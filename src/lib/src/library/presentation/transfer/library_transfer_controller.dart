/// Managed transfer operation controller.
library;

import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../data/library_repository.dart';
import '../../models/library_failure.dart';
import '../../models/library_snapshot.dart';
import '../../transfer/library_document.dart';
import '../../transfer/library_json_codec.dart';
import '../../transfer/library_markdown_export.dart';
import '../../transfer/library_transfer_plan.dart';
import '../../transfer/raycast_snippet_decoder.dart';
import '../library_controller.dart';
import '../library_document_files.dart';
import 'library_transfer_state.dart';

/// Owns one transfer operation from file to exact result.
///
/// The controller captures the expected snapshot when a review starts,
/// reclassifies the operation as stale when the repository moves, and keeps
/// the prepared export bytes outside the published state.
final class LibraryTransferController {
  /// Creates the transfer controller.
  LibraryTransferController({
    required this._repository,
    required this._library,
    required this._files,
    DateTime Function()? now,
    DocumentLimits? limits,
  }) : _now = now ?? DateTime.now,
       _limits = limits ?? DocumentLimits() {
    _snapshotSubscription = _repository.watchSnapshot().listen(
      _handleSnapshot,
      onError: _handleSnapshotError,
    );
  }

  final LibraryRepository _repository;
  final LibraryController _library;
  final LibraryDocumentFiles _files;
  final DateTime Function() _now;
  final DocumentLimits _limits;

  final StreamController<LibraryTransferState> _statesController =
      StreamController<LibraryTransferState>.broadcast();
  StreamSubscription<LibrarySnapshot>? _snapshotSubscription;
  LibraryTransferState _state = const LibraryTransferIdle();
  bool _isDisposed = false;
  bool _shutdownStarted = false;
  bool _busy = false;

  LibrarySnapshot? _expected;
  RaycastDocument? _raycastSource;
  RaycastSelection? _selection;
  Future<void>? _selectionRun;
  Uint8List? _preparedBytes;
  DocumentExportKind? _preparedKind;
  LibraryTransferState? _review;
  LibrarySnapshot? _pendingRestore;
  RaycastImportPlan? _pendingRaycast;
  bool _maintenanceActive = false;
  bool _staleDuringOperation = false;
  LibraryFailure? _snapshotFailure;
  bool _snapshotObservationFailed = false;
  Completer<void>? _operationDone;
  Future<void>? _disposeFuture;

  /// Returns the current operation state.
  LibraryTransferState get state => _state;

  /// Publishes future operation states.
  Stream<LibraryTransferState> get states => _statesController.stream;

  /// Completes when the admitted operation releases its resources.
  Future<void> get settled => _operationDone?.future ?? Future<void>.value();

  /// Reports whether prepared export bytes are still held.
  @visibleForTesting
  bool get hasPreparedBytes => _preparedBytes != null;

  /// Returns an independent copy of the prepared export bytes, if any.
  ///
  /// The copy keeps the internal buffer unobservable even if a future byte
  /// source hands back a modifiable list; today both encoders already
  /// return unmodifiable views, which is a property of the encoders, not of
  /// this controller.
  @visibleForTesting
  Uint8List? get preparedBytes =>
      _preparedBytes == null ? null : Uint8List.fromList(_preparedBytes!);

  /// Begins shutdown: rejects new operations and completes when started one
  /// settles.
  ///
  /// Exit voting calls this before reading the returned future, so an
  /// operation started after the vote began cannot slip past the wait. The
  /// ban is idempotent with [dispose] and can be lifted by [cancelShutdown]
  /// while disposal has not started.
  Future<void> beginShutdown() {
    _shutdownStarted = true;
    return settled;
  }

  /// Cancels a shutdown that has not reached disposal.
  ///
  /// After [dispose] has started the controller stays closed; a canceled
  /// exit returns it to the working state instead.
  void cancelShutdown() {
    if (_isDisposed) return;
    _shutdownStarted = false;
  }

  /// Prepares export bytes for [kind] with a default file name.
  Future<void> prepareExport(DocumentExportKind kind) {
    return _runOperation(() async {
      final snapshot = await _repository.getSnapshot();
      if (_isDisposed) return;
      try {
        final document = LibraryDocument(
          snapshot: snapshot,
          exportedAt: _secondsNow(),
        );
        final bytes = await _encodeDocument(document, kind, _limits);
        if (_isDisposed) return;
        _preparedBytes = bytes;
        _preparedKind = kind;
        _emit(
          LibraryTransferExportReady(
            kind: kind,
            fileName: _defaultExportName(kind),
          ),
        );
      } on DocumentFailure catch (failure) {
        _clearWorking();
        _emit(LibraryTransferFailed(failure: failure));
      }
    });
  }

  /// Sends the prepared bytes through the native save flow.
  Future<void> exportPrepared() {
    return _runOperation(() async {
      final state = _state;
      if (state is! LibraryTransferExportReady) return;
      final bytes = _preparedBytes;
      final kind = _preparedKind;
      if (bytes == null || kind == null) return;
      final result = await _files.exportDocument(
        kind: kind,
        suggestedName: state.fileName,
        bytes: bytes,
      );
      if (_isDisposed) return;
      switch (result) {
        case final DocumentSaved saved:
          _emit(state.copyWith(savedPath: saved.path));
        case DocumentExportCancelled():
          break;
        case DocumentExportUnavailable():
          _clearWorking();
          _emit(const LibraryTransferFailed());
        case final DocumentExportFailure failure:
          _clearWorking();
          _emit(LibraryTransferFailed(code: failure.code));
      }
    });
  }

  /// Picks one document and classifies it for review.
  Future<void> startImport() {
    return _runOperation(() async {
      final result = await _files.pickDocument();
      if (_isDisposed) return;
      switch (result) {
        case DocumentPickCancelled():
          return;
        case DocumentPickUnavailable():
          _emit(const LibraryTransferFailed());
        case final DocumentPickFailure failure:
          _emit(LibraryTransferFailed(code: failure.code));
        case final DocumentPicked picked:
          await _classify(picked.bytes);
      }
    });
  }

  /// Returns the latest selection requested for the current source.
  ///
  /// Row choices merge into this value rather than into the last published
  /// review, which can still reflect an earlier recalculation.
  RaycastSelection get raycastSelection => _selection ?? RaycastSelection();

  /// Rebuilds the Raycast plan with the new selection.
  ///
  /// A selection arriving during a recalculation replaces the pending
  /// request; the running recalculation repeats until the published review
  /// matches the latest request, so no user choice is dropped.
  Future<void> updateSelection(RaycastSelection selection) {
    _ensureActive();
    final source = _raycastSource;
    if (_state is! LibraryTransferRaycastReview || source == null) {
      return Future<void>.value();
    }
    selection.validate(source.rows.length);
    _selection = selection;
    return _selectionRun ??= _runOperation(_planLatestSelection)
        .whenComplete(() => _selectionRun = null);
  }

  /// Recalculates until the plan reflects the most recent selection.
  Future<void> _planLatestSelection() async {
    final source = _raycastSource;
    final expected = _expected;
    if (source == null || expected == null) return;
    while (_state is LibraryTransferRaycastReview) {
      final requested = _selection;
      if (requested == null) return;
      final plan = await _planRaycast(source, expected, requested);
      if (_isDisposed) return;
      if (!identical(requested, _selection)) continue;
      _review = LibraryTransferRaycastReview(plan: plan, selection: requested);
      _pendingRaycast = plan;
      _emit(_review!);
      return;
    }
  }

  /// Moves a reviewed operation to the backup or confirm step.
  Future<void> continueFromReview() {
    return _runOperation(() async {
      final expected = _expected;
      if (expected == null) return;
      switch (_state) {
        case LibraryTransferRestoreReview(:final plan):
          _review = LibraryTransferRestoreReview(plan: plan);
          _pendingRestore = plan.incomingSnapshot;
          _pendingRaycast = null;
        case LibraryTransferRaycastReview(:final plan):
          _review = _state;
          _pendingRaycast = plan;
          _pendingRestore = null;
        default:
          return;
      }
      if (expected == const LibrarySnapshot.empty()) {
        _emit(const LibraryTransferBackupVerified(backupName: null));
        return;
      }
      _emit(LibraryTransferBackupRequired(backupName: _defaultBackupName()));
    });
  }

  /// Saves the external backup copy of the current library.
  Future<void> createBackupCopy() {
    return _runOperation(() async {
      final state = _state;
      if (state is! LibraryTransferBackupRequired) return;
      final expected = _expected;
      if (expected == null) return;
      final Uint8List bytes;
      try {
        bytes = await _encodeDocument(
          LibraryDocument(snapshot: expected, exportedAt: _secondsNow()),
          DocumentExportKind.json,
          _limits,
        );
        if (_isDisposed) return;
      } on DocumentFailure catch (failure) {
        _emit(LibraryTransferFailed(failure: failure));
        return;
      }
      final result = await _files.exportDocument(
        kind: DocumentExportKind.json,
        suggestedName: state.backupName,
        bytes: bytes,
      );
      if (_isDisposed) return;
      switch (result) {
        case final DocumentSaved saved:
          _emit(
            LibraryTransferBackupSaved(
              backupName: saved.path.split('/').last,
              savedPath: saved.path,
            ),
          );
        case DocumentExportCancelled():
          _returnToReview();
        case DocumentExportUnavailable():
          _emit(const LibraryTransferFailed());
        case final DocumentExportFailure failure:
          _emit(LibraryTransferFailed(code: failure.code));
      }
    });
  }

  /// Re-reads the saved copy and compares it with the expected snapshot.
  Future<void> verifyBackupCopy() {
    return _runOperation(() async {
      if (_state is! LibraryTransferBackupSaved || _expected == null) return;
      final result = await _files.pickDocument();
      if (_isDisposed) return;
      switch (result) {
        case DocumentPickCancelled():
          return;
        case DocumentPickUnavailable():
          _emit(const LibraryTransferFailed());
        case final DocumentPickFailure failure:
          _emit(LibraryTransferFailed(code: failure.code));
        case final DocumentPicked picked:
          await _verifyCopyBytes(picked.bytes);
      }
    });
  }

  /// Applies the reviewed operation atomically under the maintenance barrier.
  Future<void> apply() {
    return _runOperation(() async {
      if (_state is! LibraryTransferBackupVerified || _expected == null) {
        return;
      }
      final backupName = (_state as LibraryTransferBackupVerified).backupName;
      _emit(const LibraryTransferApplying());
      await _library.beginMaintenance();
      _maintenanceActive = true;
      try {
        final live = await _repository.getSnapshot();
        if (_isDisposed) return;
        if (live != _expected) {
          _clearWorking();
          _emit(const LibraryTransferStale());
          return;
        }
        final restore = _pendingRestore;
        final raycast = _pendingRaycast;
        if (restore != null) {
          await _applyRestore(restore, backupName);
        } else if (raycast != null) {
          await _applyRaycast(raycast);
        }
      } on StaleSnapshotLibraryFailure {
        // The transactional expectedCurrent check is the last staleness
        // bound; like the observed movement it demands a new review and copy,
        // so the old preview must not be offered again.
        if (!_isDisposed) {
          _clearWorking();
          _emit(const LibraryTransferStale());
        }
      } on LibraryFailure catch (failure) {
        if (!_isDisposed) {
          _emit(LibraryTransferFailed(libraryFailure: failure));
        }
      } finally {
        if (_maintenanceActive) {
          _library.endMaintenance();
          _maintenanceActive = false;
        }
      }
    });
  }

  /// Returns a failed application to the still-valid review.
  void resumeReview() {
    _ensureActive();
    if (_state is! LibraryTransferFailed) return;
    if (!canResumeReview) return;
    _returnToReview();
  }

  /// Reports whether a retained preview can be revisited.
  bool get canResumeReview =>
      _state is LibraryTransferFailed && _expected != null && _review != null;

  /// Abandons the operation and returns to the idle state.
  void cancel() {
    _ensureActive();
    if (_busy || _state is LibraryTransferApplying) return;
    _clearWorking();
    _emit(const LibraryTransferIdle());
  }

  /// Releases controller resources once the started operation settles.
  ///
  /// New operations are rejected from the first call, the prepared export
  /// bytes are dropped before any waiting, and the started operation is
  /// awaited so the snapshot subscription and the states controller close
  /// only after the held transaction and admitted copy cycles are gone.
  Future<void> dispose() {
    return _disposeFuture ??= _dispose();
  }

  Future<void> _dispose() async {
    _shutdownStarted = true;
    _isDisposed = true;
    _preparedBytes = null;
    _preparedKind = null;
    await settled;
    final subscription = _snapshotSubscription;
    _snapshotSubscription = null;
    await subscription?.cancel();
    await _statesController.close();
  }

  /// Decodes and compares documents outside the presentation isolate.
  Future<void> _classify(Uint8List bytes) async {
    try {
      final source = await _decodeDocument(bytes, _limits);
      if (_isDisposed) return;
      final expected = await _repository.getSnapshot();
      if (_isDisposed) return;
      _expected = expected;
      final review = await _buildReview(source, expected);
      if (_isDisposed) return;
      // The observer ignores publications until _expected is set, and the
      // repository can publish after completing the read but before this
      // method resumes. Confirming the captured state closes that window
      // before the review is offered.
      final confirmed = await _repository.getSnapshot();
      if (_isDisposed) return;
      final unchanged =
          identical(confirmed, expected) ||
          await _snapshotsMatch(confirmed, expected);
      if (_isDisposed) return;
      if (!unchanged) {
        _clearWorking();
        _emit(const LibraryTransferStale());
        return;
      }
      _raycastSource = source is RaycastDocument ? source : null;
      _selection = null;
      _review = review;
      _emit(review);
    } on DocumentFailure catch (failure) {
      _clearWorking();
      _emit(LibraryTransferUnsupportedFile(failure: failure));
    }
  }

  Future<void> _applyRestore(
    LibrarySnapshot replacement,
    String? backupName,
  ) async {
    await _repository.restoreSnapshot(
      expectedCurrent: _expected!,
      replacement: replacement,
    );
    if (_isDisposed) return;
    final review = _review! as LibraryTransferRestoreReview;
    final done = LibraryTransferRestoreDone(
      entriesChanged: _changedCount(review.plan.entries),
      categoriesChanged: _changedCount(review.plan.categories),
      tagsChanged: _changedCount(review.plan.tags),
      backupName: backupName ?? '',
    );
    _clearWorking();
    _emit(done);
  }

  Future<void> _applyRaycast(RaycastImportPlan raycast) async {
    final drafts = [
      for (final row in raycast.selectedRows)
        RaycastEntryDraft(
          title: row.snippet!.title,
          body: row.snippet!.body,
          keyword: row.snippet!.keyword,
        ),
    ];
    await _repository.addRaycastEntries(
      expectedCurrent: _expected!,
      drafts: drafts,
    );
    if (_isDisposed) return;
    final done = LibraryTransferImportDone(
      outcomeCounts: raycast.outcomeCounts,
      warningRowCount: raycast.warningRowCount,
    );
    _clearWorking();
    _emit(done);
  }

  /// Compares the reopened copy outside the presentation isolate.
  Future<void> _verifyCopyBytes(Uint8List bytes) async {
    final expected = _expected;
    if (expected == null) return;
    try {
      final source = await _decodeDocument(bytes, _limits);
      if (_isDisposed) return;
      final matches =
          source is LibraryDocument &&
          await _snapshotsMatch(source.snapshot, expected);
      if (_isDisposed) return;
      if (!matches) {
        _emit(
          const LibraryTransferFailed(
            code: DocumentFileFailureCode.verifyFailed,
          ),
        );
        return;
      }
      _emit(LibraryTransferBackupVerified(backupName: _currentBackupName()));
    } on DocumentFailure catch (failure) {
      _emit(LibraryTransferFailed(failure: failure));
    }
  }

  void _handleSnapshot(LibrarySnapshot snapshot) {
    // The application's own repository publications are not external moves;
    // the transactional expectedCurrent check inside the repository is the
    // staleness bound for the apply itself.
    if (_isDisposed || _maintenanceActive) return;
    final expected = _expected;
    if (expected == null || snapshot == expected) return;
    if (_busy) {
      _staleDuringOperation = true;
      return;
    }
    _clearWorking();
    _emit(const LibraryTransferStale());
  }

  /// Invalidates previews when storage observation fails.
  ///
  /// Like a snapshot publication, an observation failure only matters while
  /// a review depends on the captured snapshot; it must not overwrite an
  /// applied result, a prepared export, or the application's own transaction.
  /// An unexpected failure kind is not escalated into the zone: with a live
  /// review it invalidates the review with the shared stale message, and
  /// elsewhere it is ignored.
  void _handleSnapshotError(Object error, StackTrace stack) {
    if (_isDisposed) return;
    if (error is! LibraryFailure) {
      if (_maintenanceActive || _expected == null) return;
      if (_busy) {
        _snapshotObservationFailed = true;
        return;
      }
      _clearWorking();
      _emit(const LibraryTransferStale());
      return;
    }
    if (_maintenanceActive || _expected == null) return;
    if (_busy) {
      _snapshotFailure = error;
      return;
    }
    _clearWorking();
    _emit(LibraryTransferFailed(libraryFailure: error));
  }

  void _clearWorking() {
    _expected = null;
    _raycastSource = null;
    _selection = null;
    _preparedBytes = null;
    _preparedKind = null;
    _review = null;
    _pendingRestore = null;
    _pendingRaycast = null;
  }

  void _returnToReview() {
    final review = _review;
    if (review != null) {
      _emit(review);
    }
  }

  Future<void> _runOperation(Future<void> Function() operation) async {
    _ensureOperational();
    if (_busy || _state is LibraryTransferApplying) return;
    _busy = true;
    final done = Completer<void>();
    _operationDone = done;
    try {
      await operation();
    } on LibraryFailure catch (failure) {
      _clearWorking();
      _emit(LibraryTransferFailed(libraryFailure: failure));
    } finally {
      _busy = false;
      final failure = _snapshotFailure;
      final stale = _staleDuringOperation || _snapshotObservationFailed;
      _snapshotFailure = null;
      _staleDuringOperation = false;
      _snapshotObservationFailed = false;
      // A deferred invalidation applies only while the operation still holds
      // a review; an operation that already published its result or cleared
      // its working data keeps that outcome.
      if (_expected != null) {
        if (failure != null) {
          _clearWorking();
          _emit(LibraryTransferFailed(libraryFailure: failure));
        } else if (stale) {
          _clearWorking();
          _emit(const LibraryTransferStale());
        }
      }
      done.complete();
      _operationDone = null;
    }
  }

  void _emit(LibraryTransferState nextState) {
    if (_isDisposed || nextState == _state) return;
    _state = nextState;
    _statesController.add(nextState);
  }

  void _ensureActive() {
    if (_isDisposed) {
      throw StateError('LibraryTransferController is disposed');
    }
  }

  /// Rejects operation-opening paths while shutdown has begun.
  ///
  /// Only operations that open work through [_runOperation] are banned by a
  /// begun shutdown; pure surface actions such as [cancel], [resumeReview],
  /// and an early-returning [updateSelection] stay available until the real
  /// disposal closes the controller.
  void _ensureOperational() {
    _ensureActive();
    if (_shutdownStarted) {
      throw LibraryTransferShuttingDown();
    }
  }

  int _changedCount(List<EntityDifference> rows) =>
      rows.where((row) => row.kind != EntityChangeKind.unchanged).length;

  String _currentBackupName() {
    final state = _state;
    return state is LibraryTransferBackupSaved ? state.backupName : '';
  }

  String _defaultExportName(DocumentExportKind kind) {
    final extension = switch (kind) {
      DocumentExportKind.json => 'json',
      DocumentExportKind.markdown => 'md',
    };
    return 'prompt-library-${_dateStamp()}.$extension';
  }

  String _defaultBackupName() {
    return 'prompt-library-backup-${_dateStamp()}.json';
  }

  String _dateStamp() {
    final moment = _now().toUtc();
    final month = moment.month.toString().padLeft(2, '0');
    final day = moment.day.toString().padLeft(2, '0');
    return '${moment.year}-$month-$day';
  }

  /// Truncates the seam clock to whole UTC seconds for document fields.
  ///
  /// `documentDate` rejects fractional seconds, and a live clock is
  /// practically always sub-second precise.
  DateTime _secondsNow() {
    final now = _now().toUtc();
    return DateTime.utc(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second,
    );
  }
}

/// Encodes a bounded document in a worker isolate.
Future<Uint8List> _encodeDocument(
  LibraryDocument document,
  DocumentExportKind kind,
  DocumentLimits limits,
) => Isolate.run(
  () => switch (kind) {
    DocumentExportKind.json => LibraryJsonCodec(
      limits: limits,
    ).encode(document),
    DocumentExportKind.markdown => LibraryMarkdownExport(
      limits: limits,
    ).encode(document),
  },
);

/// Reports an operation refused because application shutdown began.
final class LibraryTransferShuttingDown extends StateError {
  /// Creates the shutdown refusal.
  LibraryTransferShuttingDown()
    : super('LibraryTransferController is shutting down');
}

/// Decodes the source in a worker isolate.
Future<Object> _decodeDocument(Uint8List bytes, DocumentLimits limits) =>
    Isolate.run(() {
      final root = LibraryJsonCodec(limits: limits).decodeValue(bytes);
      if (root is Map) return LibraryDocument.fromValue(root);
      if (root is List) {
        return RaycastSnippetDecoder(limits: limits).decode(bytes);
      }
      throw const DocumentFailure(DocumentFailureCode.invalidShape);
    });

/// Builds a complete preview in a worker isolate.
Future<LibraryTransferState> _buildReview(
  Object source,
  LibrarySnapshot expected,
) => Isolate.run(() {
  if (source is LibraryDocument) {
    return LibraryTransferRestoreReview(
      plan: LibraryRestorePlan.compare(expected, source.snapshot),
    );
  }
  return LibraryTransferRaycastReview(
    plan: RaycastImportPlan.build(source as RaycastDocument, expected),
  );
});

/// Recalculates source choices in a worker isolate.
Future<RaycastImportPlan> _planRaycast(
  RaycastDocument source,
  LibrarySnapshot expected,
  RaycastSelection selection,
) => Isolate.run(
  () => RaycastImportPlan.build(source, expected, selection: selection),
);

/// Compares every snapshot field in a worker isolate.
Future<bool> _snapshotsMatch(LibrarySnapshot left, LibrarySnapshot right) =>
    Isolate.run(() => left == right);

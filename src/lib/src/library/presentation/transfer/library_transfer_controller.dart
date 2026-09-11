/// Managed transfer operation controller.
library;

import 'dart:async';
import 'dart:typed_data';

import '../../data/library_repository.dart';
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
       _codec = LibraryJsonCodec(limits: limits),
       _markdown = LibraryMarkdownExport(limits: limits),
       _decoder = RaycastSnippetDecoder(limits: limits) {
    _snapshotSubscription = _repository.watchSnapshot().listen(
      _handleSnapshot,
      onError: (Object _) {},
    );
  }

  final LibraryRepository _repository;

  // ignore: unused_field
  final LibraryController _library;

  final LibraryDocumentFiles _files;
  final DateTime Function() _now;
  final LibraryJsonCodec _codec;
  final LibraryMarkdownExport _markdown;
  final RaycastSnippetDecoder _decoder;

  final StreamController<LibraryTransferState> _statesController =
      StreamController<LibraryTransferState>.broadcast();
  StreamSubscription<LibrarySnapshot>? _snapshotSubscription;
  LibraryTransferState _state = const LibraryTransferIdle();
  bool _isDisposed = false;
  bool _busy = false;

  LibrarySnapshot? _expected;
  RaycastDocument? _raycastSource;
  Uint8List? _preparedBytes;
  DocumentExportKind? _preparedKind;

  /// Returns the current operation state.
  LibraryTransferState get state => _state;

  /// Publishes future operation states.
  Stream<LibraryTransferState> get states => _statesController.stream;

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
        final bytes = switch (kind) {
          DocumentExportKind.json => _codec.encode(document),
          DocumentExportKind.markdown => _markdown.encode(document),
        };
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

  /// Rebuilds the Raycast plan with the new selection.
  void updateSelection(RaycastSelection selection) {
    _ensureActive();
    final source = _raycastSource;
    final expected = _expected;
    if (_state is! LibraryTransferRaycastReview ||
        source == null ||
        expected == null) {
      return;
    }
    _emit(
      LibraryTransferRaycastReview(
        plan: RaycastImportPlan.build(source, expected, selection: selection),
      ),
    );
  }

  /// Abandons the operation and returns to the idle state.
  void cancel() {
    _ensureActive();
    if (_busy || _state is LibraryTransferApplying) return;
    _clearWorking();
    _emit(const LibraryTransferIdle());
  }

  /// Releases controller resources.
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    final subscription = _snapshotSubscription;
    _snapshotSubscription = null;
    await subscription?.cancel();
    await _statesController.close();
  }

  Future<void> _classify(Uint8List bytes) async {
    final Object? root;
    try {
      root = _codec.decodeValue(bytes);
    } on DocumentFailure catch (failure) {
      _emit(LibraryTransferUnsupportedFile(failure: failure));
      return;
    }
    if (root is List) {
      final RaycastDocument document;
      try {
        document = _decoder.decode(bytes);
      } on DocumentFailure catch (failure) {
        _emit(LibraryTransferUnsupportedFile(failure: failure));
        return;
      }
      final expected = await _repository.getSnapshot();
      if (_isDisposed) return;
      _expected = expected;
      _raycastSource = document;
      _emit(
        LibraryTransferRaycastReview(
          plan: RaycastImportPlan.build(document, expected),
        ),
      );
      return;
    }
    if (root is Map) {
      final LibraryDocument document;
      try {
        document = LibraryDocument.fromValue(root);
      } on DocumentFailure catch (failure) {
        _emit(LibraryTransferUnsupportedFile(failure: failure));
        return;
      }
      final expected = await _repository.getSnapshot();
      if (_isDisposed) return;
      _expected = expected;
      _emit(
        LibraryTransferRestoreReview(
          plan: LibraryRestorePlan.compare(expected, document.snapshot),
        ),
      );
      return;
    }
    _emit(
      const LibraryTransferUnsupportedFile(
        failure: DocumentFailure(DocumentFailureCode.invalidShape),
      ),
    );
  }

  void _handleSnapshot(LibrarySnapshot snapshot) {
    if (_isDisposed) return;
    final expected = _expected;
    if (expected == null || snapshot == expected) return;
    _clearWorking();
    _emit(const LibraryTransferStale());
  }

  void _clearWorking() {
    _expected = null;
    _raycastSource = null;
    _preparedBytes = null;
    _preparedKind = null;
  }

  Future<void> _runOperation(Future<void> Function() operation) async {
    _ensureActive();
    if (_busy || _state is LibraryTransferApplying) return;
    _busy = true;
    try {
      await operation();
    } finally {
      _busy = false;
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

  String _defaultExportName(DocumentExportKind kind) {
    final extension = switch (kind) {
      DocumentExportKind.json => 'json',
      DocumentExportKind.markdown => 'md',
    };
    final moment = _now();
    final month = moment.month.toString().padLeft(2, '0');
    final day = moment.day.toString().padLeft(2, '0');
    return 'prompt-library-${moment.year}-$month-$day.$extension';
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

/// Transfer controller tests.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/library/models/library_failure.dart';
import 'package:prompt_library/src/library/models/library_snapshot.dart';
import 'package:prompt_library/src/library/presentation/library_clipboard.dart';
import 'package:prompt_library/src/library/presentation/library_haptics.dart';
import 'package:prompt_library/src/library/presentation/library_share.dart';
import 'package:prompt_library/src/library/presentation/mobile/mobile_library_actions.dart';
import 'package:prompt_library/src/platform/macos/mac_quick_panel_port.dart';
import 'package:prompt_library/src/platform/macos/quick_panel_controller.dart';
import 'package:prompt_library/src/platform/macos/quick_panel_delay.dart';
import 'package:prompt_library/src/platform/macos/quick_panel_state.dart';
import 'package:prompt_library/src/library/presentation/library_controller.dart';
import 'package:prompt_library/src/library/presentation/library_document_files.dart';
import 'package:prompt_library/src/library/presentation/transfer/library_transfer_controller.dart';
import 'package:prompt_library/src/library/presentation/transfer/library_transfer_state.dart';
import 'package:prompt_library/src/library/transfer/library_document.dart';
import 'package:prompt_library/src/library/transfer/library_json_codec.dart';
import 'package:prompt_library/src/library/transfer/library_transfer_plan.dart';

import '../../../support/library_test_support.dart';

void main() {
  late TestLibraryRepository repository;
  late LibraryController library;
  late TestDocumentFiles files;
  late _GateClipboard clipboard;
  late LibraryTransferController controller;

  setUp(() {
    repository = TestLibraryRepository();
    library = LibraryController(repository: repository);
    clipboard = _GateClipboard();
    files = TestDocumentFiles();
    controller = LibraryTransferController(
      repository: repository,
      library: library,
      files: files,
      now: () => DateTime.utc(2026, 9, 11, 14, 25),
    );
  });

  tearDown(() async {
    await controller.dispose();
    await library.dispose();
    await repository.close();
  });

  group('classification', () {
    test('classifies a List root as a Raycast review', () async {
      files.pickResult = DocumentPicked(
        fileName: 'snippets.json',
        bytes: _bytes('[{"name":"Alpha","text":"Body A"}]'),
      );

      await controller.startImport();

      final state = controller.state;
      expect(state, isA<LibraryTransferRaycastReview>());
      final review = state as LibraryTransferRaycastReview;
      expect(review.plan.rows, hasLength(1));
      expect(review.plan.rows.single.outcome, ImportRowOutcome.selected);
    });

    test('classifies a Map root as a restore review', () async {
      final document = LibraryDocument(
        snapshot: LibrarySnapshot(
          entries: [testEntry('incoming-1', title: 'Incoming', body: 'Body')],
        ),
        exportedAt: DateTime.utc(2026, 9, 1),
      );
      files.pickResult = DocumentPicked(
        fileName: 'library.json',
        bytes: LibraryJsonCodec().encode(document),
      );

      await controller.startImport();

      final state = controller.state;
      expect(state, isA<LibraryTransferRestoreReview>());
      final review = state as LibraryTransferRestoreReview;
      expect(review.plan.entries.single.kind, EntityChangeKind.added);
    });

    test('rejects a scalar root and broken JSON as unsupported', () async {
      files.pickResult = DocumentPicked(
        fileName: 'scalar.json',
        bytes: _bytes('42'),
      );
      await controller.startImport();
      expect(
        controller.state,
        isA<LibraryTransferUnsupportedFile>().having(
          (state) => state.failure.code,
          'code',
          DocumentFailureCode.invalidShape,
        ),
      );

      files.pickResult = DocumentPicked(
        fileName: 'broken.json',
        bytes: _bytes('{'),
      );
      await controller.startImport();
      expect(
        controller.state,
        isA<LibraryTransferUnsupportedFile>().having(
          (state) => state.failure.code,
          'code',
          DocumentFailureCode.invalidJson,
        ),
      );
    });

    test(
      'rejects a damaged own document without Raycast diagnostics',
      () async {
        files.pickResult = DocumentPicked(
          fileName: 'own.json',
          bytes: _bytes('{"format":"dev.hawkx.promptlibrary.library"}'),
        );

        await controller.startImport();

        expect(controller.state, isA<LibraryTransferUnsupportedFile>());
        expect(controller.state, isNot(isA<LibraryTransferRaycastReview>()));
      },
    );
  });

  group('export preparation', () {
    test('builds a default name with a lowercase extension', () async {
      await controller.prepareExport(DocumentExportKind.json);

      final state = controller.state as LibraryTransferExportReady;
      expect(state.fileName, 'prompt-library-2026-09-11.json');
      expect(state.fileName.contains(':'), isFalse);
      expect(state.savedPath, isNull);
    });

    test('builds a markdown name for the markdown kind', () async {
      await controller.prepareExport(DocumentExportKind.markdown);

      final state = controller.state as LibraryTransferExportReady;
      expect(state.fileName, 'prompt-library-2026-09-11.md');
    });

    test('truncates live clocks to whole UTC seconds', () async {
      final fractional = LibraryTransferController(
        repository: repository,
        library: library,
        files: files,
        now: () => DateTime.utc(2026, 9, 11, 14, 25, 22, 500, 900),
      );
      addTearDown(() => unawaited(fractional.dispose()));

      await fractional.prepareExport(DocumentExportKind.json);

      expect(fractional.state, isA<LibraryTransferExportReady>());
    });

    test('rejects an oversized snapshot before any file is created', () async {
      final oversized = LibraryTransferController(
        repository: repository,
        library: library,
        files: files,
        limits: DocumentLimits(maxBytes: 64),
      );
      addTearDown(() => unawaited(oversized.dispose()));
      repository.emit(
        LibrarySnapshot(entries: List.generate(50, (i) => testEntry('e$i'))),
      );
      await pumpEventQueue();

      await oversized.prepareExport(DocumentExportKind.json);

      expect(
        oversized.state,
        isA<LibraryTransferFailed>().having(
          (state) => state.failure?.code,
          'failure.code',
          DocumentFailureCode.limitExceeded,
        ),
      );
      expect(files.calls, isEmpty);
    });

    test(
      'sends prepared bytes through the boundary and records the path',
      () async {
        await controller.prepareExport(DocumentExportKind.json);
        files.exportResult = DocumentSaved(path: '/tmp/saved.json');

        await controller.exportPrepared();

        expect(files.calls.single.startsWith('exportDocument:'), isTrue);
        expect(files.lastKind, DocumentExportKind.json);
        final state = controller.state as LibraryTransferExportReady;
        expect(state.savedPath, '/tmp/saved.json');
      },
    );

    test(
      'keeps the prepared export when the save dialog is cancelled',
      () async {
        await controller.prepareExport(DocumentExportKind.json);
        files.exportResult = const DocumentExportCancelled();

        await controller.exportPrepared();

        final state = controller.state as LibraryTransferExportReady;
        expect(state.savedPath, isNull);
      },
    );

    test('moves to the failed state when the boundary fails', () async {
      await controller.prepareExport(DocumentExportKind.json);
      files.exportResult = const DocumentExportFailure(
        code: DocumentFileFailureCode.writeFailed,
      );

      await controller.exportPrepared();

      expect(
        controller.state,
        isA<LibraryTransferFailed>().having(
          (state) => state.code,
          'code',
          DocumentFileFailureCode.writeFailed,
        ),
      );
    });
  });

  group('selection and staleness', () {
    test('rebuilds the plan with the new selection', () async {
      await _startRaycastImport(repository, files, controller);

      await controller.updateSelection(RaycastSelection(excludedIndices: {1}));

      final review = controller.state as LibraryTransferRaycastReview;
      expect(review.plan.rows.last.outcome, ImportRowOutcome.userSkipped);
    });

    test(
      'keeps the latest selection when choices arrive during a rebuild',
      () async {
        await _startRaycastImport(repository, files, controller);

        final first = controller.updateSelection(
          RaycastSelection(excludedIndices: {0}),
        );
        final second = controller.updateSelection(
          RaycastSelection(excludedIndices: {0, 1}),
        );
        await Future.wait([first, second]);
        await controller.settled;

        final review = controller.state as LibraryTransferRaycastReview;
        expect(review.plan.rows.map((row) => row.outcome), [
          ImportRowOutcome.userSkipped,
          ImportRowOutcome.userSkipped,
        ]);
        expect(review.selection!.excludedIndices, {0, 1});
      },
    );

    test(
      'combines unknown-field consent and add-as-new sent in quick succession',
      () async {
        files.pickResult = DocumentPicked(
          fileName: 'snippets.json',
          bytes: _bytes(
            '[{"name":"Alpha","text":"one"},'
            '{"name":" Alpha ","text":"two","folder":"work"}]',
          ),
        );
        await controller.startImport();

        final first = controller.updateSelection(
          RaycastSelection(acceptedUnknownFieldIndices: {1}),
        );
        final second = controller.updateSelection(
          RaycastSelection(
            acceptedUnknownFieldIndices: {1},
            addAsNewIndices: {1},
          ),
        );
        await Future.wait([first, second]);
        await controller.settled;

        final review = controller.state as LibraryTransferRaycastReview;
        expect(review.plan.rows.last.outcome, ImportRowOutcome.selected);
        expect(review.plan.predictedAdded, 2);
      },
    );

    test('a publication racing the review read forces a new review', () async {
      repository.emit(LibrarySnapshot(entries: [testEntry('kept-1')]));
      await pumpEventQueue();
      files.pickResult = DocumentPicked(
        fileName: 'library.json',
        bytes: LibraryJsonCodec().encode(
          LibraryDocument(
            snapshot: LibrarySnapshot(
              entries: [testEntry('kept-1'), testEntry('incoming-1')],
            ),
            exportedAt: DateTime.utc(2026, 9, 1),
          ),
        ),
      );
      repository.onNextRead = () => repository.emit(
        LibrarySnapshot(
          entries: [
            testEntry('kept-1', lastCopiedAt: DateTime.utc(2026, 9, 10)),
          ],
        ),
      );

      await controller.startImport();
      await controller.settled;

      expect(controller.state, const LibraryTransferStale());
      await controller.continueFromReview();
      files.exportResult = const DocumentSaved(path: '/tmp/backup.json');
      await controller.createBackupCopy();
      expect(files.calls, ['pickDocument']);
    });

    test('goes stale when the library changes after the review', () async {
      await _startRaycastImport(repository, files, controller);
      expect(controller.state, isA<LibraryTransferRaycastReview>());
      repository.emit(
        LibrarySnapshot(
          entries: [testEntry('entry-1', lastCopiedAt: DateTime.utc(2026))],
        ),
      );
      await pumpEventQueue();

      expect(controller.state, isA<LibraryTransferStale>());
    });

    test('cancel returns to idle and forgets the stale operation', () async {
      await _startRaycastImport(repository, files, controller);
      repository.emit(const LibrarySnapshot.empty());
      await pumpEventQueue();
      expect(controller.state, isA<LibraryTransferStale>());

      controller.cancel();

      expect(controller.state, const LibraryTransferIdle());
    });
  });

  group('lifecycle', () {
    test('ignores a second import while one is in flight', () async {
      final gate = Completer<void>();
      files.pickGate = gate;
      files.pickResult = DocumentPicked(
        fileName: 'snippets.json',
        bytes: _bytes('[{"name":"A","text":"B"}]'),
      );

      final first = controller.startImport();
      await controller.startImport();
      gate.complete();
      await first;
      await pumpEventQueue();

      expect(files.calls, ['pickDocument']);
      expect(controller.state, isA<LibraryTransferRaycastReview>());
    });

    test('stays idle when the pick is cancelled', () async {
      files.pickResult = const DocumentPickCancelled();

      await controller.startImport();

      expect(controller.state, const LibraryTransferIdle());
    });

    test('reports the boundary failure and allows a retry', () async {
      files.pickResult = const DocumentPickFailure(
        code: DocumentFileFailureCode.readFailed,
      );

      await controller.startImport();
      expect(
        controller.state,
        isA<LibraryTransferFailed>().having(
          (state) => state.code,
          'code',
          DocumentFileFailureCode.readFailed,
        ),
      );

      files.pickResult = DocumentPicked(
        fileName: 'snippets.json',
        bytes: _bytes('[{"name":"A","text":"B"}]'),
      );
      await controller.startImport();
      expect(controller.state, isA<LibraryTransferRaycastReview>());
    });

    test('disposes idempotently and rejects later commands', () async {
      await controller.dispose();
      await controller.dispose();

      expect(() => controller.startImport(), throwsStateError);
      expect(
        () => controller.updateSelection(RaycastSelection()),
        throwsStateError,
      );
    });

    test('suppresses late snapshot events after disposal', () async {
      await _startRaycastImport(repository, files, controller);
      await controller.dispose();

      repository.emit(const LibrarySnapshot.empty());
      await pumpEventQueue();

      expect(controller.state, isA<LibraryTransferRaycastReview>());
    });
  });
  group('safe shutdown', () {
    // Characterization, not a Stage 6B differentiator: this test is green on
    // the pre-Stage-6B code at 873462c (the _emit guard and the early
    // _isDisposed return already existed there). It documents the late-answer
    // contract and must not be counted as proof of the stage.
    test(
      'a late system dialog answer changes no state and throws nothing',
      () async {
        await _startRestoreImport(repository, files, controller);
        await controller.continueFromReview();
        final gate = Completer<void>();
        files.exportGate = gate;
        files.exportResult = DocumentSaved(path: '/tmp/late-copy.json');

        final saving = controller.createBackupCopy();
        await pumpEventQueue();
        repository.emit(
          LibrarySnapshot(
            entries: [testEntry('kept-1', lastCopiedAt: DateTime.utc(2026))],
          ),
        );
        await pumpEventQueue();
        final stateBefore = controller.state;

        final disposing = controller.dispose();
        gate.complete();
        await saving;
        await disposing;

        expect(controller.state, stateBefore);
        expect(controller.state, isA<LibraryTransferBackupRequired>());
      },
    );

    // Characterization, not a Stage 6B differentiator: green on the
    // pre-Stage-6B code at 873462c, where dispose also rejected later
    // commands immediately. The voting-time ban is proved by the
    // shutdown-begun-at-voting test above instead.
    test('rejects an operation started after shutdown began', () async {
      final gate = Completer<void>();
      files.pickGate = gate;
      files.pickResult = const DocumentPickCancelled();
      final picking = controller.startImport();
      await pumpEventQueue();

      final disposing = controller.dispose();
      await pumpEventQueue();

      expect(() => controller.startImport(), throwsStateError);

      gate.complete();
      await picking;
      await disposing;
    });

    test('repeated and concurrent dispose calls await one process', () async {
      final expected = await _startRestoreImport(repository, files, controller);
      await _verifyThroughBackup(files, controller, expected);
      final gate = Completer<void>();
      repository.nextMutationGate = gate;
      final applying = controller.apply();
      await pumpEventQueue();

      final first = controller.dispose();
      final second = controller.dispose();
      expect(identical(first, second), isTrue);

      var returned = false;
      unawaited(second.then((_) => returned = true));
      await pumpEventQueue();
      expect(returned, isFalse);

      gate.complete();
      await applying;
      await first;
      await second;
      expect(returned, isTrue);
    });

    test('dispose cancels the prepared export bytes', () async {
      await controller.prepareExport(DocumentExportKind.json);
      expect(controller.hasPreparedBytes, isTrue);

      await controller.dispose();

      expect(controller.hasPreparedBytes, isFalse);
    });

    test('returns prepared bytes as an independent copy', () async {
      await controller.prepareExport(DocumentExportKind.json);
      final bytes = controller.preparedBytes!;
      expect(controller.hasPreparedBytes, isTrue);

      final again = controller.preparedBytes!;

      expect(
        again,
        isNot(same(bytes)),
        reason:
            'the getter hands out an independent buffer, so no caller '
            'can ever alias the controller state',
      );
      expect(again, equals(bytes));
    });

    test('shutdown begun at voting rejects new operations and awaits the started one', () async {
      final gate = Completer<void>();
      files.pickGate = gate;
      files.pickResult = const DocumentPickCancelled();
      final picking = controller.startImport();
      await pumpEventQueue();

      final voting = controller.beginShutdown();
      expect(() => controller.startImport(), throwsStateError);

      var returned = false;
      unawaited(voting.then((_) => returned = true));
      await pumpEventQueue();
      expect(returned, isFalse);

      gate.complete();
      await picking;
      await voting;
      expect(returned, isTrue);
    });

    test('canceling the exit re-enables the next operation', () async {
      await controller.beginShutdown();
      controller.cancelShutdown();

      files.pickResult = DocumentPicked(
        fileName: 'snippets.json',
        bytes: _bytes('[{"name":"Alpha","text":"Body A"}]'),
      );
      await controller.startImport();

      expect(controller.state, isA<LibraryTransferRaycastReview>());
    });

    test('canceling after dispose does not resurrect the controller', () async {
      await controller.dispose();

      controller.cancelShutdown();

      expect(() => controller.startImport(), throwsStateError);
    });

    test(
      'cancel works during a begun shutdown and throws after dispose',
      () async {
        await _startRaycastImport(repository, files, controller);
        expect(controller.state, isA<LibraryTransferRaycastReview>());

        await controller.beginShutdown();
        controller.cancel();

        expect(controller.state, const LibraryTransferIdle());

        await controller.dispose();
        expect(() => controller.cancel(), throwsStateError);
      },
    );
  });
  group('observation errors', () {
    test('invalidates a live review without zone errors', () async {
      final zoneErrors = <Object>[];
      await runZonedGuarded(() async {
        await _startRestoreImport(repository, files, controller);
        repository.emitObservationError(StateError('observer crashed'));
      }, (error, stackTrace) => zoneErrors.add(error));
      expect(zoneErrors, isEmpty);
      expect(controller.state, isA<LibraryTransferFailed>());
      expect(
        (controller.state as LibraryTransferFailed).code,
        DocumentFileFailureCode.unknownOutcome,
        reason: 'an observation failure must not claim the library changed',
      );
    });

    test('is ignored outside a review', () async {
      final zoneErrors = <Object>[];
      await runZonedGuarded(() async {
        repository.emitObservationError(StateError('observer crashed'));
      }, (error, stackTrace) => zoneErrors.add(error));
      expect(zoneErrors, isEmpty);
      expect(controller.state, isA<LibraryTransferIdle>());
    });

    test('invalidates the review after a running operation settles', () async {
      final zoneErrors = <Object>[];
      await runZonedGuarded(() async {
        await _startRestoreImport(repository, files, controller);
        final gate = Completer<void>();
        files.pickGate = gate;
        files.pickResult = const DocumentPickCancelled();
        final verifying = controller.verifyBackupCopy();
        await pumpEventQueue();

        repository.emitObservationError(StateError('observer crashed'));
        gate.complete();
        await verifying;
      }, (error, stackTrace) => zoneErrors.add(error));
      expect(zoneErrors, isEmpty);
      expect(controller.state, isA<LibraryTransferFailed>());
      expect(
        (controller.state as LibraryTransferFailed).code,
        DocumentFileFailureCode.unknownOutcome,
        reason: 'the deferred observation failure keeps the honest message',
      );
    });
  });

  group('backup and application', () {
    test('requires a backup copy for a non-empty library', () async {
      final expected = await _startRestoreImport(repository, files, controller);
      expect(expected.entries, hasLength(1));

      await controller.continueFromReview();

      final state = controller.state as LibraryTransferBackupRequired;
      expect(state.backupName, 'prompt-library-backup-2026-09-11.json');
      expect(state.backupName.contains(':'), isFalse);
    });

    test('skips the copy for an empty library', () async {
      final incoming = LibraryDocument(
        snapshot: LibrarySnapshot(entries: [testEntry('incoming-1')]),
        exportedAt: DateTime.utc(2026, 9, 1),
      );
      files.pickResult = DocumentPicked(
        fileName: 'library.json',
        bytes: LibraryJsonCodec().encode(incoming),
      );
      await controller.startImport();

      await controller.continueFromReview();

      expect(
        controller.state,
        const LibraryTransferBackupVerified(backupName: null),
      );
    });

    test('apply without a verified copy is rejected', () async {
      await _startRestoreImport(repository, files, controller);

      await controller.apply();

      expect(repository.calls, isNot(contains('restoreSnapshot')));
      expect(controller.state, isA<LibraryTransferRestoreReview>());
    });

    test('verification passes when the re-read copy matches', () async {
      final expected = await _startRestoreImport(repository, files, controller);
      await controller.continueFromReview();
      files.exportResult = DocumentSaved(path: '/tmp/backup.json');
      await controller.createBackupCopy();
      expect(controller.state, isA<LibraryTransferBackupSaved>());

      files.pickResult = DocumentPicked(
        fileName: 'backup.json',
        bytes: LibraryJsonCodec().encode(
          LibraryDocument(snapshot: expected, exportedAt: DateTime.utc(2026)),
        ),
      );
      await controller.verifyBackupCopy();

      expect(controller.state, isA<LibraryTransferBackupVerified>());
    });

    test(
      'verification mismatch explains failure and allows a new review',
      () async {
        await _startRestoreImport(repository, files, controller);
        await controller.continueFromReview();
        files.exportResult = DocumentSaved(path: '/tmp/backup.json');
        await controller.createBackupCopy();

        final drifted = LibraryDocument(
          snapshot: LibrarySnapshot(
            entries: [
              testEntry('kept-1', lastCopiedAt: DateTime.utc(2026, 9, 10)),
            ],
          ),
          exportedAt: DateTime.utc(2026, 9, 1),
        );
        files.pickResult = DocumentPicked(
          fileName: 'backup.json',
          bytes: LibraryJsonCodec().encode(drifted),
        );
        await controller.verifyBackupCopy();

        expect(controller.state, isA<LibraryTransferFailed>());
        await controller.apply();
        expect(repository.calls, isNot(contains('restoreSnapshot')));
        controller.resumeReview();
        expect(controller.state, isA<LibraryTransferRestoreReview>());
      },
    );

    test('apply restore reports counts and releases the barrier', () async {
      final expected = await _startRestoreImport(repository, files, controller);
      await _verifyThroughBackup(files, controller, expected);

      await controller.apply();

      expect(repository.calls, contains('restoreSnapshot'));
      final done = controller.state as LibraryTransferRestoreDone;
      expect(done.entriesChanged, 1);
      expect(done.categoriesChanged, 0);
      expect(done.backupName, 'backup.json');
      expect(library.state.isUnderMaintenance, isFalse);
      await library.markCopied('kept-1');
    });

    test('apply raycast keeps the verbatim keyword of selected rows', () async {
      await _startRaycastImport(repository, files, controller);
      await controller.continueFromReview();
      final expected = await repository.getSnapshot();
      files.exportResult = DocumentSaved(path: '/tmp/backup.json');
      await controller.createBackupCopy();
      files.pickResult = DocumentPicked(
        fileName: 'backup.json',
        bytes: LibraryJsonCodec().encode(
          LibraryDocument(snapshot: expected, exportedAt: DateTime.utc(2026)),
        ),
      );
      await controller.verifyBackupCopy();

      await controller.apply();

      expect(repository.calls, contains('addRaycastEntries'));
      final done = controller.state as LibraryTransferImportDone;
      expect(done.outcomeCounts[ImportRowOutcome.selected], 2);
      final snapshot = await repository.getSnapshot();
      final alpha = snapshot.entries.singleWhere(
        (entry) => entry.title == 'Alpha',
      );
      expect(alpha.keyword, '  al  ');
      expect(
        snapshot.entries.singleWhere((entry) => entry.title == 'Beta').body,
        'Body B',
      );
    });

    test(
      'repository failure keeps the plan alive and releases the barrier',
      () async {
        final expected = await _startRestoreImport(
          repository,
          files,
          controller,
        );
        await _verifyThroughBackup(files, controller, expected);
        repository.nextFailure = LibraryFailure.databaseFailure(
          code: LibraryDatabaseFailureCode.transactionFailed,
        );

        await controller.apply();

        final state = controller.state as LibraryTransferFailed;
        expect(state.libraryFailure, isNotNull);
        expect(library.state.isUnderMaintenance, isFalse);
        await library.markCopied('kept-1');
      },
    );

    test('transactional staleness in restore requires a new review', () async {
      final expected = await _startRestoreImport(repository, files, controller);
      await _verifyThroughBackup(files, controller, expected);
      repository.nextFailure = const LibraryFailure.staleSnapshot();

      await controller.apply();

      expect(controller.state, const LibraryTransferStale());
      expect(controller.canResumeReview, isFalse);
      expect(library.state.isUnderMaintenance, isFalse);
      controller.resumeReview();
      await controller.continueFromReview();
      await controller.apply();
      expect(controller.state, const LibraryTransferStale());
      expect(
        repository.calls.where((call) => call == 'restoreSnapshot'),
        hasLength(1),
      );
    });

    test(
      'transactional staleness in Raycast import requires a new review',
      () async {
        await _startRaycastImport(repository, files, controller);
        await _verifyThroughBackup(
          files,
          controller,
          await repository.getSnapshot(),
        );
        expect(controller.state, isA<LibraryTransferBackupVerified>());
        repository.nextFailure = const LibraryFailure.staleSnapshot();

        await controller.apply();

        expect(controller.state, const LibraryTransferStale());
        expect(controller.canResumeReview, isFalse);
        expect(library.state.isUnderMaintenance, isFalse);
        await _startRaycastImport(repository, files, controller);
        expect(controller.state, isA<LibraryTransferRaycastReview>());
      },
    );

    test('a transaction failure keeps the still-valid review', () async {
      final expected = await _startRestoreImport(repository, files, controller);
      await _verifyThroughBackup(files, controller, expected);
      repository.nextFailure = const LibraryFailure.databaseFailure(
        code: LibraryDatabaseFailureCode.transactionFailed,
      );

      await controller.apply();

      expect(controller.state, isA<LibraryTransferFailed>());
      expect(controller.canResumeReview, isTrue);
      controller.resumeReview();
      expect(controller.state, isA<LibraryTransferRestoreReview>());
    });

    test('staleness before apply rejects the application', () async {
      await _startRestoreImport(repository, files, controller);
      await controller.continueFromReview();

      repository.emit(
        LibrarySnapshot(
          entries: [
            testEntry('kept-1', lastCopiedAt: DateTime.utc(2026, 9, 10)),
          ],
        ),
      );
      await pumpEventQueue();

      await controller.apply();

      expect(repository.calls, isNot(contains('restoreSnapshot')));
      expect(controller.state, isA<LibraryTransferStale>());
    });
  });

  group('operational coverage', () {
    test('goes stale when markCopied lands after the review', () async {
      await _startRestoreImport(repository, files, controller);

      await repository.markCopied('kept-1');
      await pumpEventQueue();

      expect(controller.state, isA<LibraryTransferStale>());
      await controller.apply();
      expect(repository.calls, isNot(contains('restoreSnapshot')));
    });

    test(
      'a cancelled backup copy returns to the review with the plan',
      () async {
        await _startRestoreImport(repository, files, controller);
        await controller.continueFromReview();
        files.exportResult = const DocumentExportCancelled();

        await controller.createBackupCopy();

        expect(controller.state, isA<LibraryTransferRestoreReview>());
      },
    );

    test('an unavailable copy step reports the failure', () async {
      await _startRestoreImport(repository, files, controller);
      await controller.continueFromReview();
      files.exportResult = const DocumentExportUnavailable();

      await controller.createBackupCopy();

      expect(controller.state, isA<LibraryTransferFailed>());
    });

    test('an unavailable verify step reports the failure', () async {
      await _startRestoreImport(repository, files, controller);
      await controller.continueFromReview();
      files.exportResult = DocumentSaved(path: '/tmp/backup.json');
      await controller.createBackupCopy();
      files.pickResult = const DocumentPickUnavailable();

      await controller.verifyBackupCopy();

      expect(controller.state, isA<LibraryTransferFailed>());
    });

    test('a cancelled verify step stays on the saved backup', () async {
      await _startRestoreImport(repository, files, controller);
      await controller.continueFromReview();
      files.exportResult = DocumentSaved(path: '/tmp/backup.json');
      await controller.createBackupCopy();
      files.pickResult = const DocumentPickCancelled();

      await controller.verifyBackupCopy();

      expect(controller.state, isA<LibraryTransferBackupSaved>());
    });

    test('a repeated export during the active one is ignored', () async {
      final gate = Completer<void>();
      files.exportGate = gate;
      files.exportResult = DocumentSaved(path: '/tmp/one.json');
      await controller.prepareExport(DocumentExportKind.json);

      final first = controller.exportPrepared();
      await controller.exportPrepared();
      gate.complete();
      await first;

      expect(
        files.calls.where((call) => call.startsWith('exportDocument:')),
        hasLength(1),
      );
    });

    test('a repeated apply during the active one is ignored', () async {
      final expected = await _startRestoreImport(repository, files, controller);
      await _verifyThroughBackup(files, controller, expected);
      repository.nextMutationGate = Completer<void>();

      final first = controller.apply();
      await controller.apply();
      repository.nextMutationGate!.complete();
      await first;

      expect(
        repository.calls.where((call) => call == 'restoreSnapshot'),
        hasLength(1),
      );
    });

    test(
      'dispose waits out a held application and releases the barrier',
      () async {
        final expected = await _startRestoreImport(
          repository,
          files,
          controller,
        );
        await _verifyThroughBackup(files, controller, expected);
        final gate = Completer<void>();
        repository.nextMutationGate = gate;

        final applying = controller.apply();
        await pumpEventQueue();

        final disposing = controller.dispose();
        var disposeReturned = false;
        unawaited(disposing.then((_) => disposeReturned = true));
        await pumpEventQueue();
        expect(disposeReturned, isFalse);

        gate.complete();
        await applying;
        await disposing;
        await pumpEventQueue();

        expect(repository.calls, contains('restoreSnapshot'));
        expect(library.state.isUnderMaintenance, isFalse);
        final snapshot = await repository.getSnapshot();
        expect(snapshot.entries.length, 2);
      },
    );

    test('rejects an oversized pick before decoding', () async {
      final limited = LibraryTransferController(
        repository: repository,
        library: library,
        files: files,
        limits: DocumentLimits(maxBytes: 8),
      );
      addTearDown(() => unawaited(limited.dispose()));
      files.pickResult = DocumentPicked(
        fileName: 'big.json',
        bytes: Uint8List.fromList(List.filled(64, 123)),
      );

      await limited.startImport();

      expect(
        limited.state,
        isA<LibraryTransferUnsupportedFile>().having(
          (state) => state.failure.code,
          'code',
          DocumentFailureCode.limitExceeded,
        ),
      );
    });

    test(
      'a snapshot stream error during apply keeps the committed result',
      () async {
        final expected = await _startRestoreImport(
          repository,
          files,
          controller,
        );
        await _verifyThroughBackup(files, controller, expected);
        final gate = Completer<void>();
        repository.nextMutationGate = gate;

        final applying = controller.apply();
        await pumpEventQueue();
        expect(repository.calls, contains('restoreSnapshot'));
        repository.emitFailure(
          const LibraryFailure.databaseFailure(
            code: LibraryDatabaseFailureCode.readFailed,
          ),
        );
        gate.complete();
        await applying;
        await pumpEventQueue();

        expect(controller.state, isA<LibraryTransferRestoreDone>());
      },
    );

    test(
      'a stream error while apply waits for maintenance keeps the result',
      () async {
        final expected = await _startRestoreImport(
          repository,
          files,
          controller,
        );
        await _verifyThroughBackup(files, controller, expected);
        final gate = Completer<void>();
        repository.nextMutationGate = gate;
        repository.nextFailure = const LibraryFailure.databaseFailure(
          code: LibraryDatabaseFailureCode.transactionFailed,
        );
        final favorite = library.setFavorite('kept-1', isFavorite: true);
        final favoriteOutcome = expectLater(
          favorite,
          throwsA(isA<LibraryFailure>()),
        );
        await pumpEventQueue();

        // The library already refuses new mutations, but apply still awaits
        // the admitted one: the transfer operation is busy and holds its
        // review while its own maintenance flag is not yet set.
        final applying = controller.apply();
        await pumpEventQueue();
        expect(library.state.isUnderMaintenance, isTrue);
        repository.emitFailure(
          const LibraryFailure.databaseFailure(
            code: LibraryDatabaseFailureCode.readFailed,
          ),
        );
        gate.complete();
        await favoriteOutcome;
        await applying;
        await pumpEventQueue();

        expect(repository.calls, contains('restoreSnapshot'));
        expect(controller.state, isA<LibraryTransferRestoreDone>());
      },
    );

    test('a snapshot stream error after the result keeps it', () async {
      final expected = await _startRestoreImport(repository, files, controller);
      await _verifyThroughBackup(files, controller, expected);
      await controller.apply();
      expect(controller.state, isA<LibraryTransferRestoreDone>());

      repository.emitFailure(
        const LibraryFailure.databaseFailure(
          code: LibraryDatabaseFailureCode.readFailed,
        ),
      );
      await pumpEventQueue();

      expect(controller.state, isA<LibraryTransferRestoreDone>());
    });

    test('a snapshot stream error keeps a prepared export', () async {
      await controller.prepareExport(DocumentExportKind.json);

      repository.emitFailure(
        const LibraryFailure.databaseFailure(
          code: LibraryDatabaseFailureCode.readFailed,
        ),
      );
      await pumpEventQueue();

      expect(controller.state, isA<LibraryTransferExportReady>());
    });

    test('an equal but new snapshot instance confirms the review', () async {
      repository.emit(LibrarySnapshot(entries: [testEntry('kept-1')]));
      await pumpEventQueue();
      files.pickResult = DocumentPicked(
        fileName: 'library.json',
        bytes: LibraryJsonCodec().encode(
          LibraryDocument(
            snapshot: LibrarySnapshot(
              entries: [testEntry('kept-1'), testEntry('incoming-1')],
            ),
            exportedAt: DateTime.utc(2026, 9, 1),
          ),
        ),
      );
      // A real repository builds a new snapshot object on every read.
      repository.onNextRead = () =>
          repository.emit(LibrarySnapshot(entries: [testEntry('kept-1')]));

      await controller.startImport();
      await controller.settled;

      expect(controller.state, isA<LibraryTransferRestoreReview>());
    });

    test('snapshot errors invalidate an approved operation', () async {
      final expected = await _startRestoreImport(repository, files, controller);
      await _verifyThroughBackup(files, controller, expected);
      repository.emitFailure(
        const LibraryFailure.databaseFailure(
          code: LibraryDatabaseFailureCode.transactionFailed,
        ),
      );
      await pumpEventQueue();

      expect(controller.state, isA<LibraryTransferFailed>());
      await controller.apply();
      expect(repository.calls, isNot(contains('restoreSnapshot')));
    });

    test('repository movement during backup prevents verification', () async {
      await _startRestoreImport(repository, files, controller);
      await controller.continueFromReview();
      final gate = Completer<void>();
      files.exportGate = gate;
      files.exportResult = const DocumentSaved(path: '/tmp/copy.json');
      final saving = controller.createBackupCopy();
      await repository.markCopied('kept-1');
      gate.complete();
      await saving;

      expect(controller.state, isA<LibraryTransferStale>());
    });

    test('saved backup name reflects the user selected path', () async {
      await _startRestoreImport(repository, files, controller);
      await controller.continueFromReview();
      files.exportResult = const DocumentSaved(path: '/tmp/renamed-copy.json');
      await controller.createBackupCopy();

      expect(
        (controller.state as LibraryTransferBackupSaved).backupName,
        'renamed-copy.json',
      );
    });

    test(
      'snapshot read failure is visible and a fresh export can retry',
      () async {
        repository.nextReadFailure = const LibraryFailure.databaseFailure(
          code: LibraryDatabaseFailureCode.readFailed,
        );
        await controller.prepareExport(DocumentExportKind.json);
        expect(controller.state, isA<LibraryTransferFailed>());
        expect(controller.canResumeReview, isFalse);
        controller.cancel();
        await controller.prepareExport(DocumentExportKind.json);
        expect(controller.state, isA<LibraryTransferExportReady>());
      },
    );
  });

  group('ordering with admitted copy cycles', () {
    test(
      'desktop cycle holds the barrier; the moved library goes stale',
      () async {
        final expected = await _startRestoreImport(
          repository,
          files,
          controller,
        );
        await _verifyThroughBackup(files, controller, expected);

        final gate = clipboard.block();
        final copied = copyLibraryEntry(
          entry: testEntry('kept-1'),
          clipboard: clipboard,
          controller: library,
        );
        await pumpEventQueue();
        expect(clipboard.writes, isNotEmpty);

        final applied = controller.apply();
        await pumpEventQueue();
        expect(library.state.isUnderMaintenance, isTrue);
        expect(repository.calls, isNot(contains('restoreSnapshot')));

        gate.complete();
        expect(await copied, LibraryCopyOutcome.copied);
        await applied;

        expect(repository.calls, contains('markCopied:kept-1'));
        expect(repository.calls, isNot(contains('restoreSnapshot')));
        expect(repository.calls, ['markCopied:kept-1']);
      },
    );

    test(
      'quick panel cycle holds the barrier; the moved library goes stale',
      () async {
        final expected = await _startRestoreImport(
          repository,
          files,
          controller,
        );
        await _verifyThroughBackup(files, controller, expected);
        final panel = QuickPanelController(
          libraryController: library,
          clipboard: clipboard,
          port: _StubQuickPanelPort(),
          delay: _ImmediateDelay(),
        );

        final gate = clipboard.block();
        final copied = panel.copySelected();
        await pumpEventQueue();
        expect(clipboard.writes, isNotEmpty);
        expect(panel.state.pendingAction, QuickPanelPendingAction.copy);

        final applied = controller.apply();
        await pumpEventQueue();
        expect(library.state.isUnderMaintenance, isTrue);
        expect(repository.calls, isNot(contains('restoreSnapshot')));

        gate.complete();
        await copied;
        await applied;

        expect(controller.state, isA<LibraryTransferStale>());
        expect(library.state.isUnderMaintenance, isFalse);
        expect(repository.calls, contains('markCopied:kept-1'));
        expect(repository.calls, isNot(contains('restoreSnapshot')));
        expect(panel.state.pendingAction, isNull);
        await panel.dispose();
      },
    );

    test(
      'mobile cycle holds the barrier; the moved library goes stale',
      () async {
        final expected = await _startRestoreImport(
          repository,
          files,
          controller,
        );
        await _verifyThroughBackup(files, controller, expected);
        final haptics = _SilentHaptics();
        final actions = MobileLibraryActions(
          controller: library,
          clipboard: clipboard,
          share: const UnavailableLibraryShare(),
          haptics: haptics,
        );

        final gate = clipboard.block();
        final copied = actions.copyEntry(testEntry('kept-1'));
        await pumpEventQueue();
        expect(clipboard.writes, isNotEmpty);

        final applied = controller.apply();
        await pumpEventQueue();
        expect(library.state.isUnderMaintenance, isTrue);
        expect(repository.calls, isNot(contains('restoreSnapshot')));

        gate.complete();
        expect(await copied, MobileCopyOutcome.copied);
        await applied;

        expect(controller.state, isA<LibraryTransferStale>());
        expect(library.state.isUnderMaintenance, isFalse);
        expect(repository.calls, contains('markCopied:kept-1'));
        expect(repository.calls, isNot(contains('restoreSnapshot')));
        expect(haptics.calls, 1);
      },
    );

    test(
      'a cycle started under maintenance is refused; the restore applies',
      () async {
        final expected = await _startRestoreImport(
          repository,
          files,
          controller,
        );
        await _verifyThroughBackup(files, controller, expected);

        Future<LibraryCopyOutcome>? refused;
        repository.onNextRead = () {
          refused = copyLibraryEntry(
            entry: testEntry('kept-1'),
            clipboard: clipboard,
            controller: library,
          );
        };

        await controller.apply();

        expect(controller.state, isA<LibraryTransferRestoreDone>());
        expect(await refused!, LibraryCopyOutcome.notAdmitted);
        expect(clipboard.writes, isEmpty);
        expect(repository.calls, isNot(contains('markCopied:kept-1')));
        final restored = await repository.getSnapshot();
        expect(
          restored.entries
              .singleWhere((entry) => entry.id == 'incoming-1')
              .lastCopiedAt,
          isNull,
        );
      },
    );

    test(
      'a buffer failure during the barrier still applies the restore',
      () async {
        final expected = await _startRestoreImport(
          repository,
          files,
          controller,
        );
        await _verifyThroughBackup(files, controller, expected);

        final gate = clipboard.blockAfterWrite(const LibraryClipboardFailure());
        final copied = copyLibraryEntry(
          entry: testEntry('kept-1'),
          clipboard: clipboard,
          controller: library,
        );
        await pumpEventQueue();

        final applied = controller.apply();
        await pumpEventQueue();
        expect(library.state.isUnderMaintenance, isTrue);

        gate.complete();
        expect(await copied, LibraryCopyOutcome.clipboardFailure);
        await applied;

        expect(controller.state, isA<LibraryTransferRestoreDone>());
        expect(repository.calls, contains('restoreSnapshot'));
        expect(repository.calls, isNot(contains('markCopied:kept-1')));
        expect(library.state.isUnderMaintenance, isFalse);
      },
    );

    test(
      'teardown with a held buffer skips metadata and resolves the barrier',
      () async {
        final expected = await _startRestoreImport(
          repository,
          files,
          controller,
        );
        await _verifyThroughBackup(files, controller, expected);
        final panel = QuickPanelController(
          libraryController: library,
          clipboard: clipboard,
          port: _StubQuickPanelPort(),
          delay: _ImmediateDelay(),
        );

        final gate = clipboard.block();
        final copied = panel.copySelected();
        await pumpEventQueue();
        expect(clipboard.writes, isNotEmpty);

        final barrier = library.beginMaintenance();
        var resolved = false;
        unawaited(barrier.then((_) => resolved = true));

        await panel.dispose();
        await library.dispose();
        await pumpEventQueue();
        expect(resolved, isTrue, reason: 'dispose releases admitted cycles');

        gate.complete();
        await copied;
        await pumpEventQueue();
        expect(repository.calls, isNot(contains('markCopied:kept-1')));
      },
    );
  });
}

/// Clipboard fake holding the write and raising a failure on release.
final class _GateClipboard implements LibraryClipboard {
  /// Recorded clipboard writes.
  final List<String> writes = [];

  Completer<void>? _gate;
  Object? _errorOnRelease;

  /// Holds the write until completed.
  Completer<void> block() {
    _gate = Completer<void>();
    _errorOnRelease = null;
    return _gate!;
  }

  /// Holds the write and raises [error] after the gate completes.
  Completer<void> blockAfterWrite(Object error) {
    _gate = Completer<void>();
    _errorOnRelease = error;
    return _gate!;
  }

  @override
  Future<void> writeText(String text) async {
    writes.add(text);
    final gate = _gate;
    final error = _errorOnRelease;
    if (gate != null) {
      _gate = null;
      _errorOnRelease = null;
      await gate.future;
    }
    if (error != null) {
      throw error;
    }
  }
}

/// Port stub whose native operations always succeed.
final class _StubQuickPanelPort implements MacQuickPanelPort {
  final StreamController<int> _requests = StreamController<int>.broadcast();
  final StreamController<int> _fullRequests = StreamController<int>.broadcast();

  @override
  Stream<int> get quickModeRequests => _requests.stream;

  @override
  Stream<int> get fullLibraryRequests => _fullRequests.stream;

  @override
  Future<MacQuickPanelResult> registerHotKey(HotKeySpec spec) async =>
      const MacQuickPanelResult(MacQuickPanelResultKind.registered);

  @override
  Future<MacQuickPanelResult> registrationState() async =>
      const MacQuickPanelResult(MacQuickPanelResultKind.registered);

  @override
  Future<MacQuickPanelResult> unregisterHotKey() async =>
      const MacQuickPanelResult(MacQuickPanelResultKind.registered);

  @override
  Future<MacQuickPanelResult> hideQuickMode({
    required bool restoreFocus,
    required int generation,
  }) async => const MacQuickPanelResult(MacQuickPanelResultKind.registered);

  @override
  Future<MacQuickPanelResult> showFullLibrary() async =>
      const MacQuickPanelResult(MacQuickPanelResultKind.registered);

  @override
  Future<void> dispose() async {
    await _requests.close();
    await _fullRequests.close();
  }
}

/// Delay fake that never holds the copy confirmation.
final class _ImmediateDelay implements QuickPanelDelay {
  @override
  Future<void> wait() async {}

  @override
  void cancel() {}
}

/// Haptics fake recording feedback requests.
final class _SilentHaptics implements LibraryHaptics {
  /// Number of feedback requests.
  int calls = 0;

  @override
  Future<void> selectionFeedback() async {
    calls++;
  }
}

/// Starts a restore review over a document adding one entry.
Future<LibrarySnapshot> _startRestoreImport(
  TestLibraryRepository repository,
  TestDocumentFiles files,
  LibraryTransferController controller,
) async {
  repository.emit(LibrarySnapshot(entries: [testEntry('kept-1')]));
  await pumpEventQueue();
  final document = LibraryDocument(
    snapshot: LibrarySnapshot(
      entries: [testEntry('kept-1'), testEntry('incoming-1')],
    ),
    exportedAt: DateTime.utc(2026, 9, 1),
  );
  files.pickResult = DocumentPicked(
    fileName: 'library.json',
    bytes: LibraryJsonCodec().encode(document),
  );
  await controller.startImport();
  return repository.getSnapshot();
}

/// Drives the backup copy step up to the verified state.
Future<void> _verifyThroughBackup(
  TestDocumentFiles files,
  LibraryTransferController controller,
  LibrarySnapshot expected,
) async {
  await controller.continueFromReview();
  files.exportResult = DocumentSaved(path: '/tmp/backup.json');
  await controller.createBackupCopy();
  files.pickResult = DocumentPicked(
    fileName: 'backup.json',
    bytes: LibraryJsonCodec().encode(
      LibraryDocument(snapshot: expected, exportedAt: DateTime.utc(2026)),
    ),
  );
  await controller.verifyBackupCopy();
}

/// Starts an import over a two-row Raycast file with one seeded entry.
Future<RaycastImportPlan> _startRaycastImport(
  TestLibraryRepository repository,
  TestDocumentFiles files,
  LibraryTransferController controller,
) async {
  repository.emit(LibrarySnapshot(entries: [testEntry('entry-1')]));
  await pumpEventQueue();
  files.pickResult = DocumentPicked(
    fileName: 'snippets.json',
    bytes: _bytes(
      '[{"name":"Alpha","text":"Body A","keyword":"  al  "},'
      '{"name":"Beta","text":"Body B"}]',
    ),
  );
  await controller.startImport();
  return (controller.state as LibraryTransferRaycastReview).plan;
}

/// Wraps source text into bytes.
Uint8List _bytes(String source) => Uint8List.fromList(source.codeUnits);

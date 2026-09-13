/// Transfer controller tests.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/library/models/library_failure.dart';
import 'package:prompt_library/src/library/models/library_snapshot.dart';
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
  late LibraryTransferController controller;

  setUp(() {
    repository = TestLibraryRepository();
    library = LibraryController(repository: repository);
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

    test('dispose during the application releases the barrier', () async {
      final expected = await _startRestoreImport(repository, files, controller);
      await _verifyThroughBackup(files, controller, expected);
      final gate = Completer<void>();
      repository.nextMutationGate = gate;

      final applying = controller.apply();
      await pumpEventQueue();
      await controller.dispose();
      final remainedLocked = library.state.isUnderMaintenance;
      gate.complete();
      await applying;
      await pumpEventQueue();

      expect(remainedLocked, isTrue);
      expect(repository.calls, contains('restoreSnapshot'));
      expect(library.state.isUnderMaintenance, isFalse);
      final snapshot = await repository.getSnapshot();
      expect(snapshot.entries.length, 2);
    });

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

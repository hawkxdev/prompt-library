/// Transfer screen widget tests.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/library/models/entry.dart';
import 'package:prompt_library/src/library/models/library_failure.dart';
import 'package:prompt_library/src/library/models/library_snapshot.dart';
import 'package:prompt_library/src/library/presentation/library_controller.dart';
import 'package:prompt_library/src/library/presentation/library_document_files.dart';
import 'package:prompt_library/src/library/presentation/transfer/library_transfer_controller.dart';
import 'package:prompt_library/src/library/presentation/transfer/library_transfer_state.dart';
import 'package:prompt_library/src/library/presentation/transfer/library_transfer_screen.dart';
import 'package:prompt_library/src/library/transfer/library_document.dart';
import 'package:prompt_library/src/library/transfer/library_json_codec.dart';
import 'package:prompt_library/src/library/transfer/library_transfer_plan.dart';

import '../../../support/library_test_support.dart';

void main() {
  late TestLibraryRepository repository;
  late LibraryController library;
  late TestDocumentFiles files;
  late LibraryTransferController transfer;

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LibraryTransferScreen(transfer: transfer)),
      ),
    );
    await tester.pump();
  }

  setUp(() {
    repository = TestLibraryRepository();
    library = LibraryController(repository: repository);
    files = TestDocumentFiles();
    transfer = LibraryTransferController(
      repository: repository,
      library: library,
      files: files,
      now: () => DateTime.utc(2026, 9, 11, 14, 25),
    );
  });

  tearDown(() async {
    await transfer.dispose();
    await library.dispose();
    await repository.close();
  });

  testWidgets('export mode shows name, kind, and every excluded area', (
    tester,
  ) async {
    await tester.runAsync(
      () => transfer.prepareExport(DocumentExportKind.json),
    );
    await pumpScreen(tester);

    expect(find.text('prompt-library-2026-09-11.json'), findsOneWidget);
    expect(find.text('JSON'), findsOneWidget);
    expect(find.byKey(const Key('transfer-export-exclusions')), findsOneWidget);
    expect(
      find.textContaining('Search state'),
      findsOneWidget,
      reason: 'all five excluded areas are named',
    );
    expect(find.textContaining('Selection'), findsOneWidget);
    expect(find.textContaining('Drafts'), findsOneWidget);
    expect(find.textContaining('Global shortcut'), findsOneWidget);
    expect(find.textContaining('Platform settings'), findsOneWidget);
    expect(find.textContaining('library.JSON'), findsNothing);
  });

  testWidgets('restore review lists differences across collections', (
    tester,
  ) async {
    repository.emit(LibrarySnapshot(entries: [testEntry('kept-1')]));
    await tester.runAsync(() => transfer.settled);
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
    await tester.runAsync(() => transfer.startImport());
    await pumpScreen(tester);

    expect(
      find.byKey(const Key('transfer-restore-differences')),
      findsOneWidget,
    );
    expect(find.textContaining('added'), findsWidgets);
    expect(find.textContaining('incoming-1'), findsOneWidget);
    expect(find.textContaining('removed'), findsNothing);
  });

  testWidgets('Raycast review shows row outcomes and counters', (tester) async {
    files.pickResult = DocumentPicked(
      fileName: 'snippets.json',
      bytes: _bytes('[{"name":"Alpha","text":"Body A"}]'),
    );
    await tester.runAsync(() => transfer.startImport());
    await pumpScreen(tester);

    expect(find.byKey(const Key('transfer-raycast-rows')), findsOneWidget);
    expect(find.textContaining('Alpha'), findsOneWidget);
    expect(find.textContaining('Will add: 1'), findsOneWidget);
    expect(find.textContaining('Skipped: 0'), findsOneWidget);
  });

  testWidgets('unsupported file explains the reason without content', (
    tester,
  ) async {
    files.pickResult = DocumentPicked(
      fileName: 'broken.json',
      bytes: _bytes('{"format":"dev.hawkx.promptlibrary.library"}'),
    );
    await tester.runAsync(() => transfer.startImport());
    await pumpScreen(tester);

    expect(find.byKey(const Key('transfer-unsupported')), findsOneWidget);
    expect(find.textContaining('not a supported'), findsOneWidget);
    expect(find.textContaining('dev.hawkx.promptlibrary'), findsNothing);
  });

  testWidgets('idle mode offers export and import actions', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Export JSON'), findsOneWidget);
    expect(find.text('Export Markdown'), findsOneWidget);
    expect(find.text('Import from file…'), findsOneWidget);
  });

  testWidgets('restore review exposes exact old and new field values', (
    tester,
  ) async {
    repository.emit(
      LibrarySnapshot(entries: [testEntry('kept', body: 'old body')]),
    );
    files.pickResult = DocumentPicked(
      fileName: 'replacement.json',
      bytes: LibraryJsonCodec().encode(
        LibraryDocument(
          snapshot: LibrarySnapshot(
            entries: [testEntry('kept', body: 'new body')],
          ),
          exportedAt: DateTime.utc(2026),
        ),
      ),
    );
    await tester.runAsync(() => transfer.startImport());
    await pumpScreen(tester);
    await tester.runAsync(() async {
      await tester.tap(find.textContaining('modified: kept'));
      await transfer.settled;
    });
    await tester.runAsync(() => transfer.settled);
    await tester.pumpAndSettle();

    expect(find.textContaining('old body'), findsOneWidget);
    expect(find.textContaining('new body'), findsOneWidget);
  });

  testWidgets('modified entities show every field before and after', (
    tester,
  ) async {
    Entry entry(String body) => Entry(
      id: 'kept',
      title: 'Title',
      body: body,
      keyword: '  alias  ',
      categoryId: 'c1',
      tagIds: const ['t1'],
      isFavorite: true,
      isArchived: true,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 2, 1),
      lastCopiedAt: DateTime.utc(2026, 3, 1),
    );
    repository.emit(
      LibrarySnapshot(
        entries: [entry('old body')],
        categories: [testCategory('c1', 'Work', sortOrder: 7)],
        tags: [testTag('t1', 'Tag')],
      ),
    );
    await tester.runAsync(() => transfer.settled);
    files.pickResult = DocumentPicked(
      fileName: 'replacement.json',
      bytes: LibraryJsonCodec().encode(
        LibraryDocument(
          snapshot: LibrarySnapshot(
            entries: [entry('new body')],
            categories: [testCategory('c1', 'Work 2', sortOrder: 7)],
            tags: [testTag('t1', 'Tag 2')],
          ),
          exportedAt: DateTime.utc(2026),
        ),
      ),
    );
    await tester.runAsync(() => transfer.startImport());
    await pumpScreen(tester);

    await tester.tap(find.text('Entry modified: kept'));
    await tester.pumpAndSettle();

    expect(find.text('body (changed)'), findsOneWidget);
    for (final field in [
      'title',
      'keyword',
      'categoryId',
      'tagIds',
      'isFavorite',
      'isArchived',
      'createdAt',
      'updatedAt',
      'lastCopiedAt',
    ]) {
      expect(find.text(field), findsOneWidget, reason: field);
    }
    expect(find.text('Before: "Title"'), findsOneWidget);
    expect(find.text('After: "Title"'), findsOneWidget);
    expect(find.text('Before: "  alias  "'), findsOneWidget);
    expect(find.text('After: "  alias  "'), findsOneWidget);
    expect(find.text('Before: "c1"'), findsOneWidget);
    expect(find.text('After: ["t1"]'), findsOneWidget);
    expect(find.text('Before: true'), findsNWidgets(2));
    expect(find.textContaining('2026-02-01'), findsNWidgets(2));
    expect(find.textContaining('2026-03-01'), findsNWidgets(2));
    expect(find.text('Before: "old body"'), findsOneWidget);
    expect(find.text('After: "new body"'), findsOneWidget);

    await tester.tap(find.text('Entry modified: kept'));
    await tester.pumpAndSettle();
    final list = find
        .descendant(
          of: find.byKey(const Key('transfer-restore-differences')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Category modified: c1'),
      100,
      scrollable: list,
    );
    await tester.tap(find.text('Category modified: c1'));
    await tester.pumpAndSettle();
    expect(find.text('name (changed)'), findsOneWidget);
    expect(find.text('sortOrder'), findsOneWidget);
    expect(find.text('After: 7'), findsOneWidget);

    await tester.tap(find.text('Category modified: c1'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Tag modified: t1'),
      100,
      scrollable: list,
    );
    await tester.tap(find.text('Tag modified: t1'));
    await tester.pumpAndSettle();
    expect(find.text('name (changed)'), findsOneWidget);
    expect(find.text('id'), findsOneWidget);
    expect(find.text('Before: "t1"'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Raycast conflict and unknown fields can be accepted explicitly',
    (tester) async {
      files.pickResult = DocumentPicked(
        fileName: 'snippets.json',
        bytes: _bytes(
          '[{"name":"Alpha","text":"one"},'
          '{"name":" Alpha ","text":"two {clipboard}","folder":"work"}]',
        ),
      );
      await tester.runAsync(() => transfer.startImport());
      await pumpScreen(tester);

      expect(find.textContaining('folder'), findsOneWidget);
      expect(find.textContaining('Literal'), findsWidgets);
      await tester.ensureVisible(find.byKey(const Key('transfer-unknown-1')));
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('transfer-unknown-1')));
        await transfer.settled;
      });
      await tester.runAsync(() => transfer.settled);
      await tester.pumpAndSettle();
      expect(
        (transfer.state as LibraryTransferRaycastReview).plan.rows.last.outcome,
        ImportRowOutcome.conflict,
      );
      await tester.ensureVisible(find.byKey(const Key('transfer-add-new-1')));
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('transfer-add-new-1')));
        await transfer.settled;
      });
      await tester.runAsync(() => transfer.settled);
      await tester.pumpAndSettle();
      expect(
        (transfer.state as LibraryTransferRaycastReview).plan.predictedAdded,
        2,
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 1000));
      await tester.pumpAndSettle();
      expect(find.textContaining('Will add: 2'), findsOneWidget);
    },
  );

  testWidgets('rapid independent Raycast exclusions keep every choice', (
    tester,
  ) async {
    files.pickResult = DocumentPicked(
      fileName: 'snippets.json',
      bytes: _bytes('[{"name":"A","text":"a"},{"name":"B","text":"b"}]'),
    );
    await tester.runAsync(() => transfer.startImport());
    await pumpScreen(tester);

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('transfer-exclude-0')));
      // Only microtasks separate the taps, so the worker isolate cannot
      // deliver the first recalculation before the second choice is made.
      expect(
        (transfer.state as LibraryTransferRaycastReview).selection,
        isNull,
        reason: 'the second tap must precede the first published review',
      );
      await tester.tap(find.byKey(const Key('transfer-exclude-1')));
      await transfer.settled;
      await transfer.settled;
    });
    await tester.pump();

    final review = transfer.state as LibraryTransferRaycastReview;
    expect(review.plan.rows.map((row) => row.outcome), [
      ImportRowOutcome.userSkipped,
      ImportRowOutcome.userSkipped,
    ]);
    expect(review.selection!.excludedIndices, {0, 1});
    expect(find.textContaining('Will add: 0'), findsOneWidget);
  });

  testWidgets('a repeated decision on the same Raycast row wins', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    files.pickResult = DocumentPicked(
      fileName: 'snippets.json',
      bytes: _bytes(
        '[{"name":"A","text":"a","folder":"x"},'
        '{"name":"B","text":"b"},'
        '{"name":" B ","text":"c"}]',
      ),
    );
    await tester.runAsync(() => transfer.startImport());
    await pumpScreen(tester);

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('transfer-exclude-1')));
      // Every tap below lands before the first recalculation publishes.
      expect(
        (transfer.state as LibraryTransferRaycastReview).selection,
        isNull,
        reason: 'the repeated taps must precede the first published review',
      );
      await tester.tap(find.byKey(const Key('transfer-exclude-1')));
      await tester.tap(find.byKey(const Key('transfer-unknown-0')));
      await tester.tap(find.byKey(const Key('transfer-unknown-0')));
      await tester.tap(find.byKey(const Key('transfer-add-new-2')));
      await tester.tap(find.byKey(const Key('transfer-add-new-2')));
      await transfer.settled;
    });
    await tester.pump();

    final review = transfer.state as LibraryTransferRaycastReview;
    expect(review.selection!.excludedIndices, isEmpty);
    expect(review.selection!.acceptedUnknownFieldIndices, isEmpty);
    expect(review.selection!.addAsNewIndices, isEmpty);
    expect(review.plan.rows.map((row) => row.outcome), [
      ImportRowOutcome.unsupportedFields,
      ImportRowOutcome.selected,
      ImportRowOutcome.conflict,
    ]);
  });

  testWidgets('Raycast choices do not survive into a different file', (
    tester,
  ) async {
    files.pickResult = DocumentPicked(
      fileName: 'first.json',
      bytes: _bytes('[{"name":"A","text":"a"},{"name":"B","text":"b"}]'),
    );
    await tester.runAsync(() => transfer.startImport());
    await pumpScreen(tester);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('transfer-exclude-1')));
      await transfer.settled;
    });
    await tester.runAsync(() => transfer.settled);
    await tester.pumpAndSettle();
    transfer.cancel();
    await tester.pump();
    files.pickResult = DocumentPicked(
      fileName: 'second.json',
      bytes: _bytes('[{"name":"Only","text":"one"}]'),
    );
    await tester.runAsync(() => transfer.startImport());
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('transfer-exclude-0')));
      await transfer.settled;
    });
    await tester.runAsync(() => transfer.settled);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      (transfer.state as LibraryTransferRaycastReview).plan.predictedAdded,
      0,
    );
  });

  testWidgets('file failure explains the recovery action', (tester) async {
    await tester.runAsync(
      () => transfer.prepareExport(DocumentExportKind.json),
    );
    files.exportResult = const DocumentExportFailure(
      code: DocumentFileFailureCode.existingFile,
    );
    await tester.runAsync(() => transfer.exportPrepared());
    await pumpScreen(tester);

    expect(find.textContaining('already exists'), findsOneWidget);
    expect(find.textContaining('different name'), findsOneWidget);
  });

  group('backup and application flow', () {
    testWidgets('drives restore from review to the done summary', (
      tester,
    ) async {
      repository.emit(LibrarySnapshot(entries: [testEntry('kept-1')]));
      await tester.runAsync(() => transfer.settled);
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
      await tester.runAsync(() => transfer.startImport());
      await pumpScreen(tester);

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('transfer-restore-continue')));
        await transfer.settled;
      });
      await tester.runAsync(() => transfer.settled);
      await tester.pump();
      expect(transfer.state, isA<LibraryTransferBackupRequired>());
      files.exportResult = DocumentSaved(path: '/tmp/backup.json');
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('transfer-backup-save')));
        await transfer.settled;
      });
      await tester.runAsync(() => transfer.settled);
      await tester.runAsync(() => transfer.settled);
      await tester.pump();
      final currentSnapshot = await repository.getSnapshot();
      files.pickResult = DocumentPicked(
        fileName: 'backup.json',
        bytes: LibraryJsonCodec().encode(
          LibraryDocument(
            snapshot: currentSnapshot,
            exportedAt: DateTime.utc(2026),
          ),
        ),
      );
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('transfer-backup-verify')));
        await transfer.settled;
      });
      await tester.runAsync(() => transfer.settled);
      await tester.runAsync(() => transfer.settled);
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('transfer-apply')));
        await transfer.settled;
      });
      await tester.runAsync(() => transfer.settled);
      await tester.runAsync(() => transfer.settled);
      await tester.pump();

      expect(find.byKey(const Key('transfer-restore-done')), findsOneWidget);
      expect(find.textContaining('backup.json'), findsOneWidget);
    });

    testWidgets('returns to the review after a repository failure', (
      tester,
    ) async {
      repository.emit(LibrarySnapshot(entries: [testEntry('kept-1')]));
      await tester.runAsync(() => transfer.settled);
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
      await tester.runAsync(() => transfer.startImport());
      await pumpScreen(tester);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('transfer-restore-continue')));
        await transfer.settled;
      });
      await tester.runAsync(() => transfer.settled);
      await tester.pump();
      files.exportResult = DocumentSaved(path: '/tmp/backup.json');
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('transfer-backup-save')));
        await transfer.settled;
      });
      await tester.runAsync(() => transfer.settled);
      await tester.runAsync(() => transfer.settled);
      await tester.pump();
      final currentSnapshot = await repository.getSnapshot();
      files.pickResult = DocumentPicked(
        fileName: 'backup.json',
        bytes: LibraryJsonCodec().encode(
          LibraryDocument(
            snapshot: currentSnapshot,
            exportedAt: DateTime.utc(2026),
          ),
        ),
      );
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('transfer-backup-verify')));
        await transfer.settled;
      });
      await tester.runAsync(() => transfer.settled);
      await tester.runAsync(() => transfer.settled);
      await tester.pump();
      repository.nextFailure = LibraryFailure.databaseFailure(
        code: LibraryDatabaseFailureCode.transactionFailed,
      );
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('transfer-apply')));
        await transfer.settled;
      });
      await tester.runAsync(() => transfer.settled);
      await tester.runAsync(() => transfer.settled);
      await tester.pump();

      expect(find.byKey(const Key('transfer-failed')), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('transfer-back-to-review')));
        await transfer.settled;
      });
      await tester.runAsync(() => transfer.settled);
      await tester.pump();

      expect(
        find.byKey(const Key('transfer-restore-differences')),
        findsOneWidget,
      );
    });
  });

  group('shutdown refusal', () {
    testWidgets('idle buttons refuse with a live-region message', (
      tester,
    ) async {
      final zoneErrors = <Object>[];
      await runZonedGuarded(() async {
        await pumpScreen(tester);
        await tester.runAsync(() => transfer.beginShutdown());

        await tester.tap(find.text('Export JSON'));
        await tester.pump();
        await tester.tap(find.text('Export Markdown'));
        await tester.pump();
        await tester.tap(find.text('Import from file…'));
        await tester.pump();
      }, (error, stackTrace) => zoneErrors.add(error));
      expect(zoneErrors, isEmpty);
      expect(find.byKey(const Key('transfer-shutdown-notice')), findsOneWidget);
      expect(
        find.text('The application is closing. The operation was not started.'),
        findsOneWidget,
      );
      expect(transfer.state, isA<LibraryTransferIdle>());
    });

    testWidgets('the save action refuses and keeps the prepared export', (
      tester,
    ) async {
      final zoneErrors = <Object>[];
      await runZonedGuarded(() async {
        await tester.runAsync(
          () => transfer.prepareExport(DocumentExportKind.json),
        );
        await pumpScreen(tester);
        await tester.runAsync(() => transfer.beginShutdown());

        await tester.tap(find.byKey(const Key('transfer-export-save')));
        await tester.pump();
      }, (error, stackTrace) => zoneErrors.add(error));
      expect(zoneErrors, isEmpty);
      expect(find.byKey(const Key('transfer-shutdown-notice')), findsOneWidget);
      expect(transfer.state, isA<LibraryTransferExportReady>());
    });

    testWidgets('the review and backup actions refuse after shutdown', (
      tester,
    ) async {
      final zoneErrors = <Object>[];
      await runZonedGuarded(() async {
        repository.emit(LibrarySnapshot(entries: [testEntry('kept-1')]));
        await tester.runAsync(() => transfer.settled);
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
        await tester.runAsync(() => transfer.startImport());
        await pumpScreen(tester);
        await tester.runAsync(() => transfer.beginShutdown());

        await tester.tap(find.byKey(const Key('transfer-restore-continue')));
        await tester.pump();
      }, (error, stackTrace) => zoneErrors.add(error));
      expect(zoneErrors, isEmpty);
      expect(find.byKey(const Key('transfer-shutdown-notice')), findsOneWidget);
      expect(
        transfer.state,
        isA<LibraryTransferRestoreReview>(),
        reason: 'the refused continue leaves the review intact',
      );
    });

    testWidgets('a raycast row choice refuses after shutdown', (tester) async {
      final zoneErrors = <Object>[];
      await runZonedGuarded(() async {
        files.pickResult = DocumentPicked(
          fileName: 'snippets.json',
          bytes: _bytes('[{"name":"Alpha","text":"a"}]'),
        );
        await tester.runAsync(() => transfer.startImport());
        await pumpScreen(tester);
        await tester.runAsync(() => transfer.beginShutdown());

        await tester.tap(find.byKey(const Key('transfer-exclude-0')));
        await tester.pump();
      }, (error, stackTrace) => zoneErrors.add(error));
      expect(zoneErrors, isEmpty);
      expect(find.byKey(const Key('transfer-shutdown-notice')), findsOneWidget);
      expect(
        (transfer.state as LibraryTransferRaycastReview).selection,
        isNull,
        reason: 'the refused choice changed no selection',
      );
    });

    testWidgets('a plain StateError is not swallowed by the wrapper', (
      tester,
    ) async {
      final zoneErrors = <Object>[];
      await runZonedGuarded(() async {
        await pumpScreen(tester);
        await tester.runAsync(() => transfer.dispose());

        await tester.tap(find.text('Export JSON'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
      }, (error, stackTrace) => zoneErrors.add(error));
      expect(zoneErrors, hasLength(1));
      expect(
        (zoneErrors.single as StateError).message,
        'LibraryTransferController is disposed',
      );
    });
  });

  group('large text in the standard route', () {
    Future<void> pumpRoute(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Transfer library')),
            body: LibraryTransferScreen(transfer: transfer),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('the applying state scrolls without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 300);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 3.1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      repository.emit(const LibrarySnapshot.empty());
      await tester.runAsync(() => transfer.settled);
      files.pickResult = DocumentPicked(
        fileName: 'library.json',
        bytes: LibraryJsonCodec().encode(
          LibraryDocument(
            snapshot: LibrarySnapshot(entries: [testEntry('incoming-1')]),
            exportedAt: DateTime.utc(2026),
          ),
        ),
      );
      await tester.runAsync(() => transfer.startImport());
      await tester.runAsync(() => transfer.continueFromReview());
      final gate = Completer<void>();
      repository.nextMutationGate = gate;
      final applying = transfer.apply();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));

      await pumpRoute(tester);

      expect(transfer.state, isA<LibraryTransferApplying>());
      expect(
        tester.takeException(),
        isNull,
        reason: 'the applying message must scroll instead of overflowing',
      );

      gate.complete();
      await tester.runAsync(() => applying);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the shutdown notice scrolls and keeps the live region', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 300);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 3.1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await pumpRoute(tester);
      await tester.runAsync(() => transfer.beginShutdown());

      await tester.ensureVisible(find.text('Export JSON'));
      await tester.tap(find.text('Export JSON'));
      await tester.pump();

      expect(find.byKey(const Key('transfer-shutdown-notice')), findsOneWidget);
      expect(
        tester.takeException(),
        isNull,
        reason: 'the notice must scroll together with the content',
      );
      final handle = tester.ensureSemantics();
      final noticeData = find.semantics
          .byLabel('The application is closing. The operation was not started.')
          .evaluate()
          .single
          .getSemanticsData();
      expect(
        noticeData.flagsCollection.isLiveRegion,
        isTrue,
        reason: 'the refusal notice stays a live region',
      );
      handle.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('operational coverage', () {
    testWidgets('review actions remain reachable in short large text views', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 300);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 3.1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      files.pickResult = DocumentPicked(
        fileName: 'short.json',
        bytes: _bytes('[{"name":"Alpha","text":"body"}]'),
      );
      await tester.runAsync(() => transfer.startImport());
      await pumpScreen(tester);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byKey(const Key('transfer-import-continue')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders and scrolls a two-thousand-entry restore review', (
      tester,
    ) async {
      final kept = List.generate(2000, (i) => testEntry('kept-$i'));
      repository.emit(LibrarySnapshot(entries: kept));
      await tester.runAsync(() => transfer.settled);
      final document = LibraryDocument(
        snapshot: LibrarySnapshot(entries: [testEntry('zz-incoming-2000')]),
        exportedAt: DateTime.utc(2026, 9, 1),
      );
      files.pickResult = DocumentPicked(
        fileName: 'library.json',
        bytes: LibraryJsonCodec().encode(document),
      );
      await tester.runAsync(() => transfer.startImport());
      await pumpScreen(tester);

      final plan = (transfer.state as LibraryTransferRestoreReview).plan;
      expect(
        plan.entries.where((row) => row.kind == EntityChangeKind.removed),
        hasLength(2000),
      );
      expect(tester.takeException(), isNull);
      // Identifiers sort as strings, so kept-0 opens the list and kept-999 is
      // the last removal before the single addition.
      expect(find.text('Entry removed: kept-0'), findsOneWidget);
      final differences = find
          .descendant(
            of: find.byKey(const Key('transfer-restore-differences')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.byKey(const Key('transfer-restore-continue')),
        5000,
        maxScrolls: 100,
        scrollable: differences,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Entry removed: kept-999'), findsOneWidget);
      expect(find.text('Entry added: zz-incoming-2000'), findsOneWidget);
      expect(
        tester.getRect(find.text('Entry removed: kept-999')).top,
        lessThan(
          tester.getRect(find.text('Entry added: zz-incoming-2000')).top,
        ),
      );
    });

    testWidgets('survives large text scales without layout exceptions', (
      tester,
    ) async {
      for (final scale in [2.0, 3.1]) {
        await tester.runAsync(
          () => transfer.prepareExport(DocumentExportKind.json),
        );
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        await pumpScreen(tester);

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('transfer-export-save')), findsOneWidget);
        tester.platformDispatcher.textScaleFactorTestValue = 1.0;
        await pumpScreen(tester);
        transfer.cancel();
        await pumpScreen(tester);
      }
    });

    testWidgets('activates save and cancel through keyboard traversal', (
      tester,
    ) async {
      // Tab from a fresh screen reaches Save, and Enter activates it.
      await tester.runAsync(
        () => transfer.prepareExport(DocumentExportKind.json),
      );
      files.exportResult = DocumentSaved(path: '/tmp/saved.json');
      await pumpScreen(tester);
      var focused = focusedOn(const Key('transfer-export-save'));
      for (var i = 0; i < 12 && !focused; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        focused = focusedOn(const Key('transfer-export-save'));
      }
      expect(focused, isTrue, reason: 'Tab reaches the save action');
      await tester.runAsync(() async {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await transfer.settled;
      });
      await tester.runAsync(() => transfer.settled);
      await tester.pump();
      expect(find.textContaining('Saved. Path:'), findsOneWidget);
    });

    testWidgets('reaches cancel by traversal and returns to idle', (
      tester,
    ) async {
      await tester.runAsync(
        () => transfer.prepareExport(DocumentExportKind.json),
      );
      await pumpScreen(tester);
      var focused = focusedOn(const Key('transfer-export-cancel'));
      for (var i = 0; i < 12 && !focused; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        focused = focusedOn(const Key('transfer-export-cancel'));
      }
      expect(focused, isTrue, reason: 'Tab order reaches the cancel action');
      await tester.runAsync(() async {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await transfer.settled;
      });
      await tester.pump();
      expect(find.byKey(const Key('transfer-idle')), findsOneWidget);
    });

    testWidgets('exposes labeled actions to assistive technologies', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester);

      expect(find.semantics.byLabel('Export JSON'), findsOneWidget);
      expect(find.semantics.byLabel('Import from file…'), findsOneWidget);
      handle.dispose();

      await tester.runAsync(
        () => transfer.prepareExport(DocumentExportKind.json),
      );
      await pumpScreen(tester);
      final stepHandle = tester.ensureSemantics();
      expect(find.semantics.byLabel('Save…'), findsOneWidget);
      stepHandle.dispose();
    });
  });
}

/// Reports whether the transfer keyboard focus sits inside [key].
bool focusedOn(Key key) {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  var found = false;
  context.visitAncestorElements((element) {
    if (element.widget.key == key) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

/// Wraps source text into bytes.
Uint8List _bytes(String source) => Uint8List.fromList(source.codeUnits);

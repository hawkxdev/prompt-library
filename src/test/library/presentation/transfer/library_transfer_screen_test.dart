/// Transfer screen widget tests.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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

      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.textContaining('zz-incoming-2000'),
        5000,
        maxScrolls: 100,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('transfer-restore-differences')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining('zz-incoming-2000'), findsOneWidget);
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

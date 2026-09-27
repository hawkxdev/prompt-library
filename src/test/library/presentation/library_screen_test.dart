/// Full library widget tests.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/app/application_surface.dart';
import 'package:prompt_library/src/app/prompt_library_app.dart';
import 'package:prompt_library/src/library/models/library_failure.dart';
import 'package:prompt_library/src/library/models/library_snapshot.dart';
import 'package:prompt_library/src/library/presentation/library_clipboard.dart';
import 'package:prompt_library/src/library/presentation/library_controller.dart';
import 'package:prompt_library/src/library/presentation/library_detail.dart';
import 'package:prompt_library/src/library/presentation/library_screen.dart';
import 'package:prompt_library/src/platform/macos/quick_panel_controller.dart';
import 'package:prompt_library/src/platform/macos/unavailable_mac_quick_panel.dart';
import 'package:prompt_library/src/library/presentation/library_document_files.dart';
import 'package:prompt_library/src/library/presentation/library_filter.dart';
import 'package:prompt_library/src/library/presentation/transfer/library_transfer_controller.dart';
import 'package:prompt_library/src/library/presentation/transfer/library_transfer_screen.dart';
import 'package:prompt_library/src/library/presentation/transfer/library_transfer_state.dart';
import 'package:prompt_library/src/library/transfer/library_document.dart';
import 'package:prompt_library/src/library/transfer/library_json_codec.dart';

import '../../support/library_test_support.dart';

void main() {
  late TestLibraryRepository repository;
  late LibraryController controller;
  late TestDocumentFiles files;
  late LibraryTransferController transfer;
  late _TestClipboard clipboard;

  setUp(() {
    repository = TestLibraryRepository();
    controller = LibraryController(repository: repository);
    files = TestDocumentFiles();
    transfer = LibraryTransferController(
      repository: repository,
      library: controller,
      files: files,
      now: () => DateTime.utc(2026, 9, 27, 12),
    );
    clipboard = _TestClipboard();
  });

  tearDown(() async {
    await transfer.dispose();
    await controller.dispose();
    await repository.close();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      PromptLibraryApp(
        applicationSurface: ApplicationSurface.desktop,
        controller: controller,
        clipboard: clipboard,
        transferController: transfer,
      ),
    );
  }

  Future<void> pumpState(WidgetTester tester) async {
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump(const Duration(milliseconds: 150));
  }

  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  }

  IconButton actionButton(WidgetTester tester, String tooltip) {
    return tester.widget<IconButton>(
      find.descendant(
        of: find.byTooltip(tooltip),
        matching: find.byType(IconButton),
      ),
    );
  }

  // === State surfaces ===

  testWidgets('renders loading then actionable empty state', (tester) async {
    await pumpApp(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repository.emit(const LibrarySnapshot.empty());
    await pumpState(tester);

    expect(find.text('Your library is empty'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'New prompt'), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('exposes complete navigation at medium width', (tester) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(
        categories: [testCategory('category-1', 'Category A')],
        tags: [testTag('tag-1', 'Tag A')],
      ),
    );
    await pumpState(tester);

    await tester.tap(find.byTooltip('Library navigation'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Category A'), findsOneWidget);
    expect(find.text('Tag A'), findsOneWidget);
    expect(find.byTooltip('Manage categories and tags'), findsOneWidget);

    await tester.tap(find.text('Category A'));
    await pumpState(tester);
    expect(controller.state.filter.categoryId, 'category-1');

    await tester.tap(find.text('Tag A'));
    await pumpState(tester);
    expect(controller.state.filter.tagIds, ['tag-1']);
    await disposeApp(tester);
  });

  // === Search, selection and copy ===

  testWidgets('searches, selects, and copies exact selected body', (
    tester,
  ) async {
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(
        entries: [
          testEntry('one', title: 'Alpha', body: '  exact\nbody  '),
          testEntry('two', title: 'Beta', body: 'other'),
        ],
      ),
    );
    await pumpState(tester);

    expect(find.text('Alpha'), findsNWidgets(2));
    expect(find.text('Beta'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('library-search')), 'beta');
    await pumpState(tester);
    expect(find.text('Alpha'), findsNothing);
    expect(find.text('Beta'), findsNWidgets(2));

    await tester.enterText(find.byKey(const Key('library-search')), '');
    await pumpState(tester);
    await tester.tap(find.text('Alpha').first);
    await pumpState(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Copy'));
    await pumpState(tester);

    expect(clipboard.values, ['  exact\nbody  ']);
    expect(repository.calls, contains('markCopied:one'));
    await disposeApp(tester);
  });

  test('ignores copy metadata after controller teardown', () async {
    final gate = Completer<void>();
    clipboard.gate = gate;
    final copyFuture = copyLibraryEntry(
      entry: testEntry('one'),
      clipboard: clipboard,
      controller: controller,
    );
    await Future<void>.delayed(Duration.zero);

    await controller.dispose();
    gate.complete();

    await expectLater(copyFuture, completes);
    expect(repository.calls, isNot(contains('markCopied:one')));
  });

  testWidgets('copy under maintenance writes nothing and shows no message', (
    tester,
  ) async {
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(entries: [testEntry('one', body: 'exact body')]),
    );
    await pumpState(tester);
    await controller.beginMaintenance();

    await tester.tap(find.widgetWithText(FilledButton, 'Copy'));
    await pumpState(tester);

    expect(clipboard.values, isEmpty);
    expect(repository.calls, isEmpty);
    expect(find.text('Copied'), findsNothing);

    controller.endMaintenance();
    await tester.tap(find.widgetWithText(FilledButton, 'Copy'));
    await pumpState(tester);
    await tester.pump(const Duration(milliseconds: 400));

    expect(clipboard.values, ['exact body']);
    expect(find.text('Copied'), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('cycle started before maintenance completes under the barrier', (
    tester,
  ) async {
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(entries: [testEntry('one', body: 'exact body')]),
    );
    await pumpState(tester);
    final gate = Completer<void>();
    clipboard.gate = gate;

    await tester.tap(find.widgetWithText(FilledButton, 'Copy'));
    await pumpState(tester);
    expect(clipboard.values, ['exact body']);
    expect(find.text('Copied'), findsNothing);

    final barrier = controller.beginMaintenance();
    var resolved = false;
    unawaited(barrier.then((_) => resolved = true));

    clipboard.gate = null;
    gate.complete();
    await pumpState(tester);
    await tester.pump(const Duration(milliseconds: 400));

    expect(repository.calls, contains('markCopied:one'));
    expect(find.text('Copied'), findsOneWidget);
    await barrier;
    expect(resolved, isTrue);
    await disposeApp(tester);
  });

  testWidgets('reveals selection moved to the list end', (tester) async {
    tester.view.physicalSize = const Size(1200, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(
        entries: [
          for (var index = 1; index <= 30; index++)
            testEntry(
              'entry-$index',
              title: 'Prompt ${index.toString().padLeft(2, '0')}',
            ),
        ],
      ),
    );
    await pumpState(tester);
    await tester.tap(find.text('Prompt 01').first);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));

    expect(controller.state.selectedEntryId, 'entry-30');
    expect(find.byKey(const ValueKey('entry-entry-30')), findsOneWidget);
    await disposeApp(tester);
  });

  // === Keyboard and focus ===

  testWidgets('draws a distinct list keyboard focus outline', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpApp(tester);
    repository.emit(LibrarySnapshot(entries: [testEntry('one')]));
    await pumpState(tester);

    BoxDecoration decoration() =>
        tester
                .widget<DecoratedBox>(
                  find.byKey(const Key('library-list-focus-outline')),
                )
                .decoration
            as BoxDecoration;

    expect((decoration().border! as Border).top.color, Colors.transparent);
    await tester.tap(find.text('Prompt title').first);
    await tester.pump();
    final focused = decoration().border! as Border;
    expect(focused.top.color, const Color(0x8A315E9E));
    expect(focused.top.width, 1);
    await disposeApp(tester);
  });

  testWidgets('focuses a mounted search without an extra frame', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpApp(tester);
    repository.emit(LibrarySnapshot(entries: [testEntry('one')]));
    await pumpState(tester);
    await tester.tap(find.text('Prompt title').first);
    await pumpState(tester);
    TextField search() =>
        tester.widget<TextField>(find.byKey(const Key('library-search')));
    expect(search().focusNode?.hasFocus, isFalse);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.idle();

    expect(search().focusNode?.hasFocus, isTrue);
    await disposeApp(tester);
  });

  testWidgets('Command-F returns narrow detail to focused search', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpApp(tester);
    repository.emit(LibrarySnapshot(entries: [testEntry('one')]));
    await pumpState(tester);
    await tester.tap(find.text('Prompt title').first);
    await tester.pump();
    expect(find.byKey(const Key('library-search')), findsNothing);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump(const Duration(milliseconds: 200));

    final search = tester.widget<TextField>(
      find.byKey(const Key('library-search')),
    );
    expect(search.focusNode?.hasFocus, isTrue);
    await disposeApp(tester);
  });

  testWidgets('opens create dialog with Command-N', (tester) async {
    await pumpApp(tester);
    repository.emit(const LibrarySnapshot.empty());
    await pumpState(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();

    expect(find.byKey(const Key('editor-title')), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pump(const Duration(seconds: 1));
    await disposeApp(tester);
  });

  testWidgets('preserves text editing behavior for Control-N', (tester) async {
    await pumpApp(tester);
    repository.emit(const LibrarySnapshot.empty());
    await pumpState(tester);
    final searchFinder = find.byKey(const Key('library-search'));
    await tester.tap(searchFinder);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(find.byKey(const Key('editor-title')), findsNothing);
    expect(tester.widget<TextField>(searchFinder).focusNode?.hasFocus, isTrue);
    await disposeApp(tester);
  });

  // === Detail and dialog layout ===

  testWidgets('bounds the detail text sheet to a short body', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(entries: [testEntry('one', body: 'one short line')]),
    );
    await pumpState(tester);
    await tester.tap(find.text('Prompt title').first);
    await pumpState(tester);

    final pane = tester.getRect(find.byType(LibraryDetail));
    final sheet = tester.getRect(find.byKey(const Key('detail-text-sheet')));
    expect(sheet.height, lessThan(pane.height / 2));

    final copy = tester.getRect(find.widgetWithText(FilledButton, 'Copy'));
    expect(pane.bottom - copy.bottom, lessThan(40));
    await disposeApp(tester);
  });

  testWidgets('keeps a long body inside the detail pane', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(
        entries: [
          testEntry(
            'one',
            body: [for (var line = 0; line < 200; line++) 'line \$line']
                .join('\n'),
          ),
        ],
      ),
    );
    await pumpState(tester);
    await tester.tap(find.text('Prompt title').first);
    await pumpState(tester);

    final pane = tester.getRect(find.byType(LibraryDetail));
    final sheet = tester.getRect(find.byKey(const Key('detail-text-sheet')));
    expect(sheet.height, lessThanOrEqualTo(pane.height));

    expect(
      find.descendant(
        of: find.byKey(const Key('detail-text-sheet')),
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
    );
    expect(
      tester.getRect(find.byType(SelectableText)).height,
      greaterThan(sheet.height),
    );

    final copy = tester.getRect(find.widgetWithText(FilledButton, 'Copy'));
    expect(copy.bottom, lessThanOrEqualTo(pane.bottom));
    await disposeApp(tester);
  });

  testWidgets('keeps dialog floating labels clear of the content edge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpApp(tester);
    repository.emit(const LibrarySnapshot.empty());
    await pumpState(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(
      find.byKey(const Key('editor-title')),
      'Draft title',
    );
    await tester.pump(const Duration(milliseconds: 400));

    final content = tester.getRect(find.byKey(const Key('editor-content')));
    final label = tester.getRect(find.text('Title'));
    expect(label.top, greaterThanOrEqualTo(content.top + 6));

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pump(const Duration(seconds: 1));
    await disposeApp(tester);
  });

  testWidgets('keeps taxonomy floating labels clear of the tab bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpApp(tester);
    repository.emit(const LibrarySnapshot.empty());
    await pumpState(tester);

    await tester.tap(find.byTooltip('Manage categories and tags'));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(find.byType(TextField).last, 'Draft category');
    await tester.pump(const Duration(milliseconds: 400));
    final tabBar = tester.getRect(find.byType(TabBar));
    expect(
      tester.getRect(find.text('New category')).top,
      greaterThanOrEqualTo(tabBar.bottom + 6),
    );

    await tester.tap(find.text('Tags'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField).last, 'Draft tag');
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester.getRect(find.text('New tag')).top,
      greaterThanOrEqualTo(tabBar.bottom + 6),
    );

    await tester.tap(find.widgetWithText(TextButton, 'Close'));
    await tester.pump(const Duration(seconds: 1));
    await disposeApp(tester);
  });

  // === Entry mutations ===

  testWidgets('favorites, archives, restores, and confirms deletion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpApp(tester);
    repository.emit(LibrarySnapshot(entries: [testEntry('one')]));
    await pumpState(tester);

    await tester.tap(find.byTooltip('Add to favorites'));
    await pumpState(tester);
    expect(repository.calls, contains('setFavorite:one:true'));

    await tester.tap(find.byTooltip('Archive'));
    await pumpState(tester);
    expect(find.text('Your library is empty'), findsOneWidget);

    await tester.tap(find.text('Archived'));
    await pumpState(tester);
    await tester.tap(find.byTooltip('Restore'));
    await pumpState(tester);
    expect(repository.calls, contains('setArchived:one:false'));

    await tester.tap(find.text('All prompts'));
    await pumpState(tester);
    await tester.tap(find.byTooltip('Delete'));
    await pumpState(tester);
    expect(find.text('Delete prompt?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await pumpState(tester);
    expect(repository.calls, contains('deleteEntry:one'));
    await disposeApp(tester);
  });

  testWidgets('disables only an active favorite action', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpApp(tester);
    repository.emit(LibrarySnapshot(entries: [testEntry('one')]));
    await pumpState(tester);
    final gate = Completer<void>();
    repository.nextMutationGate = gate;

    final pending = controller.setFavorite('one', isFavorite: true);
    await pumpState(tester);

    expect(actionButton(tester, 'Add to favorites').onPressed, isNull);
    expect(actionButton(tester, 'Archive').onPressed, isNotNull);
    expect(actionButton(tester, 'Delete').onPressed, isNotNull);
    gate.complete();
    await pending;
    await disposeApp(tester);
  });

  testWidgets('disables only an active archive action', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpApp(tester);
    repository.emit(LibrarySnapshot(entries: [testEntry('one')]));
    await pumpState(tester);
    final gate = Completer<void>();
    repository.nextMutationGate = gate;

    final pending = controller.setArchived('one', isArchived: true);
    await pumpState(tester);

    expect(actionButton(tester, 'Archive').onPressed, isNull);
    expect(actionButton(tester, 'Add to favorites').onPressed, isNotNull);
    expect(actionButton(tester, 'Delete').onPressed, isNotNull);
    gate.complete();
    await pending;
    await disposeApp(tester);
  });

  testWidgets('disables only an active delete action', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpApp(tester);
    repository.emit(LibrarySnapshot(entries: [testEntry('one')]));
    await pumpState(tester);
    final gate = Completer<void>();
    repository.nextMutationGate = gate;

    final pending = controller.deleteEntry('one');
    await pumpState(tester);

    expect(actionButton(tester, 'Delete').onPressed, isNull);
    expect(actionButton(tester, 'Add to favorites').onPressed, isNotNull);
    expect(actionButton(tester, 'Archive').onPressed, isNotNull);
    gate.complete();
    await pending;
    await disposeApp(tester);
  });

  // === Transfer entry point ===

  testWidgets('transfer entry opens the route with an empty library', (
    tester,
  ) async {
    await pumpApp(tester);
    repository.emit(const LibrarySnapshot.empty());
    await pumpState(tester);

    expect(find.byKey(const Key('library-transfer')), findsOneWidget);

    await tester.tap(find.byKey(const Key('library-transfer')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Transfer library'),
      ),
      findsOneWidget,
    );
    expect(find.text('Export JSON'), findsOneWidget);
    expect(find.byType(LibraryTransferScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(LibraryTransferScreen), findsNothing);
    expect(find.text('Your library is empty'), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('transfer entry opens from wide and narrow windows', (
    tester,
  ) async {
    for (final size in [const Size(1200, 800), const Size(700, 800)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await pumpApp(tester);
      repository.emit(
        LibrarySnapshot(entries: [testEntry('one', title: 'Alpha')]),
      );
      await pumpState(tester);

      expect(find.byKey(const Key('library-transfer')), findsOneWidget);
      await tester.tap(find.byKey(const Key('library-transfer')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(LibraryTransferScreen), findsOneWidget);
      expect(find.text('Export JSON'), findsOneWidget);

      await disposeApp(tester);
      await tester.pumpWidget(const SizedBox.shrink());
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('re-entering the transfer route shows the current owner state', (
    tester,
  ) async {
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(entries: [testEntry('one', title: 'Alpha')]),
    );
    await pumpState(tester);
    await tester.runAsync(
      () => transfer.prepareExport(DocumentExportKind.json),
    );
    await pumpState(tester);

    await tester.tap(find.byKey(const Key('library-transfer')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const Key('transfer-export-name')),
      findsOneWidget,
      reason: 'the opened route shows the owner state, not a fresh screen',
    );

    await tester.pageBack();
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('library-transfer')));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('transfer-export-name')),
      findsOneWidget,
      reason: 're-entering shows the state that survived the route closure',
    );
    expect(find.byKey(const Key('transfer-idle')), findsNothing);
    await disposeApp(tester);
  });

  testWidgets('transfer entry is unreachable while the editor dialog is open', (
    tester,
  ) async {
    final pushedRouteTypes = <String>[];
    final observer = _RouteTypeObserver(pushedRouteTypes);
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: LibraryScreen(
          controller: controller,
          clipboard: clipboard,
          transfer: transfer,
        ),
      ),
    );
    repository.emit(
      LibrarySnapshot(entries: [testEntry('one', title: 'Alpha')]),
    );
    await pumpState(tester);
    final baselinePushes = pushedRouteTypes.length;

    await tester.tap(find.byTooltip('New prompt'));
    await tester.pumpAndSettle();

    expect(find.text('New prompt'), findsOneWidget);
    expect(
      find.byType(LibraryTransferScreen),
      findsNothing,
      reason: 'no transfer route exists at any moment while the editor is open',
    );
    expect(
      pushedRouteTypes.sublist(baselinePushes),
      hasLength(1),
      reason:
          'opening the editor pushed exactly its dialog route and nothing '
          'else: ${pushedRouteTypes.join(', ')}',
    );
    expect(pushedRouteTypes.last, startsWith('DialogRoute'));
    expect(
      find.byType(ModalBarrier),
      findsWidgets,
      reason: 'the modal barrier covers the transfer entry',
    );

    await tester.tap(
      find.byKey(const Key('library-transfer')),
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byType(LibraryTransferScreen),
      findsNothing,
      reason: 'the dialog intercepts the tap, so no transfer route opens',
    );
    expect(
      pushedRouteTypes
          .sublist(baselinePushes)
          .where((type) => type.contains('MaterialPageRoute')),
      isEmpty,
      reason: 'the navigator never pushed a transfer route',
    );
    await disposeApp(tester);
  });

  testWidgets('transfer entry is unreachable while the delete dialog is open', (
    tester,
  ) async {
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(entries: [testEntry('one', title: 'Alpha')]),
    );
    await pumpState(tester);

    await tester.tap(find.byTooltip('Delete'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Delete prompt?'), findsOneWidget);
    expect(
      find.byType(ModalBarrier),
      findsWidgets,
      reason: 'the modal barrier covers the transfer entry',
    );

    await tester.tap(
      find.byKey(const Key('library-transfer')),
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byType(LibraryTransferScreen),
      findsNothing,
      reason: 'the dialog intercepts the tap, so no transfer route opens',
    );
    await disposeApp(tester);
  });

  testWidgets('transfer entry announces its tooltip', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(entries: [testEntry('one', title: 'Alpha')]),
    );
    await pumpState(tester);

    expect(
      tester.getSemantics(find.byKey(const Key('library-transfer'))).tooltip,
      'Transfer library',
    );
    handle.dispose();
    await disposeApp(tester);
  });

  testWidgets('keyboard traversal reaches the transfer entry and opens it', (
    tester,
  ) async {
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(entries: [testEntry('one', title: 'Alpha')]),
    );
    await pumpState(tester);

    var focused = _focusInside(const Key('library-transfer'));
    for (var i = 0; i < 12 && !focused; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      focused = _focusInside(const Key('library-transfer'));
    }
    expect(focused, isTrue, reason: 'Tab reaches the transfer entry');

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(LibraryTransferScreen), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await disposeApp(tester);
  });

  testWidgets('action row with the transfer entry survives large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(700, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 3.1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(entries: [testEntry('one', title: 'Alpha')]),
    );
    await pumpState(tester);

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const Key('library-transfer'))).width,
      greaterThan(0),
      reason: 'the entry keeps a positive size at the accessibility scale',
    );
    await disposeApp(tester);
  });

  testWidgets('a library stream error is shown without reaching the zone', (
    tester,
  ) async {
    final zoneErrors = <Object>[];
    await runZonedGuarded(() async {
      await pumpApp(tester);
      repository.emit(
        LibrarySnapshot(entries: [testEntry('one', title: 'Alpha')]),
      );
      await pumpState(tester);

      repository.emitObservationError(StateError('observer crashed'));
      await pumpState(tester);
    }, (error, stackTrace) => zoneErrors.add(error));
    expect(zoneErrors, isEmpty);
    expect(
      find.text('The library could not be updated. Try again.'),
      findsOneWidget,
      reason: 'the surface reports the stream error to the user',
    );
    await disposeApp(tester);
  });

  Future<void> pumpFullMacActions(WidgetTester tester) async {
    final quick = QuickPanelController(
      libraryController: controller,
      clipboard: clipboard,
      port: const UnavailableMacQuickPanel(),
    );
    await tester.pumpWidget(
      PromptLibraryApp(
        applicationSurface: ApplicationSurface.desktop,
        controller: controller,
        clipboard: clipboard,
        transferController: transfer,
        quickPanelController: quick,
        quickAccessSupported: true,
      ),
    );
    repository.emit(
      LibrarySnapshot(entries: [testEntry('one', title: 'Alpha')]),
    );
    await pumpState(tester);
    await tester.runAsync(quick.dispose);
  }

  Finder searchEditable() {
    return find.descendant(
      of: find.byKey(const Key('library-search')),
      matching: find.byType(EditableText),
    );
  }

  testWidgets('search keeps a usable width in the mid-width window', (
    tester,
  ) async {
    for (final width in [720.0, 800.0, 1039.0]) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpFullMacActions(tester);

      expect(find.byKey(const Key('library-transfer')), findsOneWidget);
      expect(find.byTooltip('New prompt'), findsOneWidget);
      expect(find.byKey(const Key('hotkey-settings')), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(searchEditable()).width,
        greaterThanOrEqualTo(120),
        reason: 'window $width must keep a usable search input',
      );
      await disposeApp(tester);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('search keeps a positive width at large text in the mid window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 3.1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await pumpFullMacActions(tester);

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(searchEditable()).width,
      greaterThan(0),
      reason: 'the search input survives the accessibility scale',
    );
    expect(
      tester.getSize(find.byKey(const Key('library-transfer'))).width,
      greaterThan(0),
    );
    await disposeApp(tester);
  });

  // === View reset after replacement ===

  Future<void> driveRestoreFlow(
    WidgetTester tester,
    LibrarySnapshot replacement,
  ) async {
    files.pickResult = DocumentPicked(
      fileName: 'library.json',
      bytes: LibraryJsonCodec().encode(
        LibraryDocument(snapshot: replacement, exportedAt: DateTime.utc(2026)),
      ),
    );
    await tester.runAsync(() => transfer.startImport());
    await tester.runAsync(() => transfer.continueFromReview());
    files.exportResult = DocumentSaved(path: '/tmp/backup.json');
    await tester.runAsync(() => transfer.createBackupCopy());
    final current = await repository.getSnapshot();
    files.pickResult = DocumentPicked(
      fileName: 'backup.json',
      bytes: LibraryJsonCodec().encode(
        LibraryDocument(snapshot: current, exportedAt: DateTime.utc(2026)),
      ),
    );
    await tester.runAsync(() => transfer.verifyBackupCopy());
    await tester.runAsync(() => transfer.apply());
  }

  testWidgets('replacement resets search, filter, and selection', (
    tester,
  ) async {
    await pumpApp(tester);
    final category = testCategory('category-1', 'Work');
    repository.emit(
      LibrarySnapshot(
        entries: [
          testEntry('kept-a', title: 'Alpha', categoryId: 'category-1'),
          testEntry('kept-b', title: 'Beta'),
          testEntry('kept-c', title: 'Gamma', isArchived: true),
        ],
        categories: [category],
      ),
    );
    await pumpState(tester);
    await tester.enterText(find.byKey(const Key('library-search')), 'Beta');
    await pumpState(tester);
    controller.setCategoryFilter('category-1');
    await pumpState(tester);
    expect(controller.state.filter.searchQuery, 'Beta');

    await driveRestoreFlow(
      tester,
      LibrarySnapshot(
        entries: [
          testEntry('restored-1', title: 'Restored One'),
          testEntry('restored-2', title: 'Restored Two'),
        ],
      ),
    );
    await pumpState(tester);

    expect(controller.state.filter, LibraryFilter());
    expect(controller.state.selectedEntryId, 'restored-1');
    expect(
      find.text('Restored One'),
      findsNWidgets(2),
      reason: 'the restored library is visible under the default view',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('library-search')))
          .controller
          ?.text,
      isEmpty,
      reason: 'the surface search field is cleared',
    );
    await disposeApp(tester);
  });

  testWidgets('replacement resets the archived scope and narrow detail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(700, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(
        entries: [
          testEntry('kept-a', title: 'Alpha'),
          testEntry('kept-b', title: 'Beta'),
          testEntry('kept-c', title: 'Gamma', isArchived: true),
        ],
      ),
    );
    await pumpState(tester);
    controller.setFilterScope(LibraryFilterScope.archived);
    await pumpState(tester);
    expect(find.text('Gamma'), findsOneWidget);
    expect(find.text('Alpha'), findsNothing);

    await driveRestoreFlow(
      tester,
      LibrarySnapshot(
        entries: [
          testEntry('restored-1', title: 'Restored One'),
          testEntry('restored-2', title: 'Restored Two'),
        ],
      ),
    );
    await pumpState(tester);

    expect(controller.state.filter.scope, LibraryFilterScope.active);
    expect(find.text('Restored One'), findsOneWidget);
    expect(
      find.byKey(const Key('library-search')),
      findsOneWidget,
      reason: 'the narrow detail view is closed back to the result list',
    );
    await disposeApp(tester);
  });

  testWidgets('raycast import does not reset the view', (tester) async {
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(entries: [testEntry('kept-a', title: 'Alpha')]),
    );
    await pumpState(tester);
    await tester.enterText(find.byKey(const Key('library-search')), 'Alp');
    await pumpState(tester);
    expect(controller.state.filter.searchQuery, 'Alp');

    files.pickResult = DocumentPicked(
      fileName: 'snippets.json',
      bytes: Uint8List.fromList(
        '[{"name":"Imported","text":"body"}]'.codeUnits,
      ),
    );
    await tester.runAsync(() => transfer.startImport());
    await tester.runAsync(() => transfer.continueFromReview());
    files.exportResult = DocumentSaved(path: '/tmp/backup.json');
    await tester.runAsync(() => transfer.createBackupCopy());
    final current = await repository.getSnapshot();
    files.pickResult = DocumentPicked(
      fileName: 'backup.json',
      bytes: LibraryJsonCodec().encode(
        LibraryDocument(snapshot: current, exportedAt: DateTime.utc(2026)),
      ),
    );
    await tester.runAsync(() => transfer.verifyBackupCopy());
    await tester.runAsync(() => transfer.apply());
    await pumpState(tester);

    expect(transfer.state, isA<LibraryTransferImportDone>());
    expect(
      controller.state.filter.searchQuery,
      'Alp',
      reason: 'an import must not reset the view',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('library-search')))
          .controller
          ?.text,
      'Alp',
    );
    await disposeApp(tester);
  });

  testWidgets('done closes the transfer route back to the library', (
    tester,
  ) async {
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(entries: [testEntry('kept-a', title: 'Alpha')]),
    );
    await pumpState(tester);
    await tester.tap(find.byKey(const Key('library-transfer')));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byType(LibraryTransferScreen), findsOneWidget);

    await driveRestoreFlow(
      tester,
      LibrarySnapshot(
        entries: [testEntry('restored-1', title: 'Restored One')],
      ),
    );
    await pumpState(tester);
    expect(find.byKey(const Key('transfer-restore-done')), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(LibraryTransferScreen), findsNothing);
    expect(find.byKey(const Key('library-search')), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('failure and cancel do not reset the view', (tester) async {
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(entries: [testEntry('kept-a', title: 'Alpha')]),
    );
    await pumpState(tester);
    await tester.enterText(find.byKey(const Key('library-search')), 'Alp');
    await pumpState(tester);
    expect(controller.state.filter.searchQuery, 'Alp');

    files.pickResult = DocumentPicked(
      fileName: 'library.json',
      bytes: LibraryJsonCodec().encode(
        LibraryDocument(
          snapshot: LibrarySnapshot(
            entries: [testEntry('restored-1', title: 'Restored One')],
          ),
          exportedAt: DateTime.utc(2026),
        ),
      ),
    );
    await tester.runAsync(() => transfer.startImport());
    await tester.runAsync(() => transfer.continueFromReview());
    files.exportResult = DocumentSaved(path: '/tmp/backup.json');
    await tester.runAsync(() => transfer.createBackupCopy());
    final current = await repository.getSnapshot();
    files.pickResult = DocumentPicked(
      fileName: 'backup.json',
      bytes: LibraryJsonCodec().encode(
        LibraryDocument(snapshot: current, exportedAt: DateTime.utc(2026)),
      ),
    );
    await tester.runAsync(() => transfer.verifyBackupCopy());
    repository.nextFailure = LibraryFailure.databaseFailure(
      code: LibraryDatabaseFailureCode.transactionFailed,
    );
    await tester.runAsync(() => transfer.apply());
    await pumpState(tester);

    expect(transfer.state, isA<LibraryTransferFailed>());
    expect(controller.state.filter.searchQuery, 'Alp');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('library-search')))
          .controller
          ?.text,
      'Alp',
    );

    transfer.cancel();
    await pumpState(tester);
    expect(transfer.state, isA<LibraryTransferIdle>());
    expect(controller.state.filter.searchQuery, 'Alp');
    await disposeApp(tester);
  });
}

/// Records the runtime type of every pushed route.
final class _RouteTypeObserver extends NavigatorObserver {
  _RouteTypeObserver(this.pushed);

  final List<String> pushed;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route.runtimeType.toString());
  }
}

/// Reports whether keyboard focus sits inside the widget carrying [key].
bool _focusInside(Key key) {
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

/// Recording clipboard fake.
final class _TestClipboard implements LibraryClipboard {
  /// Recorded clipboard writes.
  final List<String> values = [];

  /// Blocks the next write until completed.
  Completer<void>? gate;

  /// Records text and awaits the optional gate.
  @override
  Future<void> writeText(String text) async {
    values.add(text);
    await gate?.future;
  }
}

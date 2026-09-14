/// Full library widget tests.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/app/application_surface.dart';
import 'package:prompt_library/src/app/prompt_library_app.dart';
import 'package:prompt_library/src/library/models/library_snapshot.dart';
import 'package:prompt_library/src/library/presentation/library_clipboard.dart';
import 'package:prompt_library/src/library/presentation/library_controller.dart';
import 'package:prompt_library/src/library/presentation/library_detail.dart';

import '../../support/library_test_support.dart';

void main() {
  late TestLibraryRepository repository;
  late LibraryController controller;
  late _TestClipboard clipboard;

  setUp(() {
    repository = TestLibraryRepository();
    controller = LibraryController(repository: repository);
    clipboard = _TestClipboard();
  });

  tearDown(() async {
    await controller.dispose();
    await repository.close();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      PromptLibraryApp(
        applicationSurface: ApplicationSurface.desktop,
        controller: controller,
        clipboard: clipboard,
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

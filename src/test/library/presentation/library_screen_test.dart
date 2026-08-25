/// Full library widget tests.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/app/prompt_library_app.dart';
import 'package:prompt_library/src/library/models/library_snapshot.dart';
import 'package:prompt_library/src/library/presentation/library_clipboard.dart';
import 'package:prompt_library/src/library/presentation/library_controller.dart';

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
      PromptLibraryApp(controller: controller, clipboard: clipboard),
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

  testWidgets('renders loading then actionable empty state', (tester) async {
    await pumpApp(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repository.emit(const LibrarySnapshot.empty());
    await pumpState(tester);

    expect(find.text('Your library is empty'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'New prompt'), findsOneWidget);
    await disposeApp(tester);
  });

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
}

final class _TestClipboard implements LibraryClipboard {
  final List<String> values = [];

  @override
  Future<void> writeText(String text) async {
    values.add(text);
  }
}

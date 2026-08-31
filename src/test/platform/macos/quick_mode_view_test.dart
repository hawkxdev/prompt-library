import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/library/models/library_failure.dart';
import 'package:prompt_library/src/library/presentation/library_clipboard.dart';
import 'package:prompt_library/src/library/presentation/library_list.dart';
import 'package:prompt_library/src/platform/macos/quick_mode_view.dart';

import '../../support/library_test_support.dart';
import 'quick_panel_widget_test_support.dart';

void main() {
  late QuickPanelWidgetHarness harness;

  setUp(() {
    harness = QuickPanelWidgetHarness();
  });

  tearDown(() async {
    await harness.dispose();
  });

  Future<void> pumpQuick(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: QuickModeView(
          libraryController: harness.library,
          quickPanelController: harness.quick,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('focuses search, filters, and moves shared selection', (
    tester,
  ) async {
    await harness.enterQuick([
      testEntry('entry-1', title: 'Alpha'),
      testEntry('entry-2', title: 'Beta'),
    ]);
    await pumpQuick(tester);

    final search = tester.widget<TextField>(
      find.byKey(const Key('quick-search')),
    );
    expect(search.focusNode?.hasFocus, isTrue);
    expect(harness.library.state.selectedEntryId, 'entry-1');

    await tester.enterText(find.byKey(const Key('quick-search')), 'Beta');
    await tester.pump();
    expect(harness.library.state.filter.searchQuery, 'Beta');
    expect(harness.library.state.selectedEntryId, 'entry-2');

    await tester.enterText(find.byKey(const Key('quick-search')), '');
    await tester.pump();
    expect(harness.library.state.selectedEntryId, 'entry-2');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(harness.library.state.selectedEntryId, 'entry-1');
  });

  testWidgets('repeated hotkey refocuses search after list focus', (
    tester,
  ) async {
    await harness.enterQuick([
      testEntry('entry-1', title: 'Alpha'),
      testEntry('entry-2', title: 'Beta'),
    ]);
    await pumpQuick(tester);

    await tester.tap(find.text('Beta'));
    await tester.pump();
    final list = tester.widget<LibraryList>(find.byType(LibraryList));
    expect(list.focusNode.hasFocus, isTrue);

    harness.port.emitQuickModeRequest();
    await tester.pump();
    await tester.pump();

    final search = tester.widget<TextField>(
      find.byKey(const Key('quick-search')),
    );
    expect(search.focusNode?.hasFocus, isTrue);
    expect(harness.library.state.filter.searchQuery, isEmpty);
    expect(harness.library.state.selectedEntryId, 'entry-1');
  });

  testWidgets('Enter copies exact body and shows bounded confirmation', (
    tester,
  ) async {
    const body = '  first line\n\nlast line  ';
    await harness.enterQuick([testEntry('entry-1', body: body)]);
    await pumpQuick(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(harness.clipboard.values, [body]);
    expect(find.byKey(const Key('quick-copied')), findsOneWidget);
    expect(harness.port.hideCalls, isEmpty);

    harness.delay.complete();
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('quick-copied')), findsNothing);
    expect(harness.port.hideCalls, [true]);
  });

  testWidgets('shows retained metadata failure over usable quick results', (
    tester,
  ) async {
    await harness.enterQuick([testEntry('entry-1')]);
    harness.repository.nextFailure = const LibraryFailure.databaseFailure(
      code: LibraryDatabaseFailureCode.transactionFailed,
    );
    await pumpQuick(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(find.byKey(const Key('quick-library-failure')), findsOneWidget);
    expect(
      find.text('The library could not save this change.'),
      findsOneWidget,
    );

    harness.delay.complete();
    await tester.pump();
  });

  testWidgets('Escape hides without clipboard or metadata mutation', (
    tester,
  ) async {
    await harness.enterQuick([testEntry('entry-1')]);
    await pumpQuick(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(harness.clipboard.values, isEmpty);
    expect(harness.repository.calls, isEmpty);
    expect(harness.port.hideCalls, [true]);
  });

  testWidgets('clipboard failure remains visible and does not hide', (
    tester,
  ) async {
    await harness.enterQuick([testEntry('entry-1')]);
    harness.clipboard.nextError = const LibraryClipboardFailure();
    await pumpQuick(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(find.byKey(const Key('quick-copy-failure')), findsOneWidget);
    expect(harness.repository.calls, isEmpty);
    expect(harness.port.hideCalls, isEmpty);
  });

  testWidgets('empty results keep Escape available and Enter inert', (
    tester,
  ) async {
    await harness.enterQuick([]);
    await pumpQuick(tester);

    expect(find.byKey(const Key('quick-empty')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(harness.clipboard.values, isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(harness.port.hideCalls, [true]);
  });
}

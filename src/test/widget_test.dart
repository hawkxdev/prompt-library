/// Application surface contract.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/app/application_surface.dart';
import 'package:prompt_library/src/app/prompt_library_app.dart';
import 'package:prompt_library/src/library/models/library_snapshot.dart';
import 'package:prompt_library/src/library/presentation/library_clipboard.dart';
import 'package:prompt_library/src/library/presentation/library_controller.dart';
import 'package:prompt_library/src/platform/macos/quick_mode_view.dart';
import 'package:prompt_library/src/platform/macos/quick_panel_controller.dart';
import 'package:prompt_library/src/platform/macos/unavailable_mac_quick_panel.dart';

import 'platform/macos/quick_panel_widget_test_support.dart';
import 'support/library_test_support.dart';

void main() {
  late TestLibraryRepository repository;
  late LibraryController controller;

  setUp(() {
    repository = TestLibraryRepository();
    controller = LibraryController(repository: repository);
  });

  tearDown(() async {
    await controller.dispose();
    await repository.close();
  });

  for (final applicationSurface in ApplicationSurface.values) {
    testWidgets('application shows actionable empty library on '
        '${applicationSurface.name}', (tester) async {
      final quick = QuickPanelController(
        libraryController: controller,
        clipboard: const _NoopClipboard(),
        port: const UnavailableMacQuickPanel(),
      );
      await quick.initialize(QuickPanelWidgetHarness.defaultSpec);
      repository.emit(const LibrarySnapshot.empty());
      await tester.pumpWidget(
        PromptLibraryApp(
          applicationSurface: applicationSurface,
          controller: controller,
          clipboard: const _NoopClipboard(),
          quickPanelController: quick,
          quickAccessSupported: false,
        ),
      );
      await tester.pump();

      expect(find.text('Your library is empty'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'New prompt'), findsOneWidget);
      expect(find.byKey(const Key('hotkey-settings')), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump();
      await tester.runAsync(quick.dispose);
    });
  }

  testWidgets('application switches one object graph into quick mode', (
    tester,
  ) async {
    final quickHarness = QuickPanelWidgetHarness();
    addTearDown(quickHarness.dispose);
    quickHarness.repository.emit(const LibrarySnapshot.empty());
    await quickHarness.quick.initialize(QuickPanelWidgetHarness.defaultSpec);

    await tester.pumpWidget(
      PromptLibraryApp(
        applicationSurface: ApplicationSurface.mobile,
        controller: quickHarness.library,
        clipboard: quickHarness.clipboard,
        quickPanelController: quickHarness.quick,
        quickAccessSupported: true,
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('hotkey-settings')), findsOneWidget);
    expect(find.byType(QuickModeView), findsNothing);

    await tester.tap(find.byKey(const Key('hotkey-settings')));
    await tester.pumpAndSettle();
    expect(find.text('Global shortcut'), findsOneWidget);

    quickHarness.port.emitQuickModeRequest();
    await tester.pumpAndSettle();

    expect(find.byType(QuickModeView), findsOneWidget);
    expect(find.byKey(const Key('quick-search')), findsOneWidget);
    expect(find.text('Global shortcut'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

final class _NoopClipboard implements LibraryClipboard {
  const _NoopClipboard();

  @override
  Future<void> writeText(String text) async {}
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/platform/macos/hotkey_settings_dialog.dart';
import 'package:prompt_library/src/platform/macos/mac_quick_panel_port.dart';

import 'quick_panel_widget_test_support.dart';

void main() {
  late QuickPanelWidgetHarness harness;

  setUp(() async {
    harness = QuickPanelWidgetHarness();
    await harness.quick.initialize(QuickPanelWidgetHarness.defaultSpec);
  });

  tearDown(() async {
    await harness.dispose();
  });

  Future<void> pumpDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: HotKeySettingsDialog(controller: harness.quick)),
    );
    await tester.pump();
  }

  testWidgets('shows Control Option Space as the registered default', (
    tester,
  ) async {
    await pumpDialog(tester);

    expect(find.text('Space'), findsOneWidget);
    expect(
      tester
          .widget<FilterChip>(find.byKey(const ValueKey('hotkey-control')))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<FilterChip>(find.byKey(const ValueKey('hotkey-option')))
          .selected,
      isTrue,
    );
    expect(find.text('Shortcut registered.'), findsOneWidget);
  });

  testWidgets('requires at least one modifier', (tester) async {
    await pumpDialog(tester);

    await tester.tap(find.byKey(const ValueKey('hotkey-control')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('hotkey-option')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('hotkey-save')));
    await tester.pump();

    expect(find.text('Select at least one modifier.'), findsOneWidget);
    expect(harness.port.registeredSpecs, [QuickPanelWidgetHarness.defaultSpec]);
  });

  testWidgets('disables actions while replacement is pending', (tester) async {
    harness.port.registrationGate = Completer<void>();
    await pumpDialog(tester);

    await tester.tap(find.byKey(const Key('hotkey-save')));
    await tester.pump();

    expect(find.text('Registering…'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Close'))
          .onPressed,
      isNull,
    );

    harness.port.registrationGate!.complete();
    await tester.pump();
    await tester.pump();
  });

  testWidgets('pending replacement blocks barrier and Escape dismissal', (
    tester,
  ) async {
    harness.port.registrationGate = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () =>
                  showHotKeySettingsDialog(context, controller: harness.quick),
              child: const Text('Open settings'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('hotkey-save')));
    await tester.pump();

    await tester.tapAt(const Offset(4, 4));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(find.text('Global shortcut'), findsOneWidget);
    harness.port.registrationGate!.complete();
    await tester.pump();
    await tester.pump();
  });

  final failures = <(MacQuickPanelResult, String)>[
    (
      const MacQuickPanelResult(
        MacQuickPanelResultKind.collision,
        diagnosticCode: -9878,
      ),
      'That shortcut is already registered. The previous shortcut remains active. (code -9878)',
    ),
    (
      const MacQuickPanelResult(MacQuickPanelResultKind.invalidShortcut),
      'Choose a valid key and modifier combination.',
    ),
    (
      const MacQuickPanelResult(MacQuickPanelResultKind.unavailable),
      'Global shortcuts are unavailable on this platform.',
    ),
    (
      const MacQuickPanelResult(
        MacQuickPanelResultKind.nativeFailure,
        diagnosticCode: -50,
      ),
      'The shortcut could not be registered. (code -50)',
    ),
  ];

  for (final (result, message) in failures) {
    testWidgets('${result.kind.name} retains the previous shortcut display', (
      tester,
    ) async {
      harness.port.registrationResults.add(result);
      await pumpDialog(tester);

      tester
          .widget<DropdownButtonFormField<int>>(
            find.byType(DropdownButtonFormField<int>),
          )
          .onChanged!(35);
      await tester.pump();
      await tester.tap(find.byKey(const Key('hotkey-save')));
      await tester.pump();
      await tester.pump();

      expect(find.text(message), findsOneWidget);
      expect(
        harness.quick.state.configuredHotKey,
        QuickPanelWidgetHarness.defaultSpec,
      );
      expect(find.text('Space'), findsOneWidget);
    });
  }

  testWidgets('successful replacement updates the configured shortcut', (
    tester,
  ) async {
    await pumpDialog(tester);

    tester
        .widget<DropdownButtonFormField<int>>(
          find.byType(DropdownButtonFormField<int>),
        )
        .onChanged!(35);
    await tester.pump();
    await tester.tap(find.byKey(const Key('hotkey-save')));
    await tester.pump();
    await tester.pump();

    expect(harness.quick.state.configuredHotKey.keyCode, 35);
    expect(find.text('P'), findsOneWidget);
    expect(find.text('Shortcut registered.'), findsOneWidget);
  });
}

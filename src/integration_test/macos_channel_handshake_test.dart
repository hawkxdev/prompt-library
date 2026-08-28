import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:prompt_library/src/platform/macos/mac_quick_panel_port.dart';
import 'package:prompt_library/src/platform/macos/method_channel_mac_quick_panel.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('macOS production channel completes registration handshake', (
    tester,
  ) async {
    final adapter = MethodChannelMacQuickPanel();
    addTearDown(adapter.dispose);

    final initial = await adapter.registrationState();
    expect(initial.kind, isA<MacQuickPanelResultKind>());
    expect(initial.diagnosticCode, anyOf(isNull, isA<int>()));
    expect(await adapter.registrationState(), initial);

    final first = HotKeySpec(
      keyCode: 122,
      modifiers: {HotKeyModifier.control, HotKeyModifier.option},
    );
    final replacement = HotKeySpec(
      keyCode: 120,
      modifiers: {HotKeyModifier.control, HotKeyModifier.option},
    );

    final registered = await adapter.registerHotKey(first);
    expect(registered.kind, MacQuickPanelResultKind.registered);
    expect(registered.diagnosticCode, isNull);
    expect(await adapter.registrationState(), registered);

    final repeated = await adapter.registerHotKey(first);
    expect(repeated.kind, MacQuickPanelResultKind.registered);
    expect(repeated, registered);
    expect(await adapter.registrationState(), repeated);

    final replaced = await adapter.registerHotKey(replacement);
    expect(replaced.kind, MacQuickPanelResultKind.registered);
    expect(replaced.diagnosticCode, anyOf(isNull, isA<int>()));
    expect(await adapter.registrationState(), replaced);

    await adapter.dispose();
    final verifier = MethodChannelMacQuickPanel();
    addTearDown(verifier.dispose);
    final afterDispose = await verifier.registrationState();
    expect(afterDispose.kind, MacQuickPanelResultKind.unavailable);
    expect(afterDispose.diagnosticCode, isNull);
  }, skip: !Platform.isMacOS);
}

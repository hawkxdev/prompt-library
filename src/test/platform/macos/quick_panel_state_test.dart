import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/platform/macos/mac_quick_panel_port.dart';
import 'package:prompt_library/src/platform/macos/quick_panel_state.dart';

void main() {
  final defaultSpec = HotKeySpec(
    keyCode: 49,
    modifiers: {HotKeyModifier.control, HotKeyModifier.option},
  );
  const registered = MacQuickPanelResult(MacQuickPanelResultKind.registered);
  const nativeFailure = MacQuickPanelResult(
    MacQuickPanelResultKind.nativeFailure,
    diagnosticCode: -1,
  );

  test('compares every observable value', () {
    final state = QuickPanelState(
      mode: QuickPanelMode.quick,
      configuredHotKey: defaultSpec,
      registration: registered,
      pendingAction: QuickPanelPendingAction.copy,
      copied: true,
      latestNativeFailure: nativeFailure,
    );
    final equal = state.copyWith();

    expect(equal, state);
    expect(equal.hashCode, state.hashCode);
    expect(state.copyWith(mode: QuickPanelMode.fullLibrary), isNot(state));
    expect(
      state.copyWith(pendingAction: QuickPanelPendingAction.dismiss),
      isNot(state),
    );
    expect(state.copyWith(copied: false), isNot(state));
    expect(state.copyWith(copyFailed: true), isNot(state));
    expect(state.copyWith(requestGeneration: 1), isNot(state));
    expect(
      state.copyWith(
        configuredHotKey: HotKeySpec(
          keyCode: 35,
          modifiers: {HotKeyModifier.command},
        ),
      ),
      isNot(state),
    );
    expect(state.copyWith(registration: nativeFailure), isNot(state));
    expect(state.copyWith(latestNativeFailure: null), isNot(state));
  });

  test('preserves values and explicitly clears nullable fields', () {
    final state = QuickPanelState(
      mode: QuickPanelMode.quick,
      configuredHotKey: defaultSpec,
      registration: registered,
      pendingAction: QuickPanelPendingAction.copy,
      copied: true,
      latestNativeFailure: nativeFailure,
    );

    final cleared = state.copyWith(
      pendingAction: null,
      latestNativeFailure: null,
    );

    expect(cleared.mode, QuickPanelMode.quick);
    expect(cleared.configuredHotKey, defaultSpec);
    expect(cleared.registration, registered);
    expect(cleared.copied, isTrue);
    expect(cleared.pendingAction, isNull);
    expect(cleared.latestNativeFailure, isNull);
  });

  test('copies registration and configured shortcut independently', () {
    final replacement = HotKeySpec(
      keyCode: 35,
      modifiers: {HotKeyModifier.command, HotKeyModifier.shift},
    );
    final state = QuickPanelState(
      mode: QuickPanelMode.fullLibrary,
      configuredHotKey: defaultSpec,
      registration: registered,
    );

    final changed = state.copyWith(
      configuredHotKey: replacement,
      registration: nativeFailure,
    );

    expect(changed.configuredHotKey, replacement);
    expect(changed.registration, nativeFailure);
    expect(changed.mode, QuickPanelMode.fullLibrary);
  });
}

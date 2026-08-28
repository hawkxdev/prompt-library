import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/platform/macos/mac_quick_panel_port.dart';

void main() {
  test('HotKeySpec serializes deterministically and compares by value', () {
    final spec = HotKeySpec(
      keyCode: 49,
      modifiers: {HotKeyModifier.option, HotKeyModifier.control},
    );
    expect(spec.toMap(), {
      'keyCode': 49,
      'modifiers': ['control', 'option'],
    });
    expect(
      spec,
      HotKeySpec(
        keyCode: 49,
        modifiers: {HotKeyModifier.control, HotKeyModifier.option},
      ),
    );
  });

  test('HotKeySpec owns and exposes an immutable modifier set', () {
    final input = <HotKeyModifier>{HotKeyModifier.command};
    final spec = HotKeySpec(keyCode: 49, modifiers: input);
    input.add(HotKeyModifier.shift);
    expect(spec.modifiers, {HotKeyModifier.command});
    expect(
      () => spec.modifiers.add(HotKeyModifier.shift),
      throwsUnsupportedError,
    );
  });

  test('equal specs hash equally regardless of modifier insertion order', () {
    final first = HotKeySpec(
      keyCode: 49,
      modifiers: {HotKeyModifier.command, HotKeyModifier.shift},
    );
    final second = HotKeySpec(
      keyCode: 49,
      modifiers: {HotKeyModifier.shift, HotKeyModifier.command},
    );
    expect(first, second);
    expect(first.hashCode, second.hashCode);
  });

  test('HotKeySpec rejects an empty modifier set', () {
    expect(
      () => HotKeySpec(keyCode: 49, modifiers: const {}),
      throwsArgumentError,
    );
  });

  test('result round trips and rejects malformed maps', () {
    const result = MacQuickPanelResult(
      MacQuickPanelResultKind.nativeFailure,
      diagnosticCode: 7,
    );
    expect(MacQuickPanelResult.fromMap(result.toMap()), result);
    expect(() => MacQuickPanelResult.fromMap(null), throwsFormatException);
    expect(() => MacQuickPanelResult.fromMap(42), throwsFormatException);
    expect(() => MacQuickPanelResult.fromMap(const {}), throwsFormatException);
    expect(
      () => MacQuickPanelResult.fromMap({'kind': 'unknown'}),
      throwsFormatException,
    );
    expect(
      () => MacQuickPanelResult.fromMap({
        'kind': 'registered',
        'diagnosticCode': '7',
      }),
      throwsFormatException,
    );
  });
}

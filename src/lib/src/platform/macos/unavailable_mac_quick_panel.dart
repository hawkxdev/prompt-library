import 'mac_quick_panel_port.dart';

/// Explicit capability used when macOS quick access is unavailable.
class UnavailableMacQuickPanel implements MacQuickPanelPort {
  const UnavailableMacQuickPanel();
  @override
  Stream<int> get quickModeRequests => const Stream<int>.empty();

  @override
  Stream<int> get fullLibraryRequests => const Stream<int>.empty();
  @override
  Future<MacQuickPanelResult> registerHotKey(HotKeySpec spec) async =>
      const MacQuickPanelResult(MacQuickPanelResultKind.unavailable);
  @override
  Future<MacQuickPanelResult> registrationState() async =>
      const MacQuickPanelResult(MacQuickPanelResultKind.unavailable);

  @override
  Future<MacQuickPanelResult> unregisterHotKey() async =>
      const MacQuickPanelResult(MacQuickPanelResultKind.unavailable);
  @override
  Future<MacQuickPanelResult> hideQuickMode({
    required bool restoreFocus,
    required int generation,
  }) async => const MacQuickPanelResult(MacQuickPanelResultKind.unavailable);
  @override
  Future<MacQuickPanelResult> showFullLibrary() async =>
      const MacQuickPanelResult(MacQuickPanelResultKind.unavailable);
  @override
  Future<void> dispose() async {}
}

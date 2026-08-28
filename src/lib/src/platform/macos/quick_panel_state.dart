import 'mac_quick_panel_port.dart';

/// Visible surface owned by the quick-panel controller.
enum QuickPanelMode { fullLibrary, quick }

/// Operation currently being completed.
enum QuickPanelPendingAction { copy, dismiss, replaceHotKey, showFullLibrary }

/// Immutable quick-panel state; library entries are intentionally absent.
final class QuickPanelState {
  /// Creates a complete quick-panel state value.
  const QuickPanelState({
    required this.mode,
    required this.configuredHotKey,
    required this.registration,
    this.pendingAction,
    this.copied = false,
    this.copyFailed = false,
    this.requestGeneration = 0,
    this.latestNativeFailure,
  });

  static const Object _unset = Object();

  /// Current full-library or compact presentation.
  final QuickPanelMode mode;

  /// Last successfully configured shortcut.
  final HotKeySpec configuredHotKey;

  /// Latest shortcut-registration result.
  final MacQuickPanelResult registration;

  /// Operation that currently excludes duplicate actions.
  final QuickPanelPendingAction? pendingAction;

  /// Whether exact clipboard copy is showing confirmation.
  final bool copied;

  /// Whether the last clipboard write failed without hiding quick mode.
  final bool copyFailed;

  /// Latest native presentation generation applied to Flutter state.
  final int requestGeneration;

  /// Latest non-fatal native capability failure.
  final MacQuickPanelResult? latestNativeFailure;

  /// Copies state while permitting nullable fields to be cleared explicitly.
  QuickPanelState copyWith({
    QuickPanelMode? mode,
    HotKeySpec? configuredHotKey,
    MacQuickPanelResult? registration,
    Object? pendingAction = _unset,
    bool? copied,
    bool? copyFailed,
    int? requestGeneration,
    Object? latestNativeFailure = _unset,
  }) {
    return QuickPanelState(
      mode: mode ?? this.mode,
      configuredHotKey: configuredHotKey ?? this.configuredHotKey,
      registration: registration ?? this.registration,
      pendingAction: identical(pendingAction, _unset)
          ? this.pendingAction
          : pendingAction as QuickPanelPendingAction?,
      copied: copied ?? this.copied,
      copyFailed: copyFailed ?? this.copyFailed,
      requestGeneration: requestGeneration ?? this.requestGeneration,
      latestNativeFailure: identical(latestNativeFailure, _unset)
          ? this.latestNativeFailure
          : latestNativeFailure as MacQuickPanelResult?,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is QuickPanelState &&
        mode == other.mode &&
        configuredHotKey == other.configuredHotKey &&
        registration == other.registration &&
        pendingAction == other.pendingAction &&
        copied == other.copied &&
        copyFailed == other.copyFailed &&
        requestGeneration == other.requestGeneration &&
        latestNativeFailure == other.latestNativeFailure;
  }

  @override
  int get hashCode {
    return Object.hash(
      mode,
      configuredHotKey,
      registration,
      pendingAction,
      copied,
      copyFailed,
      requestGeneration,
      latestNativeFailure,
    );
  }
}

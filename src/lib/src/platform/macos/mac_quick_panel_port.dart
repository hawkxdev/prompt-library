/// Modifier keys supported by the macOS quick-panel shortcut.
enum HotKeyModifier { command, shift, option, control }

/// Stable outcomes returned by the native quick-panel capability.
enum MacQuickPanelResultKind {
  registered,
  collision,
  invalidShortcut,
  unavailable,
  nativeFailure,
}

/// Immutable keyboard shortcut specification sent to the host.
class HotKeySpec {
  factory HotKeySpec({
    required int keyCode,
    required Set<HotKeyModifier> modifiers,
  }) {
    if (modifiers.isEmpty) {
      throw ArgumentError('At least one modifier is required');
    }
    return HotKeySpec._(
      keyCode: keyCode,
      modifiers: Set.unmodifiable(modifiers),
    );
  }

  const HotKeySpec._({required this.keyCode, required this.modifiers});
  final int keyCode;
  final Set<HotKeyModifier> modifiers;

  /// Encodes this shortcut using the native wire format.
  Map<String, Object> toMap() => {
    'keyCode': keyCode,
    'modifiers': (modifiers.toList()..sort((a, b) => a.name.compareTo(b.name)))
        .map((modifier) => modifier.name)
        .toList(),
  };

  @override
  bool operator ==(Object other) =>
      other is HotKeySpec &&
      keyCode == other.keyCode &&
      _setEquals(modifiers, other.modifiers);

  @override
  int get hashCode => Object.hash(
    keyCode,
    Object.hashAll((modifiers.map((m) => m.index).toList()..sort())),
  );
}

/// Result of a native quick-panel operation, optionally carrying diagnostics.
class MacQuickPanelResult {
  const MacQuickPanelResult(this.kind, {this.diagnosticCode});
  final MacQuickPanelResultKind kind;
  final int? diagnosticCode;

  /// Encodes this result using the native wire format.
  Map<String, Object?> toMap() => {
    'kind': kind.name,
    if (diagnosticCode != null) 'diagnosticCode': diagnosticCode,
  };

  /// Decodes and validates a native result payload.
  factory MacQuickPanelResult.fromMap(Object? value) {
    if (value is! Map) {
      throw const FormatException('Result must be a map');
    }
    final rawKind = value['kind'];
    final matches = MacQuickPanelResultKind.values.where(
      (item) => item.name == rawKind,
    );
    if (matches.length != 1) {
      throw const FormatException('Unknown result kind');
    }
    final code = value['diagnosticCode'];
    if (code != null && code is! int) {
      throw const FormatException('Diagnostic code must be an integer');
    }
    return MacQuickPanelResult(matches.single, diagnosticCode: code as int?);
  }

  @override
  bool operator ==(Object other) =>
      other is MacQuickPanelResult &&
      kind == other.kind &&
      diagnosticCode == other.diagnosticCode;
  @override
  int get hashCode => Object.hash(kind, diagnosticCode);
}

/// Typed capability boundary for macOS quick-panel operations.
abstract interface class MacQuickPanelPort {
  /// Native requests to enter quick mode.
  Stream<int> get quickModeRequests;

  /// Native requests to restore the full-library surface.
  Stream<int> get fullLibraryRequests;

  /// Registers a global shortcut.
  Future<MacQuickPanelResult> registerHotKey(HotKeySpec spec);

  /// Reads current registration state.
  Future<MacQuickPanelResult> registrationState();

  /// Releases the active native hotkey registration.
  Future<MacQuickPanelResult> unregisterHotKey();

  /// Hides quick mode and optionally restores focus.
  Future<MacQuickPanelResult> hideQuickMode({
    required bool restoreFocus,
    required int generation,
  });

  /// Shows the full library window.
  Future<MacQuickPanelResult> showFullLibrary();

  /// Releases all capability resources.
  Future<void> dispose();
}

/// Compares sets independently of iteration order.
bool _setEquals<T>(Set<T> left, Set<T> right) =>
    left.length == right.length && left.containsAll(right);

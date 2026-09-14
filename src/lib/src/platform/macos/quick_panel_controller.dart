import 'dart:async';

import '../../library/models/entry.dart';
import '../../library/presentation/library_clipboard.dart';
import '../../library/presentation/library_controller.dart';
import 'mac_quick_panel_port.dart';
import 'quick_panel_delay.dart';
import 'quick_panel_state.dart';

/// Coordinates deterministic quick-mode transitions above the native port.
final class QuickPanelController {
  /// Creates quick-mode orchestration with explicit external boundaries.
  QuickPanelController({
    required LibraryController libraryController,
    required this._clipboard,
    required this._port,
    QuickPanelDelay? delay,
  }) : _library = libraryController,
       _delay = delay ?? TimerQuickPanelDelay(),
       _state = QuickPanelState(
         mode: QuickPanelMode.fullLibrary,
         configuredHotKey: HotKeySpec(
           keyCode: 49,
           modifiers: {HotKeyModifier.control, HotKeyModifier.option},
         ),
         registration: const MacQuickPanelResult(
           MacQuickPanelResultKind.unavailable,
         ),
       ),
       _states = StreamController<QuickPanelState>.broadcast();

  final LibraryController _library;
  final LibraryClipboard _clipboard;
  final MacQuickPanelPort _port;
  final QuickPanelDelay _delay;
  final StreamController<QuickPanelState> _states;

  StreamSubscription<void>? _requests;
  StreamSubscription<void>? _fullRequests;
  QuickPanelState _state;
  Future<void>? _disposeFuture;
  Future<void>? _copyOperation;
  bool _disposed = false;
  int _currentGeneration = 0;
  int? _queuedQuickGeneration;

  /// Returns current quick-panel state synchronously.
  QuickPanelState get state => _state;

  /// Publishes non-replay quick-panel state transitions.
  Stream<QuickPanelState> get states => _states.stream;

  /// Whether lifecycle teardown has started.
  bool get isDisposed => _disposed;

  /// Registers the default shortcut and starts listening for host requests.
  Future<void> initialize(HotKeySpec defaultSpec) async {
    if (_disposed || _requests != null) {
      return;
    }
    _requests = _port.quickModeRequests.listen(_enterQuick);
    _fullRequests = _port.fullLibraryRequests.listen(_enterFullFromHost);
    late final MacQuickPanelResult registration;
    try {
      registration = await _port.registerHotKey(defaultSpec);
    } catch (_) {
      await _requests?.cancel();
      await _fullRequests?.cancel();
      _requests = null;
      _fullRequests = null;
      rethrow;
    }
    if (_disposed) {
      return;
    }
    final registered = registration.kind == MacQuickPanelResultKind.registered;
    _state = _state.copyWith(
      configuredHotKey: registered ? defaultSpec : _state.configuredHotKey,
      registration: registration,
      latestNativeFailure: registered
          ? _state.latestNativeFailure
          : registration,
    );
    _emit();
  }

  /// Replaces the shortcut only after native registration succeeds.
  Future<void> replaceHotKey(HotKeySpec spec) async {
    if (_disposed || _state.pendingAction != null) {
      return;
    }
    _state = _state.copyWith(
      pendingAction: QuickPanelPendingAction.replaceHotKey,
    );
    _emit();
    late final MacQuickPanelResult result;
    try {
      result = await _port.registerHotKey(spec);
    } catch (_) {
      _clearPendingAction(QuickPanelPendingAction.replaceHotKey);
      rethrow;
    }
    if (_disposed ||
        _state.pendingAction != QuickPanelPendingAction.replaceHotKey) {
      return;
    }
    final registered = result.kind == MacQuickPanelResultKind.registered;
    _state = _state.copyWith(
      configuredHotKey: registered ? spec : _state.configuredHotKey,
      registration: result,
      pendingAction: null,
      latestNativeFailure: registered ? _state.latestNativeFailure : result,
    );
    _emit();
    _consumeQueuedQuickRequest();
  }

  /// Copies the selected visible entry at most once concurrently.
  Future<void> copySelected() {
    final active = _copyOperation;
    if (active != null) {
      return active;
    }
    if (_disposed || _state.pendingAction != null) {
      return Future<void>.value();
    }
    final entry = _selectedEntry();
    if (entry == null) {
      return Future<void>.value();
    }
    final operation = _copy(entry);
    _copyOperation = operation;
    return operation.whenComplete(() {
      _copyOperation = null;
    });
  }

  Entry? _selectedEntry() {
    final selectedId = _library.state.selectedEntryId;
    for (final entry in _library.state.visibleEntries) {
      if (entry.id == selectedId) {
        return entry;
      }
    }
    return null;
  }

  Future<void> _copy(Entry entry) async {
    _state = _state.copyWith(
      pendingAction: QuickPanelPendingAction.copy,
      copied: false,
      copyFailed: false,
    );
    _emit();
    LibraryCopyOutcome outcome;
    try {
      outcome = await copyLibraryEntry(
        entry: entry,
        clipboard: _clipboard,
        controller: _library,
      );
    } catch (_) {
      _clearPendingCopy();
      rethrow;
    }
    if (_disposed) {
      return;
    }
    if (outcome == LibraryCopyOutcome.notAdmitted) {
      _clearPendingCopy();
      return;
    }
    if (outcome == LibraryCopyOutcome.clipboardFailure) {
      _clearPendingCopy(copyFailed: true);
      return;
    }
    if (_state.pendingAction != QuickPanelPendingAction.copy) {
      return;
    }
    _state = _state.copyWith(copied: true);
    _emit();
    await _delay.wait();
    if (_disposed || _state.pendingAction != QuickPanelPendingAction.copy) {
      return;
    }
    if (_queuedQuickGeneration != null) {
      _clearPendingAction(QuickPanelPendingAction.copy, copied: false);
      return;
    }
    _state = _state.copyWith(copied: false);
    _emit();
    late final MacQuickPanelResult result;
    try {
      result = await _port.hideQuickMode(
        restoreFocus: true,
        generation: _currentGeneration,
      );
    } catch (_) {
      _clearPendingAction(QuickPanelPendingAction.copy, copied: false);
      rethrow;
    }
    if (_disposed || _state.pendingAction != QuickPanelPendingAction.copy) {
      return;
    }
    _state = _state.copyWith(
      mode: QuickPanelMode.fullLibrary,
      pendingAction: null,
      copied: false,
      copyFailed: false,
      latestNativeFailure: _failureFrom(result),
    );
    _emit();
    _consumeQueuedQuickRequest();
  }

  void _clearPendingCopy({bool copyFailed = false}) {
    _clearPendingAction(
      QuickPanelPendingAction.copy,
      copied: false,
      copyFailed: copyFailed,
    );
  }

  void _clearPendingAction(
    QuickPanelPendingAction action, {
    bool? copied,
    bool? copyFailed,
  }) {
    if (_disposed || _state.pendingAction != action) {
      return;
    }
    _state = _state.copyWith(
      pendingAction: null,
      copied: copied,
      copyFailed: copyFailed,
    );
    _emit();
    _consumeQueuedQuickRequest();
  }

  /// Dismisses quick mode without touching clipboard or copy metadata.
  Future<void> dismiss() async {
    if (_disposed || _state.pendingAction != null) {
      return;
    }
    _state = _state.copyWith(pendingAction: QuickPanelPendingAction.dismiss);
    _emit();
    late final MacQuickPanelResult result;
    try {
      result = await _port.hideQuickMode(
        restoreFocus: true,
        generation: _currentGeneration,
      );
    } catch (_) {
      _clearPendingAction(QuickPanelPendingAction.dismiss);
      rethrow;
    }
    if (_disposed || _state.pendingAction != QuickPanelPendingAction.dismiss) {
      return;
    }
    _state = _state.copyWith(
      mode: QuickPanelMode.fullLibrary,
      pendingAction: null,
      copied: false,
      copyFailed: false,
      latestNativeFailure: _failureFrom(result),
    );
    _emit();
    _consumeQueuedQuickRequest();
  }

  /// Restores the ordinary full-library presentation.
  Future<void> showFullLibrary() async {
    if (_disposed || _state.pendingAction != null) {
      return;
    }
    _state = _state.copyWith(
      pendingAction: QuickPanelPendingAction.showFullLibrary,
    );
    _emit();
    late final MacQuickPanelResult result;
    try {
      result = await _port.showFullLibrary();
    } catch (_) {
      _clearPendingAction(QuickPanelPendingAction.showFullLibrary);
      rethrow;
    }
    if (_disposed ||
        _state.pendingAction != QuickPanelPendingAction.showFullLibrary) {
      return;
    }
    _state = _state.copyWith(
      mode: QuickPanelMode.fullLibrary,
      pendingAction: null,
      copied: false,
      copyFailed: false,
      latestNativeFailure: _failureFrom(result),
    );
    _emit();
    _consumeQueuedQuickRequest();
  }

  MacQuickPanelResult? _failureFrom(MacQuickPanelResult result) {
    return result.kind == MacQuickPanelResultKind.registered
        ? _state.latestNativeFailure
        : result;
  }

  void _enterQuick(int generation) {
    if (_disposed || generation < _currentGeneration) {
      return;
    }
    if (_state.pendingAction != null) {
      _queuedQuickGeneration = generation;
      return;
    }
    _applyQuickRequest(generation);
  }

  void _consumeQueuedQuickRequest() {
    final generation = _queuedQuickGeneration;
    if (generation == null || _disposed || _state.pendingAction != null) {
      return;
    }
    _queuedQuickGeneration = null;
    _applyQuickRequest(generation);
  }

  void _applyQuickRequest(int generation) {
    if (_library.state.isUnderMaintenance) {
      _currentGeneration = generation;
      unawaited(_rejectQuickRequest());
      return;
    }
    _currentGeneration = generation;
    _library.updateSearchQuery('');
    final entries = _library.state.visibleEntries;
    _library.selectEntry(entries.isEmpty ? null : entries.first.id);
    _state = _state.copyWith(
      mode: QuickPanelMode.quick,
      copied: false,
      copyFailed: false,
      requestGeneration: generation,
    );
    _emit();
  }

  /// Returns the window to the full library when maintenance refuses the
  /// quick transition.
  ///
  /// A port answer can outlive the refusal it belongs to; when a newer quick
  /// or full request was accepted during the wait, the stale completion is a
  /// no-op. Unexpected port errors do not disappear silently: after teardown
  /// they are ignored, otherwise they are handed to the enclosing zone.
  Future<void> _rejectQuickRequest() async {
    final generation = _currentGeneration;
    late final MacQuickPanelResult result;
    try {
      result = await _port.showFullLibrary();
    } on Object catch (error, stackTrace) {
      if (_disposed) {
        return;
      }
      Zone.current.handleUncaughtError(error, stackTrace);
      return;
    }
    if (_disposed || generation != _currentGeneration) {
      return;
    }
    _state = _state.copyWith(
      mode: QuickPanelMode.fullLibrary,
      copied: false,
      copyFailed: false,
      latestNativeFailure: _failureFrom(result),
    );
    _emit();
  }

  void _enterFullFromHost(int generation) {
    if (_disposed || generation < _currentGeneration) {
      return;
    }
    _currentGeneration = generation;
    _queuedQuickGeneration = null;
    if (_state.pendingAction == QuickPanelPendingAction.copy) {
      _delay.cancel();
    }
    final pending =
        _state.pendingAction == QuickPanelPendingAction.replaceHotKey
        ? QuickPanelPendingAction.replaceHotKey
        : null;
    _state = _state.copyWith(
      mode: QuickPanelMode.fullLibrary,
      pendingAction: pending,
      copied: false,
      copyFailed: false,
      requestGeneration: generation,
    );
    _emit();
  }

  void _emit() {
    if (!_states.isClosed) {
      _states.add(_state);
    }
  }

  /// Releases request, delay, native port, and state-stream ownership once.
  Future<void> dispose() {
    return _disposeFuture ??= _dispose();
  }

  Future<void> _dispose() async {
    _disposed = true;
    await _requests?.cancel();
    await _fullRequests?.cancel();
    _requests = null;
    _fullRequests = null;
    _queuedQuickGeneration = null;
    _delay.cancel();
    await _port.dispose();
    await _states.close();
  }
}

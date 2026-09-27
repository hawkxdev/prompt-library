import 'dart:async';

import 'package:prompt_library/src/library/models/entry.dart';
import 'package:prompt_library/src/library/models/library_snapshot.dart';
import 'package:prompt_library/src/library/presentation/library_clipboard.dart';
import 'package:prompt_library/src/library/presentation/library_controller.dart';
import 'package:prompt_library/src/library/presentation/transfer/library_transfer_controller.dart';
import 'package:prompt_library/src/platform/macos/mac_quick_panel_port.dart';
import 'package:prompt_library/src/platform/macos/quick_panel_controller.dart';
import 'package:prompt_library/src/platform/macos/quick_panel_delay.dart';

import '../../support/library_test_support.dart';

/// Owns deterministic quick-widget dependencies for one test.
final class QuickPanelWidgetHarness {
  QuickPanelWidgetHarness()
    : repository = TestLibraryRepository(),
      clipboard = RecordingQuickClipboard(),
      port = WidgetFakeQuickPanelPort(),
      delay = WidgetControlledQuickPanelDelay() {
    library = LibraryController(repository: repository);
    quick = QuickPanelController(
      libraryController: library,
      clipboard: clipboard,
      port: port,
      delay: delay,
    );
    transfer = testTransferController(repository, library);
  }

  /// Product default shortcut.
  static HotKeySpec get defaultSpec => HotKeySpec(
    keyCode: 49,
    modifiers: {HotKeyModifier.control, HotKeyModifier.option},
  );

  final TestLibraryRepository repository;
  final RecordingQuickClipboard clipboard;
  final WidgetFakeQuickPanelPort port;
  final WidgetControlledQuickPanelDelay delay;
  late final LibraryController library;
  late final QuickPanelController quick;
  late final LibraryTransferController transfer;

  /// Seeds entries, initializes quick access, and emits one host request.
  Future<void> enterQuick(Iterable<Entry> entries) async {
    repository.emit(LibrarySnapshot(entries: entries));
    await quick.initialize(defaultSpec);
    port.emitQuickModeRequest();
  }

  /// Releases every owned resource.
  Future<void> dispose() async {
    await quick.dispose();
    await transfer.dispose();
    await library.dispose();
    await repository.close();
    await port.close();
  }
}

/// Records exact clipboard writes and optional failure/gating.
final class RecordingQuickClipboard implements LibraryClipboard {
  final List<String> values = [];
  Completer<void>? gate;
  Object? nextError;

  @override
  Future<void> writeText(String text) async {
    values.add(text);
    final error = nextError;
    nextError = null;
    if (error != null) {
      Error.throwWithStackTrace(error, StackTrace.current);
    }
    await gate?.future;
  }
}

/// Controls completion of the copied confirmation interval.
final class WidgetControlledQuickPanelDelay implements QuickPanelDelay {
  Completer<void>? _gate;
  int waitCalls = 0;
  int cancelCalls = 0;

  @override
  Future<void> wait() {
    waitCalls++;
    _gate = Completer<void>();
    return _gate!.future;
  }

  /// Completes the active confirmation interval.
  void complete() {
    final gate = _gate;
    if (gate != null && !gate.isCompleted) {
      gate.complete();
    }
  }

  @override
  void cancel() {
    cancelCalls++;
    complete();
  }
}

/// Controllable native quick-panel port for widget tests.
final class WidgetFakeQuickPanelPort implements MacQuickPanelPort {
  final StreamController<int> _requests = StreamController<int>.broadcast(
    sync: true,
  );
  final StreamController<int> _fullRequests = StreamController<int>.broadcast(
    sync: true,
  );
  final List<HotKeySpec> registeredSpecs = [];
  final List<bool> hideCalls = [];
  final List<MacQuickPanelResult> registrationResults = [];
  MacQuickPanelResult hideResult = const MacQuickPanelResult(
    MacQuickPanelResultKind.registered,
  );
  MacQuickPanelResult showResult = const MacQuickPanelResult(
    MacQuickPanelResultKind.registered,
  );
  Completer<void>? registrationGate;
  int disposeCalls = 0;
  int _nextGeneration = 1;

  @override
  Stream<int> get quickModeRequests => _requests.stream;

  @override
  Stream<int> get fullLibraryRequests => _fullRequests.stream;

  @override
  Future<MacQuickPanelResult> registerHotKey(HotKeySpec spec) async {
    registeredSpecs.add(spec);
    await registrationGate?.future;
    if (registrationResults.isNotEmpty) {
      return registrationResults.removeAt(0);
    }
    return const MacQuickPanelResult(MacQuickPanelResultKind.registered);
  }

  @override
  Future<MacQuickPanelResult> registrationState() async {
    return const MacQuickPanelResult(MacQuickPanelResultKind.registered);
  }

  @override
  Future<MacQuickPanelResult> unregisterHotKey() async {
    return const MacQuickPanelResult(MacQuickPanelResultKind.registered);
  }

  @override
  Future<MacQuickPanelResult> hideQuickMode({
    required bool restoreFocus,
    required int generation,
  }) async {
    hideCalls.add(restoreFocus);
    return hideResult;
  }

  @override
  Future<MacQuickPanelResult> showFullLibrary() async => showResult;

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }

  /// Emits one native hotkey request.
  void emitQuickModeRequest({int? generation}) {
    if (!_requests.isClosed) {
      _requests.add(generation ?? _nextGeneration++);
    }
  }

  /// Emits one native full-library request.
  void emitFullLibraryRequest({int? generation}) {
    if (!_fullRequests.isClosed) {
      _fullRequests.add(generation ?? _nextGeneration++);
    }
  }

  Future<void> close() async {
    await _requests.close();
    await _fullRequests.close();
  }
}

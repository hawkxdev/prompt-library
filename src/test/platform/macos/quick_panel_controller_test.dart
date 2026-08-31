import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/library/models/library_failure.dart';
import 'package:prompt_library/src/library/models/library_snapshot.dart';
import 'package:prompt_library/src/library/presentation/library_clipboard.dart';
import 'package:prompt_library/src/library/presentation/library_controller.dart';
import 'package:prompt_library/src/platform/macos/mac_quick_panel_port.dart';
import 'package:prompt_library/src/platform/macos/quick_panel_controller.dart';
import 'package:prompt_library/src/platform/macos/quick_panel_delay.dart';
import 'package:prompt_library/src/platform/macos/quick_panel_state.dart';

import '../../support/library_test_support.dart';

void main() {
  late TestLibraryRepository repository;
  late LibraryController library;
  late _RecordingClipboard clipboard;
  late _FakePort port;
  late _ControlledDelay delay;
  late QuickPanelController controller;

  final defaultSpec = HotKeySpec(
    keyCode: 49,
    modifiers: {HotKeyModifier.control, HotKeyModifier.option},
  );
  final replacementSpec = HotKeySpec(
    keyCode: 35,
    modifiers: {HotKeyModifier.command, HotKeyModifier.shift},
  );

  setUp(() {
    repository = TestLibraryRepository();
    library = LibraryController(repository: repository);
    clipboard = _RecordingClipboard();
    port = _FakePort();
    delay = _ControlledDelay();
    controller = QuickPanelController(
      libraryController: library,
      clipboard: clipboard,
      port: port,
      delay: delay,
    );
  });

  tearDown(() async {
    await controller.dispose();
    await library.dispose();
    await repository.close();
    await port.close();
  });

  test('starts with the valid product default shortcut', () {
    expect(controller.state.configuredHotKey, defaultSpec);
    expect(controller.state.mode, QuickPanelMode.fullLibrary);
    expect(
      controller.state.registration.kind,
      MacQuickPanelResultKind.unavailable,
    );
  });

  test('subscribes before registration and initializes only once', () async {
    repository.emit(LibrarySnapshot(entries: [testEntry('entry-1')]));
    port.emitRequestDuringRegistration = true;

    await controller.initialize(defaultSpec);
    await controller.initialize(replacementSpec);

    expect(port.registeredSpecs, [defaultSpec]);
    expect(port.quickModeListenCount, 1);
    expect(controller.state.configuredHotKey, defaultSpec);
    expect(controller.state.mode, QuickPanelMode.quick);
    expect(library.state.selectedEntryId, 'entry-1');
  });

  test('retains configured shortcut when initial registration fails', () async {
    port.registrationResults.add(
      const MacQuickPanelResult(
        MacQuickPanelResultKind.collision,
        diagnosticCode: -9878,
      ),
    );

    await controller.initialize(replacementSpec);

    expect(controller.state.configuredHotKey, defaultSpec);
    expect(
      controller.state.registration.kind,
      MacQuickPanelResultKind.collision,
    );
  });

  test(
    'registration completion preserves an action started by a host request',
    () async {
      repository.emit(LibrarySnapshot(entries: [testEntry('entry-1')]));
      port.registrationGate = Completer<void>();
      port.hideGate = Completer<void>();

      final initialization = controller.initialize(defaultSpec);
      port.emitQuickModeRequest();
      final dismissal = controller.dismiss();
      await _flush();

      expect(controller.state.pendingAction, QuickPanelPendingAction.dismiss);
      expect(port.hideCalls, [true]);

      port.registrationGate!.complete();
      await initialization;
      final duplicateDismissal = controller.dismiss();
      await _flush();

      expect(controller.state.pendingAction, QuickPanelPendingAction.dismiss);
      expect(port.hideCalls, [true]);

      port.hideGate!.complete();
      await Future.wait([dismissal, duplicateDismissal]);
      expect(controller.state.mode, QuickPanelMode.fullLibrary);
      expect(controller.state.pendingAction, isNull);
    },
  );

  test('quick request clears query and selects first visible entry', () async {
    repository.emit(
      LibrarySnapshot(
        entries: [
          testEntry('entry-1', title: 'Alpha'),
          testEntry('entry-2', title: 'Beta'),
        ],
      ),
    );
    library.updateSearchQuery('Beta');
    await controller.initialize(defaultSpec);
    final publishedLibraryStates = <String>[];
    final subscription = controller.states.listen((state) {
      if (state.mode == QuickPanelMode.quick) {
        publishedLibraryStates.add(
          '${library.state.filter.searchQuery}:${library.state.selectedEntryId}',
        );
      }
    });

    port.emitQuickModeRequest();
    await _flush();

    expect(library.state.filter.searchQuery, isEmpty);
    expect(library.state.selectedEntryId, 'entry-1');
    expect(controller.state.mode, QuickPanelMode.quick);
    expect(controller.state.copied, isFalse);
    expect(publishedLibraryStates, [':entry-1']);
    await subscription.cancel();
  });

  test('quick request handles empty results and repeated requests', () async {
    repository.emit(const LibrarySnapshot.empty());
    await controller.initialize(defaultSpec);

    port.emitQuickModeRequest();
    port.emitQuickModeRequest();

    expect(library.state.selectedEntryId, isNull);
    expect(controller.state.mode, QuickPanelMode.quick);
  });

  test('copies exact body before metadata and hides after delay', () async {
    const body = '  first line\n\nlast line  ';
    repository.emit(
      LibrarySnapshot(entries: [testEntry('entry-1', body: body)]),
    );
    await controller.initialize(defaultSpec);
    port.emitQuickModeRequest();
    clipboard.gate = Completer<void>();

    final copy = controller.copySelected();
    await _flush();

    expect(clipboard.values, [body]);
    expect(repository.calls, isEmpty);
    expect(port.hideCalls, isEmpty);

    clipboard.gate!.complete();
    await _flush();

    expect(repository.calls, ['markCopied:entry-1']);
    expect(controller.state.copied, isTrue);
    expect(delay.waitCalls, 1);
    expect(port.hideCalls, isEmpty);

    delay.complete();
    await copy;

    expect(port.hideCalls, [true]);
    expect(controller.state.mode, QuickPanelMode.fullLibrary);
    expect(controller.state.copied, isFalse);
  });

  test('ends copied confirmation before awaiting native hide', () async {
    repository.emit(LibrarySnapshot(entries: [testEntry('entry-1')]));
    await controller.initialize(defaultSpec);
    port.emitQuickModeRequest();
    port.hideGate = Completer<void>();

    final copy = controller.copySelected();
    await _flush();
    expect(controller.state.copied, isTrue);

    delay.complete();
    await _flush();

    expect(port.hideCalls, [true]);
    expect(controller.state.copied, isFalse);
    expect(controller.state.pendingAction, QuickPanelPendingAction.copy);

    port.hideGate!.complete();
    await copy;
    expect(controller.state.pendingAction, isNull);
  });

  test('show full does not supersede an active copy', () async {
    repository.emit(LibrarySnapshot(entries: [testEntry('entry-1')]));
    await controller.initialize(defaultSpec);
    port.emitQuickModeRequest();

    final copy = controller.copySelected();
    await _flush();
    await controller.showFullLibrary();

    expect(port.showCalls, 0);
    expect(controller.state.mode, QuickPanelMode.quick);
    expect(controller.state.pendingAction, QuickPanelPendingAction.copy);

    delay.complete();
    await copy;
  });

  test(
    'clipboard failure leaves quick mode visible and unexpected errors escape',
    () async {
      repository.emit(LibrarySnapshot(entries: [testEntry('entry-1')]));
      await controller.initialize(defaultSpec);
      port.emitQuickModeRequest();
      clipboard.nextError = const LibraryClipboardFailure();

      await controller.copySelected();

      expect(repository.calls, isEmpty);
      expect(port.hideCalls, isEmpty);
      expect(controller.state.mode, QuickPanelMode.quick);

      clipboard.nextError = StateError('unexpected');
      await expectLater(controller.copySelected(), throwsStateError);
      expect(port.hideCalls, isEmpty);
    },
  );

  test(
    'metadata failure is retained while successful copy still hides',
    () async {
      repository.emit(LibrarySnapshot(entries: [testEntry('entry-1')]));
      await controller.initialize(defaultSpec);
      port.emitQuickModeRequest();
      repository.nextFailure = const LibraryFailure.databaseFailure(
        code: LibraryDatabaseFailureCode.transactionFailed,
      );

      final copy = controller.copySelected();
      await _flush();

      expect(library.state.failure, isA<DatabaseFailureLibraryFailure>());
      expect(controller.state.copied, isTrue);
      delay.complete();
      await copy;

      expect(port.hideCalls, [true]);
      expect(controller.state.mode, QuickPanelMode.fullLibrary);
    },
  );

  test('retains native hide failure after successful copy', () async {
    repository.emit(LibrarySnapshot(entries: [testEntry('entry-1')]));
    await controller.initialize(defaultSpec);
    port.emitQuickModeRequest();
    port.hideResult = const MacQuickPanelResult(
      MacQuickPanelResultKind.nativeFailure,
      diagnosticCode: -50,
    );

    final copy = controller.copySelected();
    await _flush();
    delay.complete();
    await copy;

    expect(
      controller.state.latestNativeFailure,
      const MacQuickPanelResult(
        MacQuickPanelResultKind.nativeFailure,
        diagnosticCode: -50,
      ),
    );
  });

  test('deduplicates copy and dismiss operations', () async {
    repository.emit(LibrarySnapshot(entries: [testEntry('entry-1')]));
    await controller.initialize(defaultSpec);
    port.emitQuickModeRequest();
    clipboard.gate = Completer<void>();

    final firstCopy = controller.copySelected();
    final secondCopy = controller.copySelected();
    await _flush();

    expect(clipboard.values, hasLength(1));
    clipboard.gate!.complete();
    await _flush();
    delay.complete();
    await Future.wait([firstCopy, secondCopy]);
    expect(repository.calls, ['markCopied:entry-1']);

    port.hideGate = Completer<void>();
    port.emitQuickModeRequest();
    final firstDismiss = controller.dismiss();
    final secondDismiss = controller.dismiss();
    await _flush();
    expect(port.hideCalls, [true, true]);
    port.hideGate!.complete();
    await Future.wait([firstDismiss, secondDismiss]);
    expect(controller.state.mode, QuickPanelMode.fullLibrary);
    expect(controller.state.pendingAction, isNull);
    expect(controller.state.latestNativeFailure, isNull);
  });

  test(
    'retains shortcut for every non-registered replacement result',
    () async {
      await controller.initialize(defaultSpec);
      const failedKinds = [
        MacQuickPanelResultKind.collision,
        MacQuickPanelResultKind.invalidShortcut,
        MacQuickPanelResultKind.unavailable,
        MacQuickPanelResultKind.nativeFailure,
      ];

      for (final kind in failedKinds) {
        port.registrationResults.add(
          MacQuickPanelResult(kind, diagnosticCode: -1),
        );
        await controller.replaceHotKey(replacementSpec);
        expect(controller.state.configuredHotKey, defaultSpec);
        expect(controller.state.registration.kind, kind);
      }

      port.registrationResults.add(
        const MacQuickPanelResult(MacQuickPanelResultKind.registered),
      );
      await controller.replaceHotKey(replacementSpec);
      expect(controller.state.configuredHotKey, replacementSpec);
      expect(
        controller.state.registration.kind,
        MacQuickPanelResultKind.registered,
      );
    },
  );

  test('show full retains native failure', () async {
    await controller.initialize(defaultSpec);
    port.emitQuickModeRequest();
    port.showResult = const MacQuickPanelResult(
      MacQuickPanelResultKind.nativeFailure,
      diagnosticCode: -1,
    );

    await controller.showFullLibrary();

    expect(port.showCalls, 1);
    expect(controller.state.mode, QuickPanelMode.fullLibrary);
    expect(controller.state.latestNativeFailure?.diagnosticCode, -1);
  });

  test('show full exclusively owns its native operation', () async {
    await controller.initialize(defaultSpec);
    port.emitQuickModeRequest();
    port.showGate = Completer<void>();

    final showing = controller.showFullLibrary();
    await _flush();
    expect(
      controller.state.pendingAction,
      QuickPanelPendingAction.showFullLibrary,
    );

    await controller.replaceHotKey(replacementSpec);
    expect(port.registeredSpecs, [defaultSpec]);
    expect(port.showCalls, 1);

    port.showGate!.complete();
    await showing;
    expect(controller.state.mode, QuickPanelMode.fullLibrary);
    expect(controller.state.pendingAction, isNull);
  });

  test('native exceptions release only the operation-owned guard', () async {
    await controller.initialize(defaultSpec);
    port.nextRegistrationError = const FormatException('register');

    await expectLater(
      controller.replaceHotKey(replacementSpec),
      throwsFormatException,
    );
    expect(controller.state.pendingAction, isNull);
    expect(controller.state.configuredHotKey, defaultSpec);

    port.emitQuickModeRequest();
    port.nextHideError = const FormatException('dismiss');
    await expectLater(controller.dismiss(), throwsFormatException);
    expect(controller.state.pendingAction, isNull);
    expect(controller.state.mode, QuickPanelMode.quick);

    repository.emit(LibrarySnapshot(entries: [testEntry('entry-1')]));
    port.emitQuickModeRequest();
    port.nextHideError = const FormatException('copy hide');
    final copy = controller.copySelected();
    await _flush();
    delay.complete();
    await expectLater(copy, throwsFormatException);
    expect(controller.state.pendingAction, isNull);
    expect(controller.state.copied, isFalse);
    expect(controller.state.mode, QuickPanelMode.quick);

    port.nextShowError = const FormatException('show');
    await expectLater(controller.showFullLibrary(), throwsFormatException);
    expect(controller.state.pendingAction, isNull);
    expect(controller.state.mode, QuickPanelMode.quick);
  });

  test('coalesces hotkey requests received during pending actions', () async {
    repository.emit(LibrarySnapshot(entries: [testEntry('entry-1')]));
    await controller.initialize(defaultSpec);
    port.emitQuickModeRequest();

    final copy = controller.copySelected();
    await _flush();
    port.emitQuickModeRequest();
    delay.complete();
    await copy;

    expect(port.hideCalls, isEmpty);
    expect(controller.state.mode, QuickPanelMode.quick);
    expect(controller.state.pendingAction, isNull);

    port.registrationGate = Completer<void>();
    final replacement = controller.replaceHotKey(replacementSpec);
    await _flush();
    port.emitQuickModeRequest();
    port.registrationGate!.complete();
    await replacement;

    expect(controller.state.mode, QuickPanelMode.quick);
    expect(controller.state.configuredHotKey, replacementSpec);
  });

  test(
    'native full-library request cancels pending copy without hiding',
    () async {
      repository.emit(LibrarySnapshot(entries: [testEntry('entry-1')]));
      await controller.initialize(defaultSpec);
      port.emitQuickModeRequest();

      final copy = controller.copySelected();
      await _flush();
      expect(controller.state.copied, isTrue);

      port.emitFullLibraryRequest();
      await copy;

      expect(controller.state.mode, QuickPanelMode.fullLibrary);
      expect(controller.state.pendingAction, isNull);
      expect(controller.state.copied, isFalse);
      expect(port.hideCalls, isEmpty);
    },
  );

  test('dispose cancels pending delay and all later work', () async {
    repository.emit(LibrarySnapshot(entries: [testEntry('entry-1')]));
    await controller.initialize(defaultSpec);
    port.emitQuickModeRequest();
    final done = Completer<void>();
    controller.states.listen(null, onDone: done.complete);

    final copy = controller.copySelected();
    await _flush();
    expect(controller.state.copied, isTrue);

    await controller.dispose();
    await controller.dispose();
    await copy;
    port.emitQuickModeRequest();
    await controller.replaceHotKey(replacementSpec);
    await controller.dismiss();
    await controller.showFullLibrary();

    expect(delay.cancelCalls, 1);
    expect(port.disposeCalls, 1);
    expect(port.quickModeCancelCount, 1);
    expect(port.hideCalls, isEmpty);
    expect(port.registeredSpecs, [defaultSpec]);
    expect(done.isCompleted, isTrue);
    expect(controller.state.mode, QuickPanelMode.quick);
  });
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

final class _ControlledDelay implements QuickPanelDelay {
  int waitCalls = 0;
  int cancelCalls = 0;
  Completer<void>? _gate;

  @override
  Future<void> wait() {
    waitCalls++;
    _gate = Completer<void>();
    return _gate!.future;
  }

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

final class _RecordingClipboard implements LibraryClipboard {
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

final class _FakePort implements MacQuickPanelPort {
  _FakePort() {
    _requests.onListen = () {
      quickModeListenCount++;
    };
    _requests.onCancel = () {
      quickModeCancelCount++;
    };
  }

  final StreamController<int> _requests = StreamController<int>.broadcast(
    sync: true,
  );
  final StreamController<int> _fullRequests = StreamController<int>.broadcast(
    sync: true,
  );
  final List<HotKeySpec> registeredSpecs = [];
  final List<MacQuickPanelResult> registrationResults = [];
  final List<bool> hideCalls = [];
  MacQuickPanelResult hideResult = const MacQuickPanelResult(
    MacQuickPanelResultKind.registered,
  );
  MacQuickPanelResult showResult = const MacQuickPanelResult(
    MacQuickPanelResultKind.registered,
  );
  Completer<void>? registrationGate;
  Completer<void>? hideGate;
  Completer<void>? showGate;
  Object? nextRegistrationError;
  Object? nextHideError;
  Object? nextShowError;
  bool emitRequestDuringRegistration = false;
  int quickModeListenCount = 0;
  int quickModeCancelCount = 0;
  int showCalls = 0;
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
    if (emitRequestDuringRegistration) {
      emitQuickModeRequest();
    }
    final registrationError = nextRegistrationError;
    nextRegistrationError = null;
    if (registrationError != null) {
      Error.throwWithStackTrace(registrationError, StackTrace.current);
    }
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
    await hideGate?.future;
    final hideError = nextHideError;
    nextHideError = null;
    if (hideError != null) {
      Error.throwWithStackTrace(hideError, StackTrace.current);
    }
    return hideResult;
  }

  @override
  Future<MacQuickPanelResult> showFullLibrary() async {
    showCalls++;
    await showGate?.future;
    final showError = nextShowError;
    nextShowError = null;
    if (showError != null) {
      Error.throwWithStackTrace(showError, StackTrace.current);
    }
    return showResult;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }

  void emitQuickModeRequest({int? generation}) {
    if (!_requests.isClosed) {
      _requests.add(generation ?? _nextGeneration++);
    }
  }

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

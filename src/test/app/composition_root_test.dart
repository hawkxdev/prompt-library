/// Composition root tests.
library;

import 'dart:ui' show AppExitResponse;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/app/application_surface.dart';
import 'package:prompt_library/src/app/composition_root.dart';
import 'package:prompt_library/src/app/prompt_library_app.dart';
import 'package:prompt_library/src/library/data/drift_library_repository.dart';
import 'package:prompt_library/src/library/data/library_database.dart';
import 'package:prompt_library/src/library/models/entry_input.dart';
import 'package:prompt_library/src/library/presentation/library_clipboard.dart';
import 'package:prompt_library/src/library/presentation/library_controller.dart';
import 'package:prompt_library/src/library/presentation/library_haptics.dart';
import 'package:prompt_library/src/library/presentation/library_share.dart';
import 'package:prompt_library/src/library/presentation/mobile/mobile_library_screen.dart';
import 'package:prompt_library/src/platform/macos/mac_quick_panel_port.dart';
import 'package:prompt_library/src/platform/macos/method_channel_mac_quick_panel.dart';
import 'package:prompt_library/src/platform/macos/unavailable_mac_quick_panel.dart';
import 'package:prompt_library/src/platform/macos/quick_panel_controller.dart';

void main() {
  test('selects mobile application surface for iOS', () {
    expect(selectApplicationSurface(isIOS: true), ApplicationSurface.mobile);
  });

  test('selects desktop application surface for non-iOS', () {
    expect(selectApplicationSurface(isIOS: false), ApplicationSurface.desktop);
  });

  test('wires real Drift and disposes controller before database', () async {
    final database = LibraryDatabase.forTesting(NativeDatabase.memory());
    final repository = DriftLibraryRepository(database);
    final controller = LibraryController(repository: repository);
    final composition = PromptLibraryComposition(
      applicationSurface: ApplicationSurface.desktop,
      database: database,
      repository: repository,
      controller: controller,
      clipboard: const _NoopClipboard(),
    );

    expect(composition.applicationSurface, ApplicationSurface.desktop);
    expect(composition.share, isA<UnavailableLibraryShare>());
    expect(composition.haptics, isA<FlutterLibraryHaptics>());

    await controller.createEntry(
      EntryInput.validate(title: 'Title', body: 'Body'),
    );
    await pumpEventQueue();
    expect(controller.state.snapshot?.entries.single.title, 'Title');

    final first = composition.dispose();
    final second = composition.dispose();
    expect(identical(first, second), isTrue);
    await first;

    expect(() => controller.updateSearchQuery('query'), throwsStateError);
    await expectLater(
      database.customSelect('SELECT 1').get(),
      throwsStateError,
    );
  });

  testWidgets('passes composition capabilities into the mobile app', (
    tester,
  ) async {
    final database = LibraryDatabase.forTesting(NativeDatabase.memory());
    final repository = DriftLibraryRepository(database);
    final controller = LibraryController(repository: repository);
    const share = _NoopShare();
    const haptics = _NoopHaptics();
    final composition = PromptLibraryComposition(
      applicationSurface: ApplicationSurface.mobile,
      database: database,
      repository: repository,
      controller: controller,
      clipboard: const _NoopClipboard(),
      share: share,
      haptics: haptics,
    );

    await tester.pumpWidget(
      PromptLibraryApp(
        applicationSurface: composition.applicationSurface,
        controller: composition.controller,
        clipboard: composition.clipboard,
        share: composition.share,
        haptics: composition.haptics,
      ),
    );

    final mobile = tester.widget<MobileLibraryScreen>(
      find.byType(MobileLibraryScreen),
    );
    expect(identical(mobile.share, share), isTrue);
    expect(identical(mobile.haptics, haptics), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    });
    await tester.runAsync(composition.dispose);
  });

  test(
    'starts default shortcut once and disposes quick access first',
    () async {
      final database = LibraryDatabase.forTesting(NativeDatabase.memory());
      final repository = DriftLibraryRepository(database);
      final controller = LibraryController(repository: repository);
      const clipboard = _NoopClipboard();
      final port = _RecordingQuickPort();
      final quick = QuickPanelController(
        libraryController: controller,
        clipboard: clipboard,
        port: port,
      );
      final composition = PromptLibraryComposition(
        applicationSurface: ApplicationSurface.desktop,
        database: database,
        repository: repository,
        controller: controller,
        clipboard: clipboard,
        quickPanelController: quick,
        quickAccessSupported: true,
      );

      expect(composition.applicationSurface, ApplicationSurface.desktop);

      await composition.start();
      await composition.start();

      expect(port.registered, hasLength(1));
      expect(port.registered.single.keyCode, 49);
      expect(port.registered.single.modifiers, {
        HotKeyModifier.control,
        HotKeyModifier.option,
      });

      var quickDisposedWhileDependenciesAlive = false;
      port.onDispose = () async {
        final rows = await database.customSelect('SELECT 1 AS value').get();
        quickDisposedWhileDependenciesAlive =
            controller.isDisposed == false && rows.single.data['value'] == 1;
      };

      await composition.dispose();
      await composition.dispose();

      expect(quickDisposedWhileDependenciesAlive, isTrue);
      expect(port.disposeCalls, 1);
      expect(controller.isDisposed, isTrue);
      await expectLater(
        database.customSelect('SELECT 1').get(),
        throwsStateError,
      );
    },
  );

  test('disposes quick, library, and database in exact order', () async {
    final order = <String>[];

    await PromptLibraryComposition.disposeResourcesInOrder(
      disposeQuickPanel: () async => order.add('quick'),
      disposeLibrary: () async => order.add('library'),
      closeDatabase: () async => order.add('database'),
    );

    expect(order, ['quick', 'library', 'database']);
  });

  test('selects concrete macOS and unavailable non-macOS ports', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final macOS = PromptLibraryComposition.createPlatformPort(
      isMacOS: true,
      messenger: messenger,
    );
    final unavailable = PromptLibraryComposition.createPlatformPort(
      isMacOS: false,
      messenger: messenger,
    );

    expect(macOS, isA<MethodChannelMacQuickPanel>());
    expect(unavailable, isA<UnavailableMacQuickPanel>());

    await macOS.dispose();
    await unavailable.dispose();
  });

  test('keeps iOS surface independent from macOS quick access', () async {
    final surface = selectApplicationSurface(isIOS: true);
    final port = PromptLibraryComposition.createPlatformPort(isMacOS: false);

    expect(surface, ApplicationSurface.mobile);
    expect(port, isA<UnavailableMacQuickPanel>());

    await port.dispose();
  });

  test('does not dispose while voting on an exit request', () async {
    var disposeCalls = 0;
    final lifecycle = PromptLibraryLifecycle(() async {
      disposeCalls++;
    });

    expect(await lifecycle.requestExit(), AppExitResponse.exit);
    expect(disposeCalls, 0);

    lifecycle.release();
    await pumpEventQueue();
    expect(disposeCalls, 1);
  });
}

final class _NoopClipboard implements LibraryClipboard {
  const _NoopClipboard();

  @override
  Future<void> writeText(String text) async {}
}

final class _NoopShare implements LibraryShare {
  const _NoopShare();

  @override
  Future<LibraryShareOutcome> shareText(String text, {Rect? anchor}) async {
    return LibraryShareOutcome.dismissed;
  }
}

final class _NoopHaptics implements LibraryHaptics {
  const _NoopHaptics();

  @override
  Future<void> selectionFeedback() async {}
}

final class _RecordingQuickPort implements MacQuickPanelPort {
  final List<HotKeySpec> registered = [];
  int disposeCalls = 0;
  Future<void> Function()? onDispose;

  @override
  Stream<int> get quickModeRequests => const Stream<int>.empty();

  @override
  Stream<int> get fullLibraryRequests => const Stream<int>.empty();

  @override
  Future<MacQuickPanelResult> registerHotKey(HotKeySpec spec) async {
    registered.add(spec);
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
    return const MacQuickPanelResult(MacQuickPanelResultKind.registered);
  }

  @override
  Future<MacQuickPanelResult> showFullLibrary() async {
    return const MacQuickPanelResult(MacQuickPanelResultKind.registered);
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    await onDispose?.call();
  }
}

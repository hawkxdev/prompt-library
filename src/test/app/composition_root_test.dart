/// Composition root tests.
library;

import 'dart:async';

import 'dart:convert' show utf8;

import 'dart:io';

import 'dart:ui' show AppExitResponse;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/app/application_surface.dart';
import 'package:prompt_library/src/app/composition_root.dart';
import 'package:prompt_library/src/app/prompt_library_app.dart';
import 'package:prompt_library/src/library/data/drift_library_repository.dart';
import 'package:prompt_library/src/library/data/library_database.dart';
import 'package:prompt_library/src/library/models/entry_input.dart';
import 'package:prompt_library/src/library/presentation/library_clipboard.dart';
import 'package:prompt_library/src/library/presentation/library_controller.dart';
import 'package:prompt_library/src/library/presentation/library_document_files.dart';
import 'package:prompt_library/src/library/presentation/library_haptics.dart';
import 'package:prompt_library/src/library/presentation/library_share.dart';
import 'package:prompt_library/src/platform/ios/share_plus_library_share.dart';
import 'package:prompt_library/src/library/presentation/mobile/mobile_library_screen.dart';
import 'package:prompt_library/src/library/presentation/transfer/library_transfer_controller.dart';
import 'package:prompt_library/src/library/presentation/transfer/library_transfer_state.dart';
import 'package:prompt_library/src/platform/documents/file_selector_document_files.dart';
import 'package:prompt_library/src/platform/macos/mac_quick_panel_port.dart';
import 'package:prompt_library/src/platform/macos/method_channel_mac_quick_panel.dart';
import 'package:prompt_library/src/platform/macos/unavailable_mac_quick_panel.dart';
import 'package:prompt_library/src/platform/macos/quick_panel_controller.dart';

import '../support/library_test_support.dart';

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
    final transfer = testTransferController(repository, controller);
    final composition = PromptLibraryComposition(
      applicationSurface: ApplicationSurface.desktop,
      database: database,
      repository: repository,
      controller: controller,
      clipboard: const _NoopClipboard(),
      documentFiles: TestDocumentFiles(),
      transferController: transfer,
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

  test(
    'production graph owns the transfer boundary over the library',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final tempDir = await Directory.systemTemp.createTemp('pl-production');
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async => tempDir.path);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      final composition = PromptLibraryComposition.production();
      addTearDown(() => composition.dispose());

      final files = composition.documentFiles;
      expect(files, isA<FileSelectorDocumentFiles>());
      expect(
        (files as FileSelectorDocumentFiles).exportClient,
        isNotNull,
        reason: 'production binds the native export client',
      );
      final transfer = composition.transferController;
      expect(transfer, isNotNull);
      expect(transfer.state, isA<LibraryTransferIdle>());

      await composition.controller.createEntry(
        EntryInput.validate(title: 'Graph connectivity', body: 'Body'),
      );
      await pumpEventQueue();

      await transfer.prepareExport(DocumentExportKind.json);

      expect(
        transfer.state,
        isA<LibraryTransferExportReady>(),
        reason: 'the transfer owner reads the same production database',
      );
      final bytes = transfer.preparedBytes;
      expect(bytes, isNotNull);
      final exported = utf8.decode(bytes!);
      expect(
        exported,
        contains('Graph connectivity'),
        reason:
            'the prepared export carries the entry created through the '
            'composition controller, so the owner is bound to the same '
            'repository',
      );
    },
  );

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
      documentFiles: TestDocumentFiles(),
      transferController: testTransferController(repository, controller),
      share: share,
      haptics: haptics,
    );

    await tester.pumpWidget(
      PromptLibraryApp(
        applicationSurface: composition.applicationSurface,
        controller: composition.controller,
        clipboard: composition.clipboard,
        transferController: composition.transferController,
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
        documentFiles: TestDocumentFiles(),
        transferController: testTransferController(repository, controller),
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

  test(
    'disposes transfer, quick, library, and database in exact order',
    () async {
      final order = <String>[];

      await PromptLibraryComposition.disposeResourcesInOrder(
        disposeTransfer: () async => order.add('transfer'),
        disposeQuickPanel: () async => order.add('quick'),
        disposeLibrary: () async => order.add('library'),
        closeDatabase: () async => order.add('database'),
      );

      expect(order, ['transfer', 'quick', 'library', 'database']);
    },
  );

  test(
    'holds the rest of teardown while a transfer transaction is held',
    () async {
      final order = <String>[];
      final gate = Completer<void>();

      final releasing = PromptLibraryComposition.disposeResourcesInOrder(
        disposeTransfer: () async {
          order.add('transfer:start');
          await gate.future;
          order.add('transfer:end');
        },
        disposeQuickPanel: () async => order.add('quick'),
        disposeLibrary: () async => order.add('library'),
        closeDatabase: () async => order.add('database'),
      );
      await pumpEventQueue();

      expect(order, ['transfer:start']);

      gate.complete();
      await releasing;

      expect(order, [
        'transfer:start',
        'transfer:end',
        'quick',
        'library',
        'database',
      ]);
    },
  );

  test('preserves the primary teardown error across failing steps', () async {
    await runZonedGuarded(() async {
      final release = PromptLibraryComposition.disposeResourcesInOrder(
        disposeTransfer: () async => throw StateError('primary'),
        disposeQuickPanel: () async => throw StateError('secondary'),
        disposeLibrary: () async {},
        closeDatabase: () async {},
      );

      await expectLater(
        release,
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'primary',
          ),
        ),
      );
    }, (error, stackTrace) {});
  });

  test('reports secondary teardown errors to the zone', () async {
    final zoneErrors = <Object>[];

    await runZonedGuarded(() async {
      final release = PromptLibraryComposition.disposeResourcesInOrder(
        disposeTransfer: () async => throw StateError('primary'),
        disposeQuickPanel: () async => throw StateError('secondary'),
        disposeLibrary: () async {},
        closeDatabase: () async {},
      );
      await expectLater(
        release,
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'primary',
          ),
        ),
      );
    }, (error, stackTrace) => zoneErrors.add(error));

    expect(zoneErrors, [
      isA<StateError>().having(
        (error) => error.message,
        'message',
        'secondary',
      ),
    ]);
  });

  test('still closes remaining resources after a step fails', () async {
    final order = <String>[];

    await expectLater(
      PromptLibraryComposition.disposeResourcesInOrder(
        disposeTransfer: () async {
          order.add('transfer');
          throw StateError('primary');
        },
        disposeQuickPanel: () async => order.add('quick'),
        disposeLibrary: () async => order.add('library'),
        closeDatabase: () async => order.add('database'),
      ),
      throwsStateError,
    );

    expect(order, ['transfer', 'quick', 'library', 'database']);
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

  test('selects the system share on iOS and unavailable elsewhere', () {
    final ios = PromptLibraryComposition.createShare(isIOS: true);
    final other = PromptLibraryComposition.createShare(isIOS: false);

    expect(ios, isA<SharePlusLibraryShare>());
    expect(other, isA<UnavailableLibraryShare>());
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

  test('request exit begins the transfer shutdown before voting', () async {
    final gate = Completer<void>();
    var begun = false;
    final lifecycle = PromptLibraryLifecycle(
      () async {},
      beginShutdown: () {
        begun = true;
        return gate.future;
      },
    );

    final voting = lifecycle.requestExit();
    await pumpEventQueue();
    expect(begun, isTrue);
    var returned = false;
    unawaited(voting.then((_) => returned = true));
    await pumpEventQueue();
    expect(returned, isFalse);

    gate.complete();
    expect(await voting, AppExitResponse.exit);
    expect(returned, isTrue);
  });

  test('exit voting through the composition seam holds and rejects', () async {
    final database = LibraryDatabase.forTesting(NativeDatabase.memory());
    final repository = DriftLibraryRepository(database);
    final controller = LibraryController(repository: repository);
    final files = TestDocumentFiles();
    final gate = Completer<void>();
    files.pickGate = gate;
    files.pickResult = const DocumentPickCancelled();
    final transfer = LibraryTransferController(
      repository: repository,
      library: controller,
      files: files,
    );
    final composition = PromptLibraryComposition(
      applicationSurface: ApplicationSurface.desktop,
      database: database,
      repository: repository,
      controller: controller,
      clipboard: const _NoopClipboard(),
      documentFiles: files,
      transferController: transfer,
    );
    addTearDown(() => composition.dispose());
    final lifecycle = PromptLibraryLifecycle(
      composition.dispose,
      beginShutdown: composition.beginTransferShutdown,
    );

    final picking = transfer.startImport();
    await pumpEventQueue();

    final voting = lifecycle.requestExit();
    await pumpEventQueue();

    expect(
      () => transfer.startImport(),
      throwsStateError,
      reason: 'voting through the seam rejects operations started after it',
    );
    var returned = false;
    unawaited(voting.then((_) => returned = true));
    await pumpEventQueue();
    expect(returned, isFalse, reason: 'voting awaits the held operation');

    gate.complete();
    await picking;
    expect(await voting, AppExitResponse.exit);
    expect(returned, isTrue);
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

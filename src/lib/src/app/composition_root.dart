/// Production application composition.
library;

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../library/data/drift_library_repository.dart';
import '../library/data/library_database.dart';
import '../library/presentation/library_clipboard.dart';
import '../library/presentation/library_controller.dart';
import '../library/presentation/library_haptics.dart';
import '../library/presentation/library_share.dart';
import '../platform/macos/mac_quick_panel_port.dart';
import '../platform/macos/method_channel_mac_quick_panel.dart';
import '../platform/macos/quick_panel_controller.dart';
import '../platform/macos/unavailable_mac_quick_panel.dart';
import 'application_surface.dart';
import 'prompt_library_app.dart';

/// Selects the application surface for the current target.
ApplicationSurface selectApplicationSurface({required bool isIOS}) {
  return isIOS ? ApplicationSurface.mobile : ApplicationSurface.desktop;
}

/// Owns the complete application object graph.
final class PromptLibraryComposition {
  /// Creates an explicit composition.
  PromptLibraryComposition({
    required this.applicationSurface,
    required this.database,
    required this.repository,
    required this.controller,
    required this.clipboard,
    this.share = const UnavailableLibraryShare(),
    this.haptics = const FlutterLibraryHaptics(),
    QuickPanelController? quickPanelController,
    this.quickAccessSupported = false,
  }) : quickPanelController =
           quickPanelController ??
           QuickPanelController(
             libraryController: controller,
             clipboard: clipboard,
             port: const UnavailableMacQuickPanel(),
           );

  /// Creates the production object graph.
  factory PromptLibraryComposition.production() {
    final database = LibraryDatabase();
    final repository = DriftLibraryRepository(database);
    final controller = LibraryController(repository: repository);
    final clipboard = FlutterLibraryClipboard();
    final applicationSurface = selectApplicationSurface(isIOS: Platform.isIOS);
    final port = createPlatformPort(isMacOS: Platform.isMacOS);
    final quickPanelController = QuickPanelController(
      libraryController: controller,
      clipboard: clipboard,
      port: port,
    );
    return PromptLibraryComposition(
      applicationSurface: applicationSurface,
      database: database,
      repository: repository,
      controller: controller,
      clipboard: clipboard,
      quickPanelController: quickPanelController,
      quickAccessSupported: Platform.isMacOS,
    );
  }

  /// Creates the concrete or unavailable port at the composition boundary.
  @visibleForTesting
  static MacQuickPanelPort createPlatformPort({
    required bool isMacOS,
    BinaryMessenger? messenger,
  }) {
    return isMacOS
        ? MethodChannelMacQuickPanel(messenger: messenger)
        : const UnavailableMacQuickPanel();
  }

  /// Normal application surface.
  final ApplicationSurface applicationSurface;

  /// Production database.
  final LibraryDatabase database;

  /// Production repository.
  final DriftLibraryRepository repository;

  /// Shared library controller.
  final LibraryController controller;

  /// Exact clipboard boundary.
  final LibraryClipboard clipboard;

  /// System sharing boundary.
  final LibraryShare share;

  /// Best-effort tactile feedback boundary.
  final LibraryHaptics haptics;

  /// Quick workflow and native-port owner.
  final QuickPanelController quickPanelController;

  /// Whether macOS quick settings are exposed.
  final bool quickAccessSupported;

  Future<void>? _startFuture;
  Future<void>? _disposeFuture;

  /// Registers the default Control+Option+Space shortcut once.
  Future<void> start() {
    return _startFuture ??= quickPanelController.initialize(
      HotKeySpec(
        keyCode: 49,
        modifiers: {HotKeyModifier.control, HotKeyModifier.option},
      ),
    );
  }

  /// Disposes all owned resources once.
  Future<void> dispose() {
    return _disposeFuture ??= _dispose();
  }

  Future<void> _dispose() {
    return disposeResourcesInOrder(
      disposeQuickPanel: quickPanelController.dispose,
      disposeLibrary: controller.dispose,
      closeDatabase: database.close,
    );
  }

  /// Applies the required quick-controller, library, database teardown order.
  @visibleForTesting
  static Future<void> disposeResourcesInOrder({
    required Future<void> Function() disposeQuickPanel,
    required Future<void> Function() disposeLibrary,
    required Future<void> Function() closeDatabase,
  }) async {
    await disposeQuickPanel();
    await disposeLibrary();
    await closeDatabase();
  }
}

/// Coordinates exit voting and post-exit release.
final class PromptLibraryLifecycle {
  /// Creates a lifecycle coordinator.
  PromptLibraryLifecycle(this._dispose);

  final Future<void> Function() _dispose;

  /// Votes without releasing dependencies.
  Future<AppExitResponse> requestExit() async => AppExitResponse.exit;

  /// Releases dependencies after detach or widget teardown.
  void release() {
    unawaited(_dispose());
  }
}

/// Creates and owns production dependencies.
final class PromptLibraryCompositionRoot extends StatefulWidget {
  /// Creates application root.
  const PromptLibraryCompositionRoot({super.key, this.composition});

  /// Optional injected composition.
  final PromptLibraryComposition? composition;

  @override
  State<PromptLibraryCompositionRoot> createState() =>
      _PromptLibraryCompositionRootState();
}

final class _PromptLibraryCompositionRootState
    extends State<PromptLibraryCompositionRoot> {
  late final PromptLibraryComposition _composition;
  late final PromptLibraryLifecycle _lifecycle;
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _composition = widget.composition ?? PromptLibraryComposition.production();
    _lifecycle = PromptLibraryLifecycle(_composition.dispose);
    _lifecycleListener = AppLifecycleListener(
      onExitRequested: _lifecycle.requestExit,
      onDetach: _lifecycle.release,
    );
    unawaited(_composition.start());
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    _lifecycle.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PromptLibraryApp(
      applicationSurface: _composition.applicationSurface,
      controller: _composition.controller,
      clipboard: _composition.clipboard,
      share: _composition.share,
      haptics: _composition.haptics,
      quickPanelController: _composition.quickPanelController,
      quickAccessSupported: _composition.quickAccessSupported,
    );
  }
}

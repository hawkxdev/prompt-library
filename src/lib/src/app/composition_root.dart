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
import '../library/presentation/library_document_files.dart';
import '../library/presentation/library_haptics.dart';
import '../library/presentation/library_share.dart';
import '../library/presentation/transfer/library_transfer_controller.dart';
import '../platform/documents/file_selector_document_files.dart';
import '../platform/documents/method_channel_document_export.dart';
import '../platform/ios/share_plus_library_share.dart';
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
    this.documentFiles,
    this.transferController,
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
    final share = createShare(isIOS: Platform.isIOS);
    final port = createPlatformPort(isMacOS: Platform.isMacOS);
    final quickPanelController = QuickPanelController(
      libraryController: controller,
      clipboard: clipboard,
      port: port,
    );
    final documentFiles = FileSelectorDocumentFiles(
      exportClient: MethodChannelDocumentExport().export,
    );
    final transferController = LibraryTransferController(
      repository: repository,
      library: controller,
      files: documentFiles,
    );
    return PromptLibraryComposition(
      applicationSurface: applicationSurface,
      database: database,
      repository: repository,
      controller: controller,
      clipboard: clipboard,
      share: share,
      quickPanelController: quickPanelController,
      quickAccessSupported: Platform.isMacOS,
      documentFiles: documentFiles,
      transferController: transferController,
    );
  }

  /// Creates the system or unavailable sharing at the composition boundary.
  @visibleForTesting
  static LibraryShare createShare({required bool isIOS}) {
    return isIOS
        ? const SharePlusLibraryShare()
        : const UnavailableLibraryShare();
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

  /// Document file boundary for transfer operations.
  final LibraryDocumentFiles? documentFiles;

  /// Transfer operation owner.
  final LibraryTransferController? transferController;

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
      disposeTransfer: transferController?.dispose,
      disposeQuickPanel: quickPanelController.dispose,
      disposeLibrary: controller.dispose,
      closeDatabase: database.close,
    );
  }

  /// Applies the required transfer, quick, library, database teardown order.
  ///
  /// A failing step records the first error and its stack trace and the
  /// remaining steps still run; the recorded error is rethrown at the end.
  @visibleForTesting
  static Future<void> disposeResourcesInOrder({
    Future<void> Function()? disposeTransfer,
    required Future<void> Function() disposeQuickPanel,
    required Future<void> Function() disposeLibrary,
    required Future<void> Function() closeDatabase,
  }) async {
    Object? firstError;
    StackTrace? firstStack;
    var failed = false;
    Future<void> guarded(Future<void> Function()? step) async {
      if (step == null) return;
      try {
        await step();
      } catch (error, stackTrace) {
        if (!failed) {
          failed = true;
          firstError = error;
          firstStack = stackTrace;
        }
      }
    }

    await guarded(disposeTransfer);
    await guarded(disposeQuickPanel);
    await guarded(disposeLibrary);
    await guarded(closeDatabase);
    if (failed) {
      Error.throwWithStackTrace(firstError!, firstStack!);
    }
  }

  /// Waits for the started transfer operation to release its resources.
  Future<void> awaitTransferSettled() async {
    await transferController?.settled;
  }
}

/// Coordinates exit voting and post-exit release.
final class PromptLibraryLifecycle {
  /// Creates a lifecycle coordinator.
  PromptLibraryLifecycle(
    this._dispose, {
    Future<void> Function()? awaitTransfer,
  }) : _awaitTransfer = awaitTransfer ?? (() async {});

  final Future<void> Function() _dispose;
  final Future<void> Function() _awaitTransfer;

  /// Waits for the active transfer operation, then votes to exit.
  Future<AppExitResponse> requestExit() async {
    await _awaitTransfer();
    return AppExitResponse.exit;
  }

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
    _lifecycle = PromptLibraryLifecycle(
      _composition.dispose,
      awaitTransfer: _composition.awaitTransferSettled,
    );
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

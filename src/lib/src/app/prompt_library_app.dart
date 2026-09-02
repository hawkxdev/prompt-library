/// Application surface.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../library/presentation/library_clipboard.dart';
import '../library/presentation/library_controller.dart';
import '../library/presentation/library_haptics.dart';
import '../library/presentation/library_screen.dart';
import '../library/presentation/library_share.dart';
import '../library/presentation/mobile/mobile_library_screen.dart';
import '../platform/macos/hotkey_settings_dialog.dart';
import '../platform/macos/quick_mode_view.dart';
import '../platform/macos/quick_panel_controller.dart';
import '../platform/macos/quick_panel_state.dart';
import 'application_surface.dart';

/// Root application widget selecting one shared full or quick surface.
final class PromptLibraryApp extends StatefulWidget {
  /// Creates application widget.
  const PromptLibraryApp({
    required this.applicationSurface,
    required this.controller,
    required this.clipboard,
    this.share = const UnavailableLibraryShare(),
    this.haptics = const FlutterLibraryHaptics(),
    this.quickPanelController,
    this.quickAccessSupported = false,
    super.key,
  });

  /// Application bar title.
  static const String appTitle = 'Prompt Library';

  /// Normal application surface.
  final ApplicationSurface applicationSurface;

  /// Shared application controller.
  final LibraryController controller;

  /// Exact clipboard boundary.
  final LibraryClipboard clipboard;

  /// System sharing boundary.
  final LibraryShare share;

  /// Best-effort tactile feedback boundary.
  final LibraryHaptics haptics;

  /// Optional quick-workflow controller.
  final QuickPanelController? quickPanelController;

  /// Whether macOS shortcut settings should be exposed.
  final bool quickAccessSupported;

  @override
  State<PromptLibraryApp> createState() => _PromptLibraryAppState();
}

final class _PromptLibraryAppState extends State<PromptLibraryApp> {
  QuickPanelState? _quickState;
  StreamSubscription<QuickPanelState>? _quickSubscription;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _bindQuickController();
  }

  @override
  void didUpdateWidget(PromptLibraryApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(
      oldWidget.quickPanelController,
      widget.quickPanelController,
    )) {
      unawaited(_quickSubscription?.cancel());
      _quickSubscription = null;
      _bindQuickController();
    }
  }

  @override
  void dispose() {
    unawaited(_quickSubscription?.cancel());
    super.dispose();
  }

  void _bindQuickController() {
    final quick = widget.quickPanelController;
    _quickState = quick?.state;
    _quickSubscription = quick?.states.listen((state) {
      if (!mounted) {
        return;
      }
      final enteringQuick =
          state.mode == QuickPanelMode.quick &&
          _quickState?.mode != QuickPanelMode.quick;
      if (enteringQuick) {
        _navigatorKey.currentState?.popUntil((route) => route.isFirst);
      }
      setState(() => _quickState = state);
    });
  }

  @override
  Widget build(BuildContext context) {
    const colorScheme = ColorScheme.light(
      primary: Color(0xFF315E9E),
      onPrimary: Color(0xFFFFFFFF),
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF18212B),
      primaryContainer: Color(0xFFDCE7F6),
      onPrimaryContainer: Color(0xFF18212B),
      error: Color(0xFFB3261E),
    );
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: PromptLibraryApp.appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF3F5F7),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    final quick = widget.quickPanelController;
    if (quick != null && _quickState?.mode == QuickPanelMode.quick) {
      return QuickModeView(
        libraryController: widget.controller,
        quickPanelController: quick,
      );
    }
    return switch (widget.applicationSurface) {
      ApplicationSurface.desktop => _buildFullLibrary(),
      ApplicationSurface.mobile => _buildMobileLibrary(),
    };
  }

  /// Builds mobile retrieval surface.
  Widget _buildMobileLibrary() {
    return MobileLibraryScreen(
      controller: widget.controller,
      clipboard: widget.clipboard,
      share: widget.share,
      haptics: widget.haptics,
    );
  }

  /// Builds full library surface.
  Widget _buildFullLibrary() {
    final quick = widget.quickPanelController;
    return Builder(
      builder: (context) => LibraryScreen(
        controller: widget.controller,
        clipboard: widget.clipboard,
        onConfigureHotKey: widget.quickAccessSupported && quick != null
            ? () => showHotKeySettingsDialog(context, controller: quick)
            : null,
      ),
    );
  }
}

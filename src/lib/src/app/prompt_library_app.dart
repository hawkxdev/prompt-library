/// Application surface.
library;

import 'package:flutter/material.dart';

import '../library/presentation/library_clipboard.dart';
import '../library/presentation/library_controller.dart';
import '../library/presentation/library_screen.dart';

/// Root application widget.
final class PromptLibraryApp extends StatelessWidget {
  /// Creates application widget.
  const PromptLibraryApp({
    required this.controller,
    required this.clipboard,
    super.key,
  });

  /// Application bar title.
  static const String appTitle = 'Prompt Library';

  /// Application controller.
  final LibraryController controller;

  /// Clipboard boundary.
  final LibraryClipboard clipboard;

  /// Builds the application.
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
      title: appTitle,
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
      home: LibraryScreen(controller: controller, clipboard: clipboard),
    );
  }
}

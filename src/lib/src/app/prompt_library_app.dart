/// Application surface.
library;

import 'package:flutter/material.dart';

/// Root application widget.
class PromptLibraryApp extends StatelessWidget {
  /// Creates application widget.
  const PromptLibraryApp({super.key});

  /// Application bar title.
  static const String appTitle = 'Prompt Library';

  /// Empty library message.
  static const String emptyLibraryMessage = 'Your library is empty';

  /// Builds the shell.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF486581),
        brightness: Brightness.light,
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text(appTitle)),
        body: const Center(child: Text(emptyLibraryMessage)),
      ),
    );
  }
}

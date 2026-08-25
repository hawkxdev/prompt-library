/// Production application composition.
library;

import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';

import '../library/data/drift_library_repository.dart';
import '../library/data/library_database.dart';
import '../library/presentation/library_clipboard.dart';
import '../library/presentation/library_controller.dart';
import 'prompt_library_app.dart';

/// Owns the application object graph.
final class PromptLibraryComposition {
  /// Creates an explicit composition.
  PromptLibraryComposition({
    required this.database,
    required this.repository,
    required this.controller,
    required this.clipboard,
  });

  /// Creates the production object graph.
  factory PromptLibraryComposition.production() {
    final database = LibraryDatabase();
    final repository = DriftLibraryRepository(database);
    return PromptLibraryComposition(
      database: database,
      repository: repository,
      controller: LibraryController(repository: repository),
      clipboard: FlutterLibraryClipboard(),
    );
  }

  /// Production database.
  final LibraryDatabase database;

  /// Production repository.
  final DriftLibraryRepository repository;

  /// Application controller.
  final LibraryController controller;

  /// Clipboard boundary.
  final LibraryClipboard clipboard;

  Future<void>? _disposeFuture;

  /// Disposes all owned resources.
  Future<void> dispose() {
    return _disposeFuture ??= _dispose();
  }

  Future<void> _dispose() async {
    await controller.dispose();
    await database.close();
  }
}

/// Creates and owns production dependencies.
final class PromptLibraryCompositionRoot extends StatefulWidget {
  /// Creates production root.
  const PromptLibraryCompositionRoot({super.key});

  @override
  State<PromptLibraryCompositionRoot> createState() =>
      _PromptLibraryCompositionRootState();
}

final class _PromptLibraryCompositionRootState
    extends State<PromptLibraryCompositionRoot> {
  late final PromptLibraryComposition _composition;
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _composition = PromptLibraryComposition.production();
    _lifecycleListener = AppLifecycleListener(
      onExitRequested: () async {
        await _composition.dispose();
        return AppExitResponse.exit;
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    unawaited(_composition.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PromptLibraryApp(
      controller: _composition.controller,
      clipboard: _composition.clipboard,
    );
  }
}

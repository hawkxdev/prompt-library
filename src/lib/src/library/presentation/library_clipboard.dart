/// Clipboard boundary.
library;

import 'package:flutter/services.dart';

import '../models/entry.dart';
import '../models/library_failure.dart';
import 'library_controller.dart';

/// Writes exact library text.
abstract interface class LibraryClipboard {
  /// Writes text to clipboard.
  Future<void> writeText(String text);
}

/// Stable clipboard failure.
final class LibraryClipboardFailure implements Exception {
  /// Creates clipboard failure.
  const LibraryClipboardFailure();
}

/// Copies one entry and records metadata while the controller is active.
Future<void> copyLibraryEntry({
  required Entry entry,
  required LibraryClipboard clipboard,
  required LibraryController controller,
}) async {
  await clipboard.writeText(entry.body);
  if (controller.isDisposed) return;
  try {
    await controller.markCopied(entry.id);
  } on LibraryFailure {
    // Clipboard success remains authoritative when metadata persistence fails.
  }
}

/// Flutter clipboard adapter.
final class FlutterLibraryClipboard implements LibraryClipboard {
  /// Writes text through Flutter services.
  @override
  Future<void> writeText(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } on PlatformException {
      throw const LibraryClipboardFailure();
    } on MissingPluginException {
      throw const LibraryClipboardFailure();
    }
  }
}

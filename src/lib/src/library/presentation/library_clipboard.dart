/// Clipboard boundary.
library;

import 'package:flutter/services.dart';

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

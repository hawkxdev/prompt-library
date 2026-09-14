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

/// Outcomes of one full copy cycle.
enum LibraryCopyOutcome {
  /// The buffer and metadata were written.
  copied,

  /// The buffer refused the write.
  clipboardFailure,

  /// The controller refused the admission before any write.
  notAdmitted,
}

/// Copies one entry through one admitted cycle and records metadata while
/// the controller is active.
///
/// The admission is released whatever the outcome is; an unexpected buffer
/// or metadata error reaches the caller unchanged.
Future<LibraryCopyOutcome> copyLibraryEntry({
  required Entry entry,
  required LibraryClipboard clipboard,
  required LibraryController controller,
}) async {
  final cycle = controller.admitCopyCycle(entry.id);
  if (cycle == null) {
    return LibraryCopyOutcome.notAdmitted;
  }
  try {
    try {
      await clipboard.writeText(entry.body);
    } on LibraryClipboardFailure {
      return LibraryCopyOutcome.clipboardFailure;
    }
    if (controller.isDisposed) return LibraryCopyOutcome.copied;
    try {
      await cycle.markCopied();
    } on LibraryFailure {
      // Clipboard success remains authoritative when metadata persistence fails.
    }
    return LibraryCopyOutcome.copied;
  } finally {
    cycle.release();
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

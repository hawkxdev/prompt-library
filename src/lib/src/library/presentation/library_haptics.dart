/// Tactile feedback boundary.
library;

import 'package:flutter/services.dart';

/// Provides best-effort tactile feedback for library actions.
abstract interface class LibraryHaptics {
  /// Requests one selection-level feedback.
  Future<void> selectionFeedback();
}

/// Flutter tactile feedback adapter.
final class FlutterLibraryHaptics implements LibraryHaptics {
  /// Creates Flutter tactile feedback.
  const FlutterLibraryHaptics();

  @override
  Future<void> selectionFeedback() async {
    try {
      await HapticFeedback.selectionClick();
    } on PlatformException {
      // Tactile feedback must not change the action result.
    } on MissingPluginException {
      // Platforms without the channel keep the action successful.
    }
  }
}

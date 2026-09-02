/// System sharing boundary.
library;

import 'dart:ui' show Rect;

/// Reports one observable sharing outcome.
///
/// A selected activity is not evidence that content was sent or delivered.
enum LibraryShareOutcome {
  /// The user selected a system activity.
  selected,

  /// The user dismissed the system surface.
  dismissed,

  /// System sharing is unavailable.
  unavailable,

  /// The system invocation failed.
  invocationFailure,
}

/// Presents exact library text through a system share surface.
abstract interface class LibraryShare {
  /// Presents one exact text payload.
  ///
  /// [anchor] is the initiating control rectangle in global logical pixels.
  /// Implementations must complete within a bounded time.
  Future<LibraryShareOutcome> shareText(String text, {Rect? anchor});
}

/// Explicit unavailable sharing capability.
final class UnavailableLibraryShare implements LibraryShare {
  /// Creates unavailable sharing.
  const UnavailableLibraryShare();

  @override
  Future<LibraryShareOutcome> shareText(String text, {Rect? anchor}) async {
    return LibraryShareOutcome.unavailable;
  }
}

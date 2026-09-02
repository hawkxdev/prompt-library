/// Mobile retrieval actions.
library;

import 'package:flutter/services.dart';

import '../../models/entry.dart';
import '../library_clipboard.dart';
import '../library_controller.dart';

/// Reports the observable result of one mobile copy cycle.
enum MobileCopyOutcome { copied, clipboardFailure }

/// Coalesces one complete copy cycle per entry.
final class MobileLibraryActions {
  /// Creates mobile retrieval actions.
  MobileLibraryActions({required this.controller, required this.clipboard});

  /// Shared application controller.
  final LibraryController controller;

  /// Exact clipboard boundary.
  final LibraryClipboard clipboard;

  final Map<String, Future<MobileCopyOutcome>> _inFlight = {};

  /// Whether a copy cycle for this entry is in flight.
  bool isPending(String entryId) => _inFlight.containsKey(entryId);

  /// Runs or joins the copy cycle for one entry.
  ///
  /// The call that starts the cycle receives its outcome. A call that joins an
  /// in-flight cycle awaits the same operation and receives null, so feedback
  /// is presented exactly once per cycle.
  Future<MobileCopyOutcome?> copyEntry(Entry entry) {
    final joined = _inFlight[entry.id];
    if (joined != null) {
      return joined.then((_) => null);
    }
    final cycle = _runCycle(entry);
    _inFlight[entry.id] = cycle;
    return cycle;
  }

  /// Executes one guarded copy cycle.
  Future<MobileCopyOutcome> _runCycle(Entry entry) async {
    try {
      try {
        await copyLibraryEntry(
          entry: entry,
          clipboard: clipboard,
          controller: controller,
        );
      } on LibraryClipboardFailure {
        return MobileCopyOutcome.clipboardFailure;
      }
      await _requestHapticFeedback();
      return MobileCopyOutcome.copied;
    } finally {
      _inFlight.remove(entry.id);
    }
  }

  /// Requests best-effort selection haptic after a successful copy.
  Future<void> _requestHapticFeedback() async {
    try {
      await HapticFeedback.selectionClick();
    } on PlatformException {
      // Haptic feedback is best-effort; clipboard success stays authoritative.
    } on MissingPluginException {
      // A platform without the haptic channel must not fail the copy cycle.
    }
  }
}

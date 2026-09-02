/// Mobile retrieval actions.
library;

import 'dart:ui' show Rect;

import '../../models/entry.dart';
import '../library_clipboard.dart';
import '../library_controller.dart';
import '../library_haptics.dart';
import '../library_share.dart';

/// Reports the observable result of one mobile copy cycle.
enum MobileCopyOutcome { copied, clipboardFailure }

/// Coalesces one complete copy cycle per entry.
final class MobileLibraryActions {
  /// Creates mobile retrieval actions.
  MobileLibraryActions({
    required this.controller,
    required this.clipboard,
    required this.share,
    required this.haptics,
  });

  /// Shared application controller.
  final LibraryController controller;

  /// Exact clipboard boundary.
  final LibraryClipboard clipboard;

  /// System sharing boundary.
  final LibraryShare share;

  /// Best-effort tactile feedback boundary.
  final LibraryHaptics haptics;

  final Map<String, Future<MobileCopyOutcome>> _inFlight = {};
  final Map<String, Future<LibraryShareOutcome>> _sharesInFlight = {};

  /// Whether a copy cycle for this entry is in flight.
  bool isPending(String entryId) => _inFlight.containsKey(entryId);

  /// Whether a share cycle for this entry is in flight.
  bool isSharePending(String entryId) => _sharesInFlight.containsKey(entryId);

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

  /// Runs or joins the share cycle for one entry.
  ///
  /// The call that starts the cycle receives its outcome. A joining call
  /// awaits the same operation and receives null so feedback appears once.
  Future<LibraryShareOutcome?> shareEntry(Entry entry, {Rect? anchor}) {
    final joined = _sharesInFlight[entry.id];
    if (joined != null) {
      return joined.then((_) => null);
    }
    final cycle = _runShareCycle(entry, anchor: anchor);
    _sharesInFlight[entry.id] = cycle;
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
      await haptics.selectionFeedback();
      return MobileCopyOutcome.copied;
    } finally {
      _inFlight.remove(entry.id);
    }
  }

  /// Executes one guarded share cycle.
  Future<LibraryShareOutcome> _runShareCycle(
    Entry entry, {
    Rect? anchor,
  }) async {
    try {
      return await share.shareText(entry.body, anchor: anchor);
    } finally {
      _sharesInFlight.remove(entry.id);
    }
  }
}

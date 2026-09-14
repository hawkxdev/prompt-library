/// Mobile retrieval actions.
library;

import 'dart:async';
import 'dart:ui' show Rect;

import '../../models/entry.dart';
import '../../models/library_failure.dart';
import '../library_clipboard.dart';
import '../library_controller.dart';
import '../library_haptics.dart';
import '../library_share.dart';
import '../library_state.dart';

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
  final Map<(String, LibraryMutationKind), Future<void>> _mutationsInFlight =
      {};

  /// Whether a copy cycle for this entry is in flight.
  bool isPending(String entryId) => _inFlight.containsKey(entryId);

  /// Whether a share cycle for this entry is in flight.
  bool isSharePending(String entryId) => _sharesInFlight.containsKey(entryId);

  /// Whether a mutation for this entry and action kind is in flight.
  bool isActionPending(String entryId, LibraryMutationKind kind) {
    return _mutationsInFlight.containsKey((entryId, kind)) ||
        controller.state.isMutationActive(
          LibraryMutationKey(kind, entityId: entryId),
        );
  }

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
    final pending = Completer<LibraryShareOutcome>.sync();
    _sharesInFlight[entry.id] = pending.future;
    unawaited(_runShareCycle(entry, pending: pending, anchor: anchor));
    return pending.future;
  }

  /// Executes one guarded copy cycle.
  Future<MobileCopyOutcome> _runCycle(Entry entry) async {
    try {
      final outcome = await copyLibraryEntry(
        entry: entry,
        clipboard: clipboard,
        controller: controller,
      );
      if (outcome == LibraryCopyOutcome.clipboardFailure) {
        return MobileCopyOutcome.clipboardFailure;
      }
      await _requestHapticFeedback();
      return MobileCopyOutcome.copied;
    } finally {
      _inFlight.remove(entry.id);
    }
  }

  /// Requests non-authoritative tactile feedback.
  Future<void> _requestHapticFeedback() async {
    try {
      await haptics.selectionFeedback();
    } on Object {
      return;
    }
  }

  /// Executes one guarded share cycle.
  Future<void> _runShareCycle(
    Entry entry, {
    required Completer<LibraryShareOutcome> pending,
    Rect? anchor,
  }) async {
    LibraryShareOutcome outcome;
    try {
      outcome = await share.shareText(entry.body, anchor: anchor);
    } on Object {
      outcome = LibraryShareOutcome.invocationFailure;
    } finally {
      _sharesInFlight.remove(entry.id);
    }
    pending.complete(outcome);
  }

  /// Toggles or sets favorite state for one entry.
  Future<void> setFavorite(Entry entry, {bool? isFavorite}) {
    return _runMutation(
      LibraryMutationKind.setFavorite,
      entry.id,
      () => controller.setFavorite(
        entry.id,
        isFavorite: isFavorite ?? !entry.isFavorite,
      ),
    );
  }

  /// Toggles or sets archive state for one entry.
  Future<void> setArchived(Entry entry, {bool? isArchived}) {
    return _runMutation(
      LibraryMutationKind.setArchived,
      entry.id,
      () => controller.setArchived(
        entry.id,
        isArchived: isArchived ?? !entry.isArchived,
      ),
    );
  }

  /// Deletes one entry.
  Future<void> deleteEntry(Entry entry) {
    return _runMutation(
      LibraryMutationKind.deleteEntry,
      entry.id,
      () => controller.deleteEntry(entry.id),
    );
  }

  /// Executes one guarded mutation cycle coalesced per entry and kind.
  Future<void> _runMutation(
    LibraryMutationKind kind,
    String entryId,
    Future<void> Function() operation,
  ) {
    final key = (entryId, kind);
    final inFlight = _mutationsInFlight[key];
    if (inFlight != null) {
      return inFlight;
    }
    final future = _executeMutation(key, operation);
    _mutationsInFlight[key] = future;
    return future;
  }

  /// Runs the mutation and catches expected [LibraryFailure] instances.
  Future<void> _executeMutation(
    (String, LibraryMutationKind) key,
    Future<void> Function() operation,
  ) async {
    try {
      await operation();
    } on LibraryFailure {
      // The controller retains a non-sensitive failure for the banner.
    } finally {
      _mutationsInFlight.remove(key);
    }
  }
}

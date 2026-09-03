/// System sharing adapter over the share_plus package.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../library/presentation/library_share.dart';

/// Presents exact text through the system share surface.
///
/// The package reports `unavailable` when a host presented the surface but
/// cannot determine the chosen action. That is not the absent capability the
/// boundary means by [LibraryShareOutcome.unavailable], so it maps to
/// [LibraryShareOutcome.selected]: the surface did its work and the caller
/// stays silent. Claiming absence there would tell the user that sharing does
/// not work on a device where it just did.
final class SharePlusLibraryShare implements LibraryShare {
  /// Creates the system sharing adapter.
  const SharePlusLibraryShare({this.present, this.timeout = defaultTimeout});

  /// Upper bound on one share cycle.
  ///
  /// A feasibility probe measured 13.5 s for an AirDrop detour and 25.5 s for
  /// an activity-list detour, both of them ordinary use. The bound only has to
  /// keep a never-reported dismissal from holding the cycle forever, so it sits
  /// far above interaction time rather than close to it.
  static const Duration defaultTimeout = Duration(minutes: 5);

  /// Bound applied to one invocation.
  final Duration timeout;

  /// Presentation seam; the package surface is used when absent.
  @visibleForTesting
  final Future<ShareResult> Function(ShareParams params)? present;

  @override
  Future<LibraryShareOutcome> shareText(String text, {Rect? anchor}) async {
    final invoke = present ?? SharePlus.instance.share;
    try {
      final result = await invoke(
        ShareParams(text: text, sharePositionOrigin: anchor),
      ).timeout(timeout);
      return switch (result.status) {
        ShareResultStatus.success => LibraryShareOutcome.selected,
        ShareResultStatus.dismissed => LibraryShareOutcome.dismissed,
        ShareResultStatus.unavailable => LibraryShareOutcome.selected,
      };
    } on MissingPluginException {
      return LibraryShareOutcome.unavailable;
    } on Object {
      // Activity and invocation errors stay inside the boundary.
      return LibraryShareOutcome.invocationFailure;
    }
  }
}

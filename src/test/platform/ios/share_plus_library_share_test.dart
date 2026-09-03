import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/library/presentation/library_share.dart';
import 'package:prompt_library/src/platform/ios/share_plus_library_share.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('passes the exact text and anchor to the system surface', () async {
    final captured = <ShareParams>[];
    final share = SharePlusLibraryShare(
      present: (params) async {
        captured.add(params);
        return const ShareResult('', ShareResultStatus.success);
      },
    );

    const anchor = Rect.fromLTWH(16, 194, 370, 48);
    await share.shareText('exact body', anchor: anchor);

    expect(captured.single.text, 'exact body');
    expect(captured.single.sharePositionOrigin, anchor);
  });

  test('maps a selected activity to selected', () async {
    final share = SharePlusLibraryShare(
      present: (_) async => const ShareResult(
        'com.apple.UIKit.activity.AirDrop',
        ShareResultStatus.success,
      ),
    );

    expect(await share.shareText('body'), LibraryShareOutcome.selected);
  });

  test('maps a dismissal to dismissed', () async {
    final share = SharePlusLibraryShare(
      present: (_) async => const ShareResult('', ShareResultStatus.dismissed),
    );

    expect(await share.shareText('body'), LibraryShareOutcome.dismissed);
  });

  test('maps an indeterminate platform report to selected', () async {
    final share = SharePlusLibraryShare(
      present: (_) async =>
          const ShareResult('', ShareResultStatus.unavailable),
    );

    expect(await share.shareText('body'), LibraryShareOutcome.selected);
  });

  test('maps a missing channel implementation to unavailable', () async {
    final share = SharePlusLibraryShare(
      present: (_) async => throw MissingPluginException('no implementation'),
    );

    expect(await share.shareText('body'), LibraryShareOutcome.unavailable);
  });

  test('maps an invocation error to invocationFailure', () async {
    final share = SharePlusLibraryShare(
      present: (_) async => throw PlatformException(code: 'error'),
    );

    expect(
      await share.shareText('body'),
      LibraryShareOutcome.invocationFailure,
    );
  });

  test('keeps the underlying activity error inside the boundary', () async {
    final share = SharePlusLibraryShare(
      present: (_) async => throw StateError('secret activity failure'),
    );

    await expectLater(share.shareText('body'), completes);
    expect(
      await share.shareText('body'),
      LibraryShareOutcome.invocationFailure,
    );
  });

  test(
    'completes within the declared bound when the sheet never reports',
    () async {
      final never = Completer<ShareResult>();
      addTearDown(
        () =>
            never.complete(const ShareResult('', ShareResultStatus.dismissed)),
      );
      final share = SharePlusLibraryShare(
        present: (_) => never.future,
        timeout: const Duration(milliseconds: 30),
      );

      expect(
        await share.shareText('body'),
        LibraryShareOutcome.invocationFailure,
      );
    },
  );

  test('declares a bound far above measured interaction time', () {
    expect(
      SharePlusLibraryShare.defaultTimeout,
      greaterThan(const Duration(seconds: 30)),
    );
  });
}

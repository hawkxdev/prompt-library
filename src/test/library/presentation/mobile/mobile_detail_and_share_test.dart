/// Mobile detail action tests.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/app/application_surface.dart';
import 'package:prompt_library/src/app/prompt_library_app.dart';
import 'package:prompt_library/src/library/models/library_failure.dart';
import 'package:prompt_library/src/library/models/library_snapshot.dart';
import 'package:prompt_library/src/library/presentation/library_clipboard.dart';
import 'package:prompt_library/src/library/presentation/library_controller.dart';
import 'package:prompt_library/src/library/presentation/library_failure_message.dart';
import 'package:prompt_library/src/library/presentation/library_haptics.dart';
import 'package:prompt_library/src/library/presentation/library_share.dart';
import 'package:prompt_library/src/library/presentation/mobile/mobile_entry_detail_screen.dart';
import 'package:prompt_library/src/library/presentation/mobile/mobile_library_screen.dart';

import '../../../support/library_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reports system sharing as unavailable without an adapter', () async {
    expect(
      await const UnavailableLibraryShare().shareText('body'),
      LibraryShareOutcome.unavailable,
    );
  });

  test(
    'sends selection feedback through the Flutter platform channel',
    () async {
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await const FlutterLibraryHaptics().selectionFeedback();

      expect(calls, hasLength(1));
      expect(calls.single.method, 'HapticFeedback.vibrate');
      expect(calls.single.arguments, 'HapticFeedbackType.selectionClick');
    },
  );

  test('absorbs a platform haptic failure', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      throw PlatformException(code: 'unavailable');
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await expectLater(
      const FlutterLibraryHaptics().selectionFeedback(),
      completes,
    );
  });

  late TestLibraryRepository repository;
  late LibraryController controller;

  setUp(() {
    repository = TestLibraryRepository();
    controller = LibraryController(repository: repository);
  });

  tearDown(() async {
    await controller.dispose();
    await repository.close();
  });

  Future<void> pumpState(WidgetTester tester) async {
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump(const Duration(milliseconds: 150));
  }

  Future<void> pumpDetail(
    WidgetTester tester, {
    String title = 'Private title',
    String body = 'Private body',
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      PromptLibraryApp(
        applicationSurface: ApplicationSurface.mobile,
        controller: controller,
        clipboard: const _NoopClipboard(),
      ),
    );
    repository.emit(
      LibrarySnapshot(
        entries: [testEntry('entry-1', title: title, body: body)],
      ),
    );
    await pumpState(tester);
    await tester.tap(find.byKey(const Key('mobile-entry-disclosure-entry-1')));
    await pumpState(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(MobileEntryDetailScreen), findsOneWidget);
  }

  Future<void> pumpNestedDetail(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          key: const Key('route-sentinel'),
          body: Builder(
            builder: (context) => FilledButton(
              key: const Key('open-mobile-library'),
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => MobileLibraryScreen(
                    controller: controller,
                    clipboard: const _NoopClipboard(),
                    share: const UnavailableLibraryShare(),
                    haptics: const FlutterLibraryHaptics(),
                  ),
                ),
              ),
              child: const Text('Open library'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-mobile-library')));
    await tester.pump(const Duration(milliseconds: 400));
    repository.emit(
      LibrarySnapshot(
        entries: [
          testEntry('entry-1', title: 'Private title', body: 'Private body'),
          testEntry('entry-2', title: 'Remaining prompt'),
        ],
      ),
    );
    await pumpState(tester);
    await tester.tap(find.byKey(const Key('mobile-entry-disclosure-entry-1')));
    await pumpState(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(MobileEntryDetailScreen), findsOneWidget);
  }

  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  }

  Future<void> pumpUntilAbsent(WidgetTester tester, Finder finder) async {
    for (var attempt = 0; attempt < 20; attempt++) {
      if (finder.evaluate().isEmpty) {
        return;
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('toggles favorite once and updates the action label', (
    tester,
  ) async {
    await pumpDetail(tester);

    final favorite = find.byKey(const Key('mobile-detail-favorite'));
    expect(tester.widget<IconButton>(favorite).tooltip, 'Add to favorites');

    await tester.tap(favorite);
    await pumpState(tester);

    expect(repository.calls, contains('setFavorite:entry-1:true'));
    expect(
      repository.calls.where((call) => call == 'setFavorite:entry-1:true'),
      hasLength(1),
    );
    expect(
      tester.widget<IconButton>(favorite).tooltip,
      'Remove from favorites',
    );
    await disposeApp(tester);
  });

  testWidgets('disables favorite while its mutation is in flight', (
    tester,
  ) async {
    await pumpDetail(tester);
    final gate = Completer<void>();
    repository.nextMutationGate = gate;
    final favorite = find.byKey(const Key('mobile-detail-favorite'));

    await tester.tap(favorite);
    await tester.pump();

    expect(tester.widget<IconButton>(favorite).onPressed, isNull);
    await tester.tap(favorite, warnIfMissed: false);
    await tester.pump();
    expect(
      repository.calls.where((call) => call == 'setFavorite:entry-1:true'),
      hasLength(1),
    );

    gate.complete();
    await pumpState(tester);
    await disposeApp(tester);
  });

  testWidgets('archives the entry without closing its detail route', (
    tester,
  ) async {
    await pumpDetail(tester);

    await tester.tap(find.byKey(const Key('mobile-detail-archive')));
    await pumpState(tester);

    expect(repository.calls, contains('setArchived:entry-1:true'));
    expect(controller.state.visibleEntries, isEmpty);
    expect(find.byType(MobileEntryDetailScreen), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('mobile-detail-archive')))
          .tooltip,
      'Restore',
    );
    await disposeApp(tester);
  });

  testWidgets('shows and dismisses a non-sensitive mutation failure', (
    tester,
  ) async {
    const failure = DatabaseFailureLibraryFailure(
      code: LibraryDatabaseFailureCode.transactionFailed,
    );
    const title = 'Private title';
    const body = 'Private body';
    await pumpDetail(tester, title: title, body: body);
    repository.nextFailure = failure;

    await tester.tap(find.byKey(const Key('mobile-detail-favorite')));
    await pumpState(tester);

    final banner = find.byKey(const Key('mobile-detail-failure-banner'));
    expect(banner, findsOneWidget);
    expect(find.text(messageForLibraryFailure(failure)), findsOneWidget);
    expect(
      find.descendant(of: banner, matching: find.text(title)),
      findsNothing,
    );
    expect(
      find.descendant(of: banner, matching: find.text(body)),
      findsNothing,
    );

    await tester.tap(find.widgetWithText(TextButton, 'Dismiss'));
    await pumpState(tester);

    expect(banner, findsNothing);
    await disposeApp(tester);
  });

  testWidgets('cancels deletion without calling the repository', (
    tester,
  ) async {
    await pumpDetail(tester);
    await tester.tap(find.byKey(const Key('mobile-detail-copy')));
    await pumpState(tester);
    expect(
      repository.calls,
      isNotEmpty,
      reason: 'positive control: the recorder observes real mutations',
    );

    await tester.tap(find.byKey(const Key('mobile-detail-delete')));
    await tester.pump();

    expect(find.text('Delete prompt?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      repository.calls.where((call) => call == 'deleteEntry:entry-1'),
      isEmpty,
    );
    expect(find.byType(MobileEntryDetailScreen), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('confirms deletion and returns to the mobile list', (
    tester,
  ) async {
    await pumpDetail(tester);
    repository.emit(
      LibrarySnapshot(
        entries: [
          testEntry('entry-1', title: 'Private title', body: 'Private body'),
          testEntry('entry-2', title: 'Remaining prompt'),
        ],
      ),
    );
    await pumpState(tester);

    await tester.tap(find.byKey(const Key('mobile-detail-delete')));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await pumpState(tester);
    await pumpUntilAbsent(tester, find.byType(MobileEntryDetailScreen));

    expect(
      repository.calls.where((call) => call == 'deleteEntry:entry-1'),
      hasLength(1),
    );
    expect(find.byType(MobileEntryDetailScreen), findsNothing);
    expect(find.byKey(const Key('mobile-library-list')), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('closes only the detail route across repeated delete states', (
    tester,
  ) async {
    await pumpNestedDetail(tester);
    final gate = Completer<void>();
    repository.nextMutationGate = gate;

    await tester.tap(find.byKey(const Key('mobile-detail-delete')));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pump();
    gate.complete();
    await pumpState(tester);
    final remaining = LibrarySnapshot(
      entries: [testEntry('entry-2', title: 'Remaining prompt')],
    );
    repository.emit(remaining);
    await tester.pump(const Duration(milliseconds: 100));
    repository.emit(remaining);
    await tester.pump(const Duration(milliseconds: 100));
    await pumpUntilAbsent(tester, find.byType(MobileEntryDetailScreen));

    expect(find.byType(MobileEntryDetailScreen), findsNothing);
    expect(find.byKey(const Key('mobile-library-search')), findsOneWidget);
    expect(find.byKey(const Key('mobile-library-list')), findsOneWidget);
    expect(find.byKey(const Key('route-sentinel')), findsNothing);
    await disposeApp(tester);
  });
}

/// Ignores clipboard writes.
final class _NoopClipboard implements LibraryClipboard {
  const _NoopClipboard();

  @override
  Future<void> writeText(String text) async {}
}

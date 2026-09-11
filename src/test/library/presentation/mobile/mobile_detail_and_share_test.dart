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
import 'package:prompt_library/src/library/presentation/library_state.dart';
import 'package:prompt_library/src/library/presentation/mobile/mobile_entry_detail_screen.dart';
import 'package:prompt_library/src/library/presentation/mobile/mobile_library_actions.dart';
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
  late _RecordingShare share;

  setUp(() {
    repository = TestLibraryRepository();
    controller = LibraryController(repository: repository);
    share = _RecordingShare();
  });

  tearDown(() async {
    await controller.dispose();
    await repository.close();
  });

  test(
    'coalesces concurrent mutations and tracks pending per action kind',
    () async {
      final entry = testEntry('entry-actions-1', title: 'Prompt 1');
      final actions = MobileLibraryActions(
        controller: controller,
        clipboard: const _NoopClipboard(),
        share: share,
        haptics: const _NoopHaptics(),
      );

      final gate = Completer<void>();
      repository.nextMutationGate = gate;

      final first = actions.setFavorite(entry);
      expect(
        actions.isActionPending(entry.id, LibraryMutationKind.setFavorite),
        isTrue,
      );

      final second = actions.setFavorite(entry);
      expect(identical(first, second), isTrue);

      gate.complete();
      await first;

      expect(
        actions.isActionPending(entry.id, LibraryMutationKind.setFavorite),
        isFalse,
      );
      expect(repository.calls, contains('setFavorite:entry-actions-1:true'));
    },
  );

  test('absorbs LibraryFailure in mobile entry mutations', () async {
    final entry = testEntry('entry-actions-fail', title: 'Prompt Fail');
    final actions = MobileLibraryActions(
      controller: controller,
      clipboard: const _NoopClipboard(),
      share: share,
      haptics: const _NoopHaptics(),
    );

    repository.nextFailure = const DatabaseFailureLibraryFailure(
      code: LibraryDatabaseFailureCode.transactionFailed,
    );

    await expectLater(actions.setFavorite(entry), completes);
    expect(controller.state.failure, isNotNull);
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
        share: share,
        haptics: const _NoopHaptics(),
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
                    haptics: const _NoopHaptics(),
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

  testWidgets('edits the entry and keeps the detail route open', (
    tester,
  ) async {
    await pumpDetail(tester, title: 'Old title', body: 'Old body');

    await tester.tap(find.byKey(const Key('mobile-detail-edit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mobile-entry-editor-screen')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('editor-title')),
      'Updated title',
    );
    await tester.enterText(
      find.byKey(const Key('editor-body')),
      'Updated body',
    );
    await tester.tap(find.byKey(const Key('mobile-editor-save')));
    await pumpState(tester);
    await tester.pumpAndSettle();

    expect(repository.calls, contains('updateEntryDetails:entry-1'));
    expect(find.byKey(const Key('mobile-entry-editor-screen')), findsNothing);
    expect(find.byType(MobileEntryDetailScreen), findsOneWidget);
    expect(find.text('Updated title'), findsOneWidget);
    expect(find.text('Updated body'), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('disables archive while its mutation is in flight', (
    tester,
  ) async {
    await pumpDetail(tester);
    final gate = Completer<void>();
    repository.nextMutationGate = gate;
    final archive = find.byKey(const Key('mobile-detail-archive'));

    await tester.tap(archive);
    await tester.pump();

    expect(tester.widget<IconButton>(archive).onPressed, isNull);
    gate.complete();
    await pumpState(tester);
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

  testWidgets('disables delete while its mutation is in flight', (
    tester,
  ) async {
    await pumpDetail(tester);
    final gate = Completer<void>();
    repository.nextMutationGate = gate;
    final delete = find.byKey(const Key('mobile-detail-delete'));

    await tester.tap(delete);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pump();

    expect(tester.widget<IconButton>(delete).onPressed, isNull);
    gate.complete();
    await pumpState(tester);
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
    repository.emit(
      LibrarySnapshot(
        entries: [testEntry('entry-2', title: 'Remaining prompt')],
      ),
    );
    await pumpState(tester);
    await tester.pump(const Duration(milliseconds: 16));
    repository.emit(
      LibrarySnapshot(
        entries: [
          testEntry('entry-2', title: 'Remaining prompt'),
          testEntry('entry-3', title: 'Third prompt'),
        ],
      ),
    );
    await pumpState(tester);
    await pumpUntilAbsent(tester, find.byType(MobileEntryDetailScreen));

    expect(find.byType(MobileEntryDetailScreen), findsNothing);
    expect(find.byKey(const Key('mobile-library-search')), findsOneWidget);
    expect(find.byKey(const Key('mobile-library-list')), findsOneWidget);
    expect(find.byKey(const Key('route-sentinel')), findsNothing);
    await disposeApp(tester);
  });

  testWidgets('shares the exact entry body without normalizing whitespace', (
    tester,
  ) async {
    const body = '  leading\nand trailing  ';
    await pumpDetail(tester, body: body);

    await tester.tap(find.byKey(const Key('mobile-detail-share')));
    await pumpState(tester);

    expect(share.invocations, hasLength(1));
    expect(_escape(share.invocations.single.text), _escape(body));
    await disposeApp(tester);
  });

  testWidgets('anchors sharing to the global share button geometry', (
    tester,
  ) async {
    await pumpDetail(tester);
    final button = find.byKey(const Key('mobile-detail-share'));
    final expected = tester.getTopLeft(button) & tester.getSize(button);

    await tester.tap(button);
    await pumpState(tester);

    final anchor = share.invocations.single.anchor;
    expect(anchor, isNotNull);
    expect(anchor!.isEmpty, isFalse);
    expect(anchor, expected);
    await disposeApp(tester);
  });

  testWidgets('joins rapid share taps into one invocation and one message', (
    tester,
  ) async {
    share.outcome = LibraryShareOutcome.unavailable;
    final gate = Completer<void>();
    share.gate = gate;
    await pumpDetail(tester);
    final button = find.byKey(const Key('mobile-detail-share'));

    await tester.tap(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();

    expect(share.invocations, hasLength(1));
    gate.complete();
    await pumpState(tester);

    expect(
      find.text('Sharing is not available on this device.'),
      findsOneWidget,
    );
    await disposeApp(tester);
  });

  testWidgets('shows progress while a share invocation is pending', (
    tester,
  ) async {
    final gate = Completer<void>();
    share.gate = gate;
    await pumpDetail(tester);
    final button = find.byKey(const Key('mobile-detail-share'));

    await tester.tap(button);
    await tester.pump();

    expect(
      find.descendant(
        of: button,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: button, matching: find.byIcon(Icons.share_outlined)),
      findsNothing,
    );

    gate.complete();
    await pumpState(tester);

    expect(
      find.descendant(
        of: button,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: button, matching: find.byIcon(Icons.share_outlined)),
      findsOneWidget,
    );
    await disposeApp(tester);
  });

  testWidgets('maps an asynchronous share error to invocation failure', (
    tester,
  ) async {
    share.nextError = StateError('share adapter failed');
    final gate = Completer<void>();
    share.gate = gate;
    await pumpDetail(tester);

    await tester.tap(find.byKey(const Key('mobile-detail-share')));
    await tester.pump();
    expect(share.invocations, hasLength(1));
    gate.complete();
    await pumpState(tester);

    expect(find.text('The prompt could not be shared.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await disposeApp(tester);
  });

  for (final scenario in <({LibraryShareOutcome outcome, String? message})>[
    (outcome: LibraryShareOutcome.dismissed, message: null),
    (
      outcome: LibraryShareOutcome.unavailable,
      message: 'Sharing is not available on this device.',
    ),
    (
      outcome: LibraryShareOutcome.invocationFailure,
      message: 'The prompt could not be shared.',
    ),
    (outcome: LibraryShareOutcome.selected, message: null),
  ]) {
    testWidgets('maps ${scenario.outcome.name} to honest share feedback', (
      tester,
    ) async {
      share.outcome = scenario.outcome;
      await pumpDetail(tester);

      await tester.tap(find.byKey(const Key('mobile-detail-share')));
      await pumpState(tester);

      if (scenario.message case final message?) {
        expect(find.text(message), findsOneWidget);
      } else {
        expect(find.byType(SnackBar), findsNothing);
      }
      expect(find.textContaining('Shared'), findsNothing);
      expect(find.textContaining('Sent'), findsNothing);
      await disposeApp(tester);
    });
  }

  testWidgets('keeps share accessible with doubled text scale', (tester) async {
    final semantics = tester.ensureSemantics();
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpDetail(tester);

    final shareButton = find.byKey(const Key('mobile-detail-share'));
    final copyButton = find.byKey(const Key('mobile-detail-copy'));
    expect(tester.getSize(shareButton).height, greaterThanOrEqualTo(48));
    expect(
      tester.getSemantics(shareButton).label,
      isNot(tester.getSemantics(copyButton).label),
    );
    expect(tester.takeException(), isNull);

    semantics.dispose();
    await disposeApp(tester);
  });
}

/// Renders whitespace visibly for failure reports.
String _escape(String value) {
  return value.replaceAll(' ', '<sp>').replaceAll('\n', '<nl>');
}

/// Ignores clipboard writes.
final class _NoopClipboard implements LibraryClipboard {
  const _NoopClipboard();

  @override
  Future<void> writeText(String text) async {}
}

/// Ignores tactile feedback requests.
final class _NoopHaptics implements LibraryHaptics {
  /// Creates no-op haptics.
  const _NoopHaptics();

  @override
  Future<void> selectionFeedback() async {}
}

/// Records exact system sharing calls.
final class _RecordingShare implements LibraryShare {
  /// Recorded share invocations.
  final List<({String text, Rect? anchor})> invocations = [];

  /// Result returned by each invocation.
  LibraryShareOutcome outcome = LibraryShareOutcome.dismissed;

  /// Optional completion gate.
  Completer<void>? gate;

  /// Throwable raised after the asynchronous boundary.
  Object? nextError;

  @override
  Future<LibraryShareOutcome> shareText(String text, {Rect? anchor}) async {
    invocations.add((text: text, anchor: anchor));
    await gate?.future;
    final error = nextError;
    nextError = null;
    if (error != null) {
      throw error;
    }
    return outcome;
  }
}

/// Mobile detail action tests.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/app/application_surface.dart';
import 'package:prompt_library/src/app/prompt_library_app.dart';
import 'package:prompt_library/src/library/models/library_failure.dart';
import 'package:prompt_library/src/library/models/library_snapshot.dart';
import 'package:prompt_library/src/library/presentation/library_clipboard.dart';
import 'package:prompt_library/src/library/presentation/library_controller.dart';
import 'package:prompt_library/src/library/presentation/library_failure_message.dart';
import 'package:prompt_library/src/library/presentation/mobile/mobile_entry_detail_screen.dart';

import '../../../support/library_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
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
}

/// Ignores clipboard writes.
final class _NoopClipboard implements LibraryClipboard {
  const _NoopClipboard();

  @override
  Future<void> writeText(String text) async {}
}

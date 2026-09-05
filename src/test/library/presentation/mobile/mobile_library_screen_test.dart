/// Mobile retrieval widget tests.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/app/application_surface.dart';
import 'package:prompt_library/src/app/prompt_library_app.dart';
import 'package:prompt_library/src/library/models/library_failure.dart';
import 'package:prompt_library/src/library/models/library_snapshot.dart';
import 'package:prompt_library/src/library/presentation/library_clipboard.dart';
import 'package:prompt_library/src/library/presentation/library_controller.dart';
import 'package:prompt_library/src/library/presentation/library_filter.dart';
import 'package:prompt_library/src/library/presentation/library_haptics.dart';
import 'package:prompt_library/src/library/presentation/library_share.dart';
import 'package:prompt_library/src/library/presentation/mobile/mobile_entry_detail_screen.dart';
import 'package:prompt_library/src/library/presentation/mobile/mobile_library_actions.dart';

import '../../../support/library_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestLibraryRepository repository;
  late LibraryController controller;
  late _RecordingClipboard clipboard;
  late _RecordingHaptics haptics;
  late MobileLibraryActions actions;

  setUp(() {
    repository = TestLibraryRepository();
    controller = LibraryController(repository: repository);
    clipboard = _RecordingClipboard();
    haptics = _RecordingHaptics();
    actions = MobileLibraryActions(
      controller: controller,
      clipboard: clipboard,
      share: const UnavailableLibraryShare(),
      haptics: haptics,
    );
  });

  tearDown(() async {
    await controller.dispose();
    await repository.close();
  });

  int markCopiedCalls(String id) {
    return repository.calls.where((call) => call == 'markCopied:$id').length;
  }

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      PromptLibraryApp(
        applicationSurface: ApplicationSurface.mobile,
        controller: controller,
        clipboard: clipboard,
        haptics: haptics,
      ),
    );
  }

  Future<void> pumpState(WidgetTester tester) async {
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump(const Duration(milliseconds: 150));
  }

  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  }

  Future<void> openDetail(WidgetTester tester, String entryId) async {
    await tester.tap(find.byKey(Key('mobile-entry-disclosure-$entryId')));
    await pumpState(tester);
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pumpUntilAbsent(WidgetTester tester, Finder finder) async {
    for (var attempt = 0; attempt < 20; attempt++) {
      if (finder.evaluate().isEmpty) {
        return;
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openFilters(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('mobile-filter-button')));
    await pumpState(tester);
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> closeFilters(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('mobile-filter-done')));
    await pumpState(tester);
    await pumpUntilAbsent(tester, find.byKey(const Key('mobile-filter-done')));
  }

  group('MobileLibraryActions', () {
    test('joins duplicate taps into one copy cycle', () async {
      final entry = testEntry('one', body: 'exact body');
      repository.emit(LibrarySnapshot(entries: [entry]));
      final gate = Completer<void>();
      clipboard.gate = gate;

      final first = actions.copyEntry(entry);
      final second = actions.copyEntry(entry);
      expect(actions.isPending('one'), isTrue);

      clipboard.gate = null;
      gate.complete();

      expect(await first, MobileCopyOutcome.copied);
      expect(await second, isNull);
      expect(clipboard.writes, ['exact body']);
      expect(markCopiedCalls('one'), 1);
      expect(haptics.calls, 1);
      expect(actions.isPending('one'), isFalse);
    });

    test('starts a new cycle after the previous one completed', () async {
      final entry = testEntry('one');
      repository.emit(LibrarySnapshot(entries: [entry]));

      expect(await actions.copyEntry(entry), MobileCopyOutcome.copied);
      expect(await actions.copyEntry(entry), MobileCopyOutcome.copied);

      expect(clipboard.writes, hasLength(2));
      expect(markCopiedCalls('one'), 2);
      expect(haptics.calls, 2);
    });

    test('runs independent cycles for different entries', () async {
      final first = testEntry('one');
      final second = testEntry('two');
      repository.emit(LibrarySnapshot(entries: [first, second]));
      final gate = Completer<void>();
      clipboard.gate = gate;

      final firstCycle = actions.copyEntry(first);
      final secondCycle = actions.copyEntry(second);
      expect(actions.isPending('one'), isTrue);
      expect(actions.isPending('two'), isTrue);

      clipboard.gate = null;
      gate.complete();

      expect(await firstCycle, MobileCopyOutcome.copied);
      expect(await secondCycle, MobileCopyOutcome.copied);
      expect(markCopiedCalls('one'), 1);
      expect(markCopiedCalls('two'), 1);
    });

    test('reports clipboard failure without metadata or haptic', () async {
      final entry = testEntry('one');
      repository.emit(LibrarySnapshot(entries: [entry]));
      clipboard.nextError = const LibraryClipboardFailure();

      expect(
        await actions.copyEntry(entry),
        MobileCopyOutcome.clipboardFailure,
      );

      expect(clipboard.writes, isEmpty);
      expect(markCopiedCalls('one'), 0);
      expect(haptics.calls, 0);
      expect(actions.isPending('one'), isFalse);
    });

    test('keeps the copy authoritative when haptic feedback fails', () async {
      final entry = testEntry('one', body: 'exact body');
      repository.emit(LibrarySnapshot(entries: [entry]));
      haptics.nextError = StateError('haptic adapter failed');

      expect(await actions.copyEntry(entry), MobileCopyOutcome.copied);

      expect(clipboard.writes, ['exact body']);
      expect(haptics.calls, 1);
      expect(markCopiedCalls('one'), 1);
    });

    test('releases the guard after an unexpected error', () async {
      final entry = testEntry('one');
      repository.emit(LibrarySnapshot(entries: [entry]));
      clipboard.nextError = StateError('clipboard adapter failed');

      await expectLater(actions.copyEntry(entry), throwsStateError);
      expect(actions.isPending('one'), isFalse);

      expect(await actions.copyEntry(entry), MobileCopyOutcome.copied);
      expect(markCopiedCalls('one'), 1);
    });

    test(
      'releases the share guard after a synchronous adapter error',
      () async {
        final entry = testEntry('one');
        final throwingActions = MobileLibraryActions(
          controller: controller,
          clipboard: clipboard,
          share: const _SynchronouslyThrowingShare(),
          haptics: haptics,
        );

        expect(
          await throwingActions.shareEntry(entry),
          LibraryShareOutcome.invocationFailure,
        );

        expect(throwingActions.isSharePending('one'), isFalse);
      },
    );
  });

  // === Observable state surfaces ===

  testWidgets('renders loading before the first snapshot', (tester) async {
    await pumpApp(tester);

    expect(find.byKey(const Key('mobile-library-loading')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('mobile-library-search')), findsNothing);
    await disposeApp(tester);
  });

  testWidgets('renders the mobile empty library with a create action', (
    tester,
  ) async {
    await pumpApp(tester);
    repository.emit(const LibrarySnapshot.empty());
    await pumpState(tester);

    expect(find.byKey(const Key('mobile-library-search')), findsOneWidget);
    expect(find.byKey(const Key('mobile-empty-state')), findsOneWidget);
    expect(find.text('Your library is empty'), findsOneWidget);
    expect(find.byKey(const Key('mobile-create-entry')), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('opens the create editor from the mobile list', (tester) async {
    await pumpApp(tester);
    repository.emit(const LibrarySnapshot.empty());
    await pumpState(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-create-entry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-entry-editor-screen')), findsOneWidget);
    expect(find.text('New prompt'), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('separates a filtered empty result from an empty library', (
    tester,
  ) async {
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(entries: [testEntry('one', title: 'Alpha')]),
    );
    await pumpState(tester);
    expect(find.text('Alpha'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('mobile-library-search')),
      'zzz',
    );
    await pumpState(tester);

    expect(find.text('No matching prompts'), findsOneWidget);
    expect(find.text('Your library is empty'), findsNothing);
    await disposeApp(tester);
  });

  testWidgets('renders the initial failure surface without a snapshot', (
    tester,
  ) async {
    await pumpApp(tester);
    repository.emitFailure(
      const DatabaseFailureLibraryFailure(
        code: LibraryDatabaseFailureCode.readFailed,
      ),
    );
    await pumpState(tester);

    expect(find.byKey(const Key('mobile-initial-failure')), findsOneWidget);
    expect(
      find.text('The library could not save this change.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('mobile-library-search')), findsNothing);
    await disposeApp(tester);
  });

  testWidgets('retains a dismissible failure banner over a usable snapshot', (
    tester,
  ) async {
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(entries: [testEntry('one', title: 'Alpha')]),
    );
    await pumpState(tester);
    repository.emitFailure(
      const DatabaseFailureLibraryFailure(
        code: LibraryDatabaseFailureCode.readFailed,
      ),
    );
    await pumpState(tester);

    expect(find.byKey(const Key('mobile-library-search')), findsOneWidget);
    expect(find.byType(MaterialBanner), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Dismiss'));
    await pumpState(tester);

    expect(find.byType(MaterialBanner), findsNothing);
    expect(find.text('Alpha'), findsOneWidget);
    await disposeApp(tester);
  });

  // === Search ===

  testWidgets('searches the shared controller filter', (tester) async {
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(
        entries: [
          testEntry('one', title: 'Alpha prompt'),
          testEntry('two', title: 'Bravo prompt'),
        ],
      ),
    );
    await pumpState(tester);
    expect(find.text('Alpha prompt'), findsOneWidget);
    expect(find.text('Bravo prompt'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('mobile-library-search')),
      'bravo',
    );
    await pumpState(tester);

    expect(controller.state.filter.searchQuery, 'bravo');
    expect(find.text('Alpha prompt'), findsNothing);
    expect(find.text('Bravo prompt'), findsOneWidget);
    await disposeApp(tester);
  });

  // === Search focus dismissal ===

  testWidgets('clears search focus when the free list area is tapped', (
    tester,
  ) async {
    await _withIosPlatform(() async {
      await pumpApp(tester);
      repository.emit(
        LibrarySnapshot(entries: [testEntry('one', title: 'Alpha')]),
      );
      await pumpState(tester);

      await tester.showKeyboard(find.byKey(const Key('mobile-library-search')));
      await pumpState(tester);
      expect(_searchHasFocus(tester), isTrue);

      await tester.tapAt(const Offset(100, 700));
      await pumpState(tester);

      expect(_searchHasFocus(tester), isFalse);
      await disposeApp(tester);
    });
  });

  testWidgets('copies the row and clears search focus on the same tap', (
    tester,
  ) async {
    const body = 'exact body';
    await _withIosPlatform(() async {
      await pumpApp(tester);
      repository.emit(
        LibrarySnapshot(
          entries: [testEntry('one', title: 'Alpha', body: body)],
        ),
      );
      await pumpState(tester);

      await tester.showKeyboard(find.byKey(const Key('mobile-library-search')));
      await pumpState(tester);
      expect(_searchHasFocus(tester), isTrue);

      await tester.tap(find.byKey(const Key('mobile-entry-one')));
      await pumpState(tester);

      expect(clipboard.writes, [body]);
      expect(markCopiedCalls('one'), 1);
      expect(_searchHasFocus(tester), isFalse);
      await disposeApp(tester);
    });
  });

  testWidgets('keeps the disclosure working while search focus is active', (
    tester,
  ) async {
    await _withIosPlatform(() async {
      await pumpApp(tester);
      repository.emit(
        LibrarySnapshot(entries: [testEntry('one', title: 'Alpha')]),
      );
      await pumpState(tester);

      await tester.showKeyboard(find.byKey(const Key('mobile-library-search')));
      await pumpState(tester);
      expect(_searchHasFocus(tester), isTrue);

      await openDetail(tester, 'one');

      expect(find.byType(MobileEntryDetailScreen), findsOneWidget);
      await disposeApp(tester);
    });
  });

  // === One-tap retrieval ===

  testWidgets('copies the exact body on a single row tap', (tester) async {
    const body = '  leading\nand trailing  ';
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(
        entries: [testEntry('one', title: 'Alpha', body: body)],
      ),
    );
    await pumpState(tester);

    await tester.tap(find.byKey(const Key('mobile-entry-one')));
    await pumpState(tester);

    expect(clipboard.writes, hasLength(1));
    expect(_escape(clipboard.writes.single), _escape(body));
    expect(markCopiedCalls('one'), 1);
    expect(find.text('Copied'), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('joins duplicate row taps and restarts after completion', (
    tester,
  ) async {
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(entries: [testEntry('one', title: 'Alpha')]),
    );
    await pumpState(tester);

    final gate = Completer<void>();
    clipboard.gate = gate;
    await tester.tap(find.byKey(const Key('mobile-entry-one')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-entry-one')));
    await tester.pump();

    clipboard.gate = null;
    gate.complete();
    await pumpState(tester);

    expect(clipboard.writes, hasLength(1));
    expect(markCopiedCalls('one'), 1);
    expect(find.text('Copied'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mobile-entry-one')));
    await pumpState(tester);

    expect(clipboard.writes, hasLength(2));
    expect(markCopiedCalls('one'), 2);
    await disposeApp(tester);
  });

  testWidgets('marks the pending row without a second side effect', (
    tester,
  ) async {
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(entries: [testEntry('one', title: 'Alpha')]),
    );
    await pumpState(tester);
    expect(_rowHint(tester, 'one'), 'Copy prompt');

    final gate = Completer<void>();
    clipboard.gate = gate;
    await tester.tap(find.byKey(const Key('mobile-entry-one')));
    await tester.pump();

    expect(_rowHint(tester, 'one'), 'Copying');
    expect(
      find.descendant(
        of: find.byKey(const Key('mobile-entry-one')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );

    clipboard.gate = null;
    gate.complete();
    await pumpState(tester);

    expect(_rowHint(tester, 'one'), 'Copy prompt');
    await disposeApp(tester);
  });

  testWidgets('reports a clipboard failure without copy feedback', (
    tester,
  ) async {
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(entries: [testEntry('one', title: 'Alpha')]),
    );
    await pumpState(tester);
    clipboard.nextError = const LibraryClipboardFailure();

    await tester.tap(find.byKey(const Key('mobile-entry-one')));
    await pumpState(tester);

    expect(find.text('The prompt could not be copied.'), findsOneWidget);
    expect(find.text('Copied'), findsNothing);
    expect(markCopiedCalls('one'), 0);
    await disposeApp(tester);
  });

  testWidgets('reorders the list from the shared controller after a copy', (
    tester,
  ) async {
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(
        entries: [
          testEntry('one', title: 'Alpha'),
          testEntry('two', title: 'Bravo'),
        ],
      ),
    );
    await pumpState(tester);
    expect(_visibleTitles(tester), ['Alpha', 'Bravo']);

    await tester.tap(find.byKey(const Key('mobile-entry-two')));
    await pumpState(tester);

    expect(_visibleTitles(tester), ['Bravo', 'Alpha']);
    await disposeApp(tester);
  });

  // === Detail route and disclosure ===

  testWidgets('opens the detail route from the separate disclosure', (
    tester,
  ) async {
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(
        entries: [
          testEntry(
            'one',
            title: 'Alpha',
            body: 'exact detail body',
            categoryId: 'category-1',
            tagIds: const ['tag-1'],
          ),
        ],
        categories: [testCategory('category-1', 'Agents')],
        tags: [testTag('tag-1', 'research')],
      ),
    );
    await pumpState(tester);

    await openDetail(tester, 'one');

    expect(find.byType(MobileEntryDetailScreen), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(MobileEntryDetailScreen),
        matching: find.text('Alpha'),
      ),
      findsOneWidget,
    );
    expect(find.text('exact detail body'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'Agents'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'research'), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('never combines copying and navigation in one target', (
    tester,
  ) async {
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(entries: [testEntry('one', title: 'Alpha')]),
    );
    await pumpState(tester);

    await tester.tap(find.byKey(const Key('mobile-entry-one')));
    await pumpState(tester);
    expect(find.byType(MobileEntryDetailScreen), findsNothing);
    expect(clipboard.writes, hasLength(1));

    await openDetail(tester, 'one');
    expect(find.byType(MobileEntryDetailScreen), findsOneWidget);
    expect(clipboard.writes, hasLength(1));
    expect(markCopiedCalls('one'), 1);
    await disposeApp(tester);
  });

  testWidgets('gives both row targets reachable size and distinct labels', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(entries: [testEntry('one', title: 'Alpha')]),
    );
    await pumpState(tester);

    expect(
      tester.getSize(find.byKey(const Key('mobile-entry-one'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester
          .getSize(find.byKey(const Key('mobile-entry-disclosure-one')))
          .height,
      greaterThanOrEqualTo(48),
    );

    final primaryLabel = _semanticsLabel(tester, const Key('mobile-entry-one'));
    final disclosureLabel = _semanticsLabel(
      tester,
      const Key('mobile-entry-disclosure-one'),
    );
    expect(primaryLabel, 'Alpha');
    expect(disclosureLabel, 'Open details for Alpha');
    expect(primaryLabel, isNot(disclosureLabel));

    await disposeApp(tester);
    handle.dispose();
  });

  testWidgets('scrolls a long body inside the outer detail scroll view', (
    tester,
  ) async {
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(
        entries: [
          testEntry(
            'one',
            title: 'Alpha',
            body: List.filled(200, 'long body line').join('\n'),
          ),
        ],
      ),
    );
    await pumpState(tester);

    await openDetail(tester, 'one');

    final viewport = tester.getSize(
      find.byKey(const Key('mobile-detail-scroll')),
    );
    final content = tester.getSize(find.byKey(const Key('mobile-detail-body')));
    expect(content.height, greaterThan(viewport.height));
    await disposeApp(tester);
  });

  testWidgets('copies from detail and refreshes the copied metadata', (
    tester,
  ) async {
    const body = 'detail exact body';
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(
        entries: [testEntry('one', title: 'Alpha', body: body)],
      ),
    );
    await pumpState(tester);

    await openDetail(tester, 'one');
    expect(find.text('Not copied yet'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mobile-detail-copy')));
    await pumpState(tester);

    expect(clipboard.writes, [body]);
    expect(markCopiedCalls('one'), 1);
    expect(find.text('Not copied yet'), findsNothing);
    expect(find.text('Last copied 2026-01-02 00:00'), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('closes the detail route when the entry disappears', (
    tester,
  ) async {
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(entries: [testEntry('one', title: 'Alpha')]),
    );
    await pumpState(tester);

    await openDetail(tester, 'one');
    expect(find.byType(MobileEntryDetailScreen), findsOneWidget);

    repository.emit(const LibrarySnapshot.empty());
    await pumpState(tester);
    await pumpUntilAbsent(tester, find.byType(MobileEntryDetailScreen));

    expect(find.byType(MobileEntryDetailScreen), findsNothing);
    expect(find.byKey(const Key('mobile-library-search')), findsOneWidget);
    await disposeApp(tester);
  });

  // === Mobile filter sheet ===

  testWidgets('opens the filter sheet with modes, categories and tags', (
    tester,
  ) async {
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(
        entries: [testEntry('one', title: 'Alpha')],
        categories: [testCategory('category-1', 'Agents')],
        tags: [testTag('tag-1', 'research')],
      ),
    );
    await pumpState(tester);

    await openFilters(tester);

    expect(find.text('All prompts'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('Archived'), findsOneWidget);
    expect(find.text('All categories'), findsOneWidget);
    expect(find.text('Agents'), findsOneWidget);
    expect(find.text('All tags'), findsOneWidget);
    expect(find.text('research'), findsOneWidget);

    await closeFilters(tester);
    await disposeApp(tester);
  });

  testWidgets('maps favorites and archived modes onto the shared scope', (
    tester,
  ) async {
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(
        entries: [
          testEntry('one', title: 'Alpha', isFavorite: true),
          testEntry('two', title: 'Bravo'),
          testEntry('three', title: 'Charlie', isArchived: true),
        ],
      ),
    );
    await pumpState(tester);

    await openFilters(tester);
    await tester.tap(find.byKey(const Key('mobile-mode-favorites')));
    await pumpState(tester);
    await closeFilters(tester);

    expect(controller.state.filter.scope, LibraryFilterScope.favorites);
    expect(_visibleTitles(tester), ['Alpha']);

    await openFilters(tester);
    await tester.tap(find.byKey(const Key('mobile-mode-archived')));
    await pumpState(tester);
    await closeFilters(tester);

    expect(controller.state.filter.scope, LibraryFilterScope.archived);
    expect(_visibleTitles(tester), ['Charlie']);
    await disposeApp(tester);
  });

  testWidgets('presents recent as copied non-archived entries descending', (
    tester,
  ) async {
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(
        entries: [
          testEntry('one', title: 'Alpha'),
          testEntry(
            'two',
            title: 'Bravo',
            lastCopiedAt: DateTime.utc(2026, 5, 1),
          ),
          testEntry(
            'three',
            title: 'Charlie',
            lastCopiedAt: DateTime.utc(2026, 5, 7),
          ),
          testEntry(
            'four',
            title: 'Delta',
            isArchived: true,
            lastCopiedAt: DateTime.utc(2026, 5, 9),
          ),
        ],
      ),
    );
    await pumpState(tester);

    await openFilters(tester);
    await tester.tap(find.byKey(const Key('mobile-mode-recent')));
    await pumpState(tester);
    await closeFilters(tester);

    expect(controller.state.filter.scope, LibraryFilterScope.active);
    expect(_visibleTitles(tester), ['Charlie', 'Bravo']);
    await disposeApp(tester);
  });

  testWidgets('applies category and tag filters through the controller', (
    tester,
  ) async {
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(
        entries: [
          testEntry(
            'one',
            title: 'Alpha',
            categoryId: 'category-1',
            tagIds: const ['tag-1'],
          ),
          testEntry('two', title: 'Bravo'),
        ],
        categories: [testCategory('category-1', 'Agents')],
        tags: [testTag('tag-1', 'research')],
      ),
    );
    await pumpState(tester);

    await openFilters(tester);
    await tester.tap(find.byKey(const Key('mobile-category-category-1')));
    await pumpState(tester);
    expect(controller.state.filter.categoryId, 'category-1');

    await tester.tap(find.byKey(const Key('mobile-tag-tag-1')));
    await pumpState(tester);
    expect(controller.state.filter.tagIds, ['tag-1']);

    await tester.tap(find.byKey(const Key('mobile-tag-tag-1')));
    await pumpState(tester);
    expect(controller.state.filter.tagIds, isEmpty);

    await closeFilters(tester);
    expect(_visibleTitles(tester), ['Alpha']);
    await disposeApp(tester);
  });

  testWidgets('never mutates taxonomy from the filter sheet', (tester) async {
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(
        entries: [testEntry('one', title: 'Alpha')],
        categories: [testCategory('category-1', 'Agents')],
        tags: [testTag('tag-1', 'research')],
      ),
    );
    await pumpState(tester);

    await openFilters(tester);
    await tester.tap(find.byKey(const Key('mobile-mode-favorites')));
    await pumpState(tester);
    await tester.tap(find.byKey(const Key('mobile-mode-all')));
    await pumpState(tester);
    await tester.tap(find.byKey(const Key('mobile-category-category-1')));
    await pumpState(tester);
    await tester.tap(find.byKey(const Key('mobile-category-all')));
    await pumpState(tester);
    await tester.tap(find.byKey(const Key('mobile-tag-tag-1')));
    await pumpState(tester);
    await tester.tap(find.byKey(const Key('mobile-tag-all')));
    await pumpState(tester);
    await closeFilters(tester);

    const taxonomyMutations = [
      'createCategory',
      'renameCategory',
      'deleteCategory',
      'reorderCategories',
      'createTag',
      'renameTag',
      'deleteTag',
    ];
    for (final mutation in taxonomyMutations) {
      expect(
        repository.calls.where((call) => call.startsWith(mutation)),
        isEmpty,
        reason: 'the filter sheet must not call $mutation',
      );
    }

    await tester.tap(find.byKey(const Key('mobile-entry-one')));
    await pumpState(tester);
    expect(
      repository.calls,
      isNotEmpty,
      reason: 'positive control: the recorder observes real mutations',
    );
    await disposeApp(tester);
  });

  // === Display constraints and accessibility ===

  testWidgets('keeps rows readable and reachable at doubled text scale', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(
        entries: [
          testEntry(
            'one',
            title: 'Alpha prompt with a deliberately long title',
            isFavorite: true,
          ),
        ],
      ),
    );
    await pumpState(tester);

    expect(tester.takeException(), isNull);
    expect(
      find.text('Alpha prompt with a deliberately long title'),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const Key('mobile-entry-one'))).height,
      greaterThanOrEqualTo(48),
    );
    await disposeApp(tester);
  });

  testWidgets('keeps search, filters and the list usable in short landscape', (
    tester,
  ) async {
    await pumpApp(tester);
    tester.view.physicalSize = const Size(844, 390);
    await tester.pump();
    repository.emit(
      LibrarySnapshot(
        entries: [
          for (var index = 1; index <= 20; index++)
            testEntry('entry-$index', title: 'Prompt $index'),
        ],
      ),
    );
    await pumpState(tester);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('mobile-library-search')), findsOneWidget);
    expect(find.byKey(const Key('mobile-filter-button')), findsOneWidget);
    expect(find.byKey(const Key('mobile-entry-entry-1')), findsOneWidget);
    expect(find.byKey(const Key('mobile-entry-entry-20')), findsNothing);

    await tester.dragUntilVisible(
      find.byKey(const Key('mobile-entry-entry-20')),
      find.byKey(const Key('mobile-library-list')),
      const Offset(0, -200),
    );
    await tester.pump();

    expect(find.byKey(const Key('mobile-entry-entry-20')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await disposeApp(tester);
  });

  testWidgets('keeps the detail route scrollable at doubled text scale', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(
        entries: [
          testEntry(
            'one',
            title: 'Alpha prompt with a deliberately long title',
            body: List.filled(40, 'long body line').join('\n'),
            categoryId: 'category-1',
            tagIds: const ['tag-1'],
          ),
        ],
        categories: [testCategory('category-1', 'Agents and assistants')],
        tags: [testTag('tag-1', 'research and analysis')],
      ),
    );
    await pumpState(tester);

    await openDetail(tester, 'one');

    expect(tester.takeException(), isNull);
    final viewport = tester.getSize(
      find.byKey(const Key('mobile-detail-scroll')),
    );
    final content = tester.getSize(find.byKey(const Key('mobile-detail-body')));
    expect(content.height, greaterThan(viewport.height));
    expect(find.byKey(const Key('mobile-detail-copy')), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('keeps every filter option reachable at doubled text scale', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(
        entries: [testEntry('one', title: 'Alpha')],
        categories: [testCategory('category-1', 'Agents and assistants')],
        tags: [testTag('tag-1', 'research and analysis')],
      ),
    );
    await pumpState(tester);

    await openFilters(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('All prompts'), findsOneWidget);

    await tester.dragUntilVisible(
      find.byKey(const Key('mobile-tag-tag-1')),
      find.byKey(const Key('mobile-filter-list')),
      const Offset(0, -120),
    );
    await tester.pump();

    expect(find.byKey(const Key('mobile-tag-tag-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await disposeApp(tester);
  });

  testWidgets('tears down cleanly while the detail route is still open', (
    tester,
  ) async {
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(entries: [testEntry('one', title: 'Alpha')]),
    );
    await pumpState(tester);

    await openDetail(tester, 'one');
    expect(find.byType(MobileEntryDetailScreen), findsOneWidget);

    await disposeApp(tester);
    await tester.runAsync(controller.dispose);
    expect(controller.isDisposed, isTrue);
  });
}

/// Runs one body under the iOS platform override.
Future<void> _withIosPlatform(Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

/// Reads focus state of the mobile search field.
bool _searchHasFocus(WidgetTester tester) {
  return tester
      .widget<EditableText>(
        find.descendant(
          of: find.byKey(
            const Key('mobile-library-search'),
            skipOffstage: false,
          ),
          matching: find.byType(EditableText, skipOffstage: false),
        ),
      )
      .focusNode
      .hasFocus;
}

/// Reads the semantics label of one node.
String? _semanticsLabel(WidgetTester tester, Key key) {
  return tester.getSemantics(find.byKey(key)).label;
}

/// Reads the semantics hint of one retrieval row.
String? _rowHint(WidgetTester tester, String entryId) {
  return tester.getSemantics(find.byKey(Key('mobile-entry-$entryId'))).hint;
}

/// Reads rendered row titles in list order.
List<String?> _visibleTitles(WidgetTester tester) {
  return tester
      .widgetList<Text>(
        find.descendant(
          of: find.byKey(const Key('mobile-library-list')),
          matching: find.byType(Text),
        ),
      )
      .map((text) => text.data)
      .toList();
}

/// Renders whitespace visibly for failure reports.
String _escape(String value) {
  return value.replaceAll(' ', '<sp>').replaceAll('\n', '<nl>');
}

/// Records clipboard writes and injects failures.
final class _RecordingClipboard implements LibraryClipboard {
  /// Text handed to the clipboard boundary.
  final List<String> writes = [];

  /// Blocks every write until completed.
  Completer<void>? gate;

  /// Throwable raised by the next write.
  Object? nextError;

  @override
  Future<void> writeText(String text) async {
    final pending = gate;
    if (pending != null) {
      await pending.future;
    }
    final error = nextError;
    nextError = null;
    if (error != null) {
      throw error;
    }
    writes.add(text);
  }
}

/// Records tactile feedback requests.
final class _RecordingHaptics implements LibraryHaptics {
  /// Number of feedback requests.
  int calls = 0;

  /// Throwable raised by the next request.
  Object? nextError;

  @override
  Future<void> selectionFeedback() async {
    calls++;
    final error = nextError;
    nextError = null;
    if (error != null) {
      throw error;
    }
  }
}

/// Throws before returning a future.
final class _SynchronouslyThrowingShare implements LibraryShare {
  /// Creates a throwing share boundary.
  const _SynchronouslyThrowingShare();

  @override
  Future<LibraryShareOutcome> shareText(String text, {Rect? anchor}) {
    throw StateError('share adapter failed');
  }
}

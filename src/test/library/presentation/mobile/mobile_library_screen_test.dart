/// Mobile retrieval widget tests.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/app/application_surface.dart';
import 'package:prompt_library/src/app/prompt_library_app.dart';
import 'package:prompt_library/src/library/models/library_failure.dart';
import 'package:prompt_library/src/library/models/library_snapshot.dart';
import 'package:prompt_library/src/library/presentation/library_clipboard.dart';
import 'package:prompt_library/src/library/presentation/library_controller.dart';
import 'package:prompt_library/src/library/presentation/library_failure_message.dart';
import 'package:prompt_library/src/library/presentation/library_filter.dart';
import 'package:prompt_library/src/library/presentation/library_haptics.dart';
import 'package:prompt_library/src/library/presentation/library_share.dart';
import 'package:prompt_library/src/library/presentation/mobile/mobile_entry_detail_screen.dart';
import 'package:prompt_library/src/library/presentation/mobile/mobile_entry_editor_screen.dart';
import 'package:prompt_library/src/library/presentation/mobile/mobile_library_screen.dart';
import 'package:prompt_library/src/library/presentation/mobile/mobile_library_actions.dart';
import 'package:prompt_library/src/library/presentation/library_document_files.dart';
import 'package:prompt_library/src/library/presentation/transfer/library_transfer_controller.dart';
import 'package:prompt_library/src/library/presentation/transfer/library_transfer_screen.dart';
import 'package:prompt_library/src/library/transfer/library_document.dart';
import 'package:prompt_library/src/library/transfer/library_json_codec.dart';

import '../../../support/library_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestLibraryRepository repository;
  late LibraryController controller;
  late TestDocumentFiles files;
  late LibraryTransferController transfer;
  late _RecordingClipboard clipboard;
  late _RecordingHaptics haptics;
  late MobileLibraryActions actions;

  setUp(() {
    repository = TestLibraryRepository();
    controller = LibraryController(repository: repository);
    files = TestDocumentFiles();
    transfer = LibraryTransferController(
      repository: repository,
      library: controller,
      files: files,
      now: () => DateTime.utc(2026, 9, 27, 12),
    );
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
    await transfer.dispose();
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
        transferController: transfer,
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

    test(
      'cycle admitted before maintenance records metadata before the barrier',
      () async {
        final entry = testEntry('one', body: 'exact body');
        repository.emit(LibrarySnapshot(entries: [entry]));
        final gate = Completer<void>();
        clipboard.gate = gate;

        final first = actions.copyEntry(entry);
        final joined = actions.copyEntry(entry);
        expect(actions.isPending('one'), isTrue);

        final barrier = controller.beginMaintenance();
        var resolved = false;
        unawaited(barrier.then((_) => resolved = true));

        clipboard.gate = null;
        gate.complete();
        expect(await first, MobileCopyOutcome.copied);
        expect(await joined, isNull);
        await barrier;
        expect(resolved, isTrue);
        expect(markCopiedCalls('one'), 1);
        expect(haptics.calls, 1);
        controller.endMaintenance();
      },
    );

    test('refuses a new copy under maintenance without haptic', () async {
      final entry = testEntry('one', body: 'exact body');
      repository.emit(LibrarySnapshot(entries: [entry]));
      await controller.beginMaintenance();

      expect(await actions.copyEntry(entry), isNull);

      expect(clipboard.writes, isEmpty);
      expect(markCopiedCalls('one'), 0);
      expect(haptics.calls, 0);
      expect(actions.isPending('one'), isFalse);

      controller.endMaintenance();
      expect(await actions.copyEntry(entry), MobileCopyOutcome.copied);
      expect(clipboard.writes, ['exact body']);
      expect(markCopiedCalls('one'), 1);
    });
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
      expect(tester.testTextInput.isVisible, isTrue);

      await tester.tapAt(_freeListPoint(tester, 'one'));
      await pumpState(tester);

      expect(_searchHasFocus(tester), isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
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
      expect(tester.testTextInput.isVisible, isTrue);

      await tester.tap(find.byKey(const Key('mobile-entry-one')));
      await pumpState(tester);

      expect(clipboard.writes, [body]);
      expect(markCopiedCalls('one'), 1);
      expect(_searchHasFocus(tester), isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      await disposeApp(tester);
    });
  });

  testWidgets('opens the detail route from the disclosure while the keyboard '
      'is up', (tester) async {
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

  testWidgets('announces the retrieval surface in a usable order', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(entries: [testEntry('one', title: 'Alpha')]),
    );
    await pumpState(tester);

    final labels = _traversalLabels(tester);
    final searchIndex = labels.indexWhere((label) => label.contains('Search'));
    final rowIndex = labels.indexOf('Alpha');
    final disclosureIndex = labels.indexOf('Open details for Alpha');

    expect(searchIndex, isNonNegative, reason: 'search must be announced');
    expect(rowIndex, isNonNegative, reason: 'the entry must be announced');
    expect(
      disclosureIndex,
      isNonNegative,
      reason: 'the disclosure must be announced separately from the row',
    );
    // Search comes before the results it filters, and the row is reached
    // before the disclosure that belongs to it.
    expect(searchIndex, lessThan(rowIndex));
    expect(rowIndex, lessThan(disclosureIndex));

    // Icon-only controls announce their tooltip rather than a label, so a
    // transcript built from labels alone would silently omit them.
    expect(
      tester
          .getSemantics(find.byKey(const Key('mobile-filter-button')))
          .tooltip,
      'Filters',
    );
    expect(
      tester.getSemantics(find.byKey(const Key('mobile-create-entry'))).tooltip,
      'New prompt',
    );

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

  testWidgets(
    'long press on primary row area opens context menu with 3 items while single tap copies',
    (tester) async {
      await pumpApp(tester);
      repository.emit(
        LibrarySnapshot(entries: [testEntry('one', title: 'Alpha')]),
      );
      await pumpState(tester);

      // Single tap copies and does not show menu
      await tester.tap(find.byKey(const Key('mobile-entry-one')));
      await pumpState(tester);
      expect(clipboard.writes, hasLength(1));
      expect(find.byKey(const Key('mobile-row-action-favorite')), findsNothing);
      expect(find.byKey(const Key('mobile-row-action-archive')), findsNothing);
      expect(find.byKey(const Key('mobile-row-action-delete')), findsNothing);

      // Long press opens menu without copying again
      await tester.longPress(find.byKey(const Key('mobile-entry-one')));
      await tester.pumpAndSettle();

      expect(clipboard.writes, hasLength(1));
      expect(
        find.byKey(const Key('mobile-row-action-favorite')),
        findsOneWidget,
      );
      expect(find.text('Add to favorites'), findsOneWidget);
      expect(
        find.byKey(const Key('mobile-row-action-archive')),
        findsOneWidget,
      );
      expect(find.text('Archive'), findsOneWidget);
      expect(find.byKey(const Key('mobile-row-action-delete')), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      // Tap favorite action from menu
      await tester.tap(find.byKey(const Key('mobile-row-action-favorite')));
      await pumpState(tester);

      expect(repository.calls, contains('setFavorite:one:true'));
      await disposeApp(tester);
    },
  );

  testWidgets(
    'confirms deletion from row context menu, and cancelling confirmation makes zero controller calls',
    (tester) async {
      await pumpApp(tester);
      repository.emit(
        LibrarySnapshot(entries: [testEntry('one', title: 'Alpha')]),
      );
      await pumpState(tester);

      // Long press and select delete
      await tester.longPress(find.byKey(const Key('mobile-entry-one')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mobile-row-action-delete')));
      await tester.pump();

      expect(find.text('Delete prompt?'), findsOneWidget);

      // Cancel deletion
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        repository.calls.where((call) => call.startsWith('deleteEntry')),
        isEmpty,
      );
      expect(find.byKey(const Key('mobile-entry-one')), findsOneWidget);

      // Long press again and confirm deletion
      await tester.longPress(find.byKey(const Key('mobile-entry-one')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mobile-row-action-delete')));
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await pumpState(tester);

      expect(repository.calls, contains('deleteEntry:one'));
      await disposeApp(tester);
    },
  );

  testWidgets(
    'announces and executes custom semantics actions on the row node matching menu handlers',
    (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester);
      repository.emit(
        LibrarySnapshot(
          entries: [
            testEntry('one', title: 'Alpha'),
            testEntry('two', title: 'Beta'),
            testEntry('three', title: 'Gamma'),
          ],
        ),
      );
      await pumpState(tester);

      final rowSemantics = tester.getSemantics(
        find.byKey(const Key('mobile-entry-one')),
      );
      final actionIds = rowSemantics
          .getSemanticsData()
          .customSemanticsActionIds;
      expect(actionIds, isNotNull);
      expect(actionIds, hasLength(3));

      final customActions = actionIds!
          .map(CustomSemanticsAction.getAction)
          .nonNulls
          .toList();
      expect(customActions.map((a) => a.label).toList(), [
        'Add to favorites',
        'Archive',
        'Delete',
      ]);

      // Execute favorite on Alpha
      tester.semantics.performAction(
        find.semantics.byLabel('Alpha'),
        SemanticsAction.customAction,
        args: CustomSemanticsAction.getIdentifier(customActions[0]),
      );
      await pumpState(tester);
      expect(repository.calls, contains('setFavorite:one:true'));

      // Execute archive on Beta
      tester.semantics.performAction(
        find.semantics.byLabel('Beta'),
        SemanticsAction.customAction,
        args: CustomSemanticsAction.getIdentifier(customActions[1]),
      );
      await pumpState(tester);
      expect(repository.calls, contains('setArchived:two:true'));

      // Execute delete on Gamma
      tester.semantics.performAction(
        find.semantics.byLabel('Gamma'),
        SemanticsAction.customAction,
        args: CustomSemanticsAction.getIdentifier(customActions[2]),
      );
      await tester.pump();
      expect(find.text('Delete prompt?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await pumpState(tester);
      expect(repository.calls, contains('deleteEntry:three'));

      handle.dispose();
      await disposeApp(tester);
    },
  );

  testWidgets(
    'disables active row menu action during in-flight mutation while row remains copyable',
    (tester) async {
      await pumpApp(tester);
      repository.emit(
        LibrarySnapshot(entries: [testEntry('one', title: 'Alpha')]),
      );
      await pumpState(tester);

      final gate = Completer<void>();
      repository.nextMutationGate = gate;

      // Start favorite mutation
      await tester.longPress(find.byKey(const Key('mobile-entry-one')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mobile-row-action-favorite')));
      await tester.pump();

      // Open menu while favorite is in flight
      await tester.longPress(find.byKey(const Key('mobile-entry-one')));
      await tester.pumpAndSettle();

      final favoriteItem = tester.widget<PopupMenuItem<dynamic>>(
        find.byKey(const Key('mobile-row-action-favorite')),
      );
      expect(favoriteItem.enabled, isFalse);

      // Close menu by tapping outside
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Row remains copyable during active mutation
      await tester.tap(find.byKey(const Key('mobile-entry-one')));
      await pumpState(tester);
      expect(clipboard.writes, hasLength(1));

      gate.complete();
      await pumpState(tester);
      await disposeApp(tester);
    },
  );

  testWidgets(
    'displays mutation failure in the mobile failure banner when row action fails',
    (tester) async {
      await pumpApp(tester);
      repository.emit(
        LibrarySnapshot(entries: [testEntry('one', title: 'Alpha')]),
      );
      await pumpState(tester);

      const failure = DatabaseFailureLibraryFailure(
        code: LibraryDatabaseFailureCode.transactionFailed,
      );
      repository.nextFailure = failure;

      await tester.longPress(find.byKey(const Key('mobile-entry-one')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mobile-row-action-favorite')));
      await pumpState(tester);

      expect(find.byType(MaterialBanner), findsOneWidget);
      expect(find.text(messageForLibraryFailure(failure)), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Dismiss'));
      await pumpState(tester);
      expect(find.byType(MaterialBanner), findsNothing);

      await disposeApp(tester);
    },
  );

  testWidgets(
    'anchors the row menu to the row geometry rather than a fixed point',
    (tester) async {
      await pumpApp(tester);
      repository.emit(
        LibrarySnapshot(
          entries: [
            testEntry('one', title: 'Alpha'),
            testEntry('two', title: 'Beta'),
            testEntry('three', title: 'Gamma'),
          ],
        ),
      );
      await pumpState(tester);

      /// Opens the menu on one row and returns where the menu was drawn.
      Future<Rect> menuRectFor(String id) async {
        await tester.longPress(find.byKey(Key('mobile-entry-$id')));
        await tester.pumpAndSettle();
        final rect = tester.getRect(
          find.byKey(const Key('mobile-row-action-favorite')),
        );
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        return rect;
      }

      final firstRow = tester.getRect(
        find.byKey(const Key('mobile-entry-one')),
      );
      final thirdRow = tester.getRect(
        find.byKey(const Key('mobile-entry-three')),
      );
      final rowGap = thirdRow.top - firstRow.top;
      expect(rowGap, greaterThan(0));

      final firstMenu = await menuRectFor('one');
      final thirdMenu = await menuRectFor('three');

      // A menu pinned to a constant point would land identically for both rows.
      expect(
        thirdMenu.top - firstMenu.top,
        closeTo(rowGap, 1),
        reason: 'menu offset must track the pressed row, not a fixed point',
      );

      await disposeApp(tester);
    },
  );

  testWidgets(
    'treats a mutation started by another owner as pending for the row menu',
    (tester) async {
      await pumpApp(tester);
      repository.emit(
        LibrarySnapshot(entries: [testEntry('one', title: 'Alpha')]),
      );
      await pumpState(tester);

      // A second actions instance over the same controller stands for any other
      // surface holding the entry: the row must see its mutation as pending.
      final foreignActions = MobileLibraryActions(
        controller: controller,
        clipboard: clipboard,
        share: const UnavailableLibraryShare(),
        haptics: haptics,
      );
      final gate = Completer<void>();
      repository.nextMutationGate = gate;
      unawaited(foreignActions.setFavorite(testEntry('one', title: 'Alpha')));
      await tester.pump();

      await tester.longPress(find.byKey(const Key('mobile-entry-one')));
      await tester.pumpAndSettle();

      final favoriteItem = tester.widget<PopupMenuItem<dynamic>>(
        find.byKey(const Key('mobile-row-action-favorite')),
      );
      expect(
        favoriteItem.enabled,
        isFalse,
        reason: 'pending raised through the controller must disable the item',
      );

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      gate.complete();
      await pumpState(tester);
      await disposeApp(tester);
    },
  );

  testWidgets('labels the favorite action by the current entry state', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(
        entries: [testEntry('one', title: 'Alpha', isFavorite: true)],
      ),
    );
    await pumpState(tester);

    final node = find.semantics
        .byLabel('Alpha')
        .evaluate()
        .single
        .getSemanticsData();
    final labels = (node.customSemanticsActionIds ?? const <int>[])
        .map((id) => CustomSemanticsAction.getAction(id)?.label)
        .toList();
    expect(
      labels,
      contains('Remove from favorites'),
      reason: 'a favorite entry must offer removal, not addition',
    );

    await tester.longPress(find.byKey(const Key('mobile-entry-one')));
    await tester.pumpAndSettle();
    expect(find.text('Remove from favorites'), findsOneWidget);

    handle.dispose();
    await disposeApp(tester);
  });

  testWidgets('labels the archive action by the current entry state', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(
        entries: [testEntry('one', title: 'Alpha', isArchived: true)],
      ),
    );
    await pumpState(tester);

    await openFilters(tester);
    await tester.tap(find.byKey(const Key('mobile-mode-archived')));
    await pumpState(tester);
    await closeFilters(tester);

    final node = find.semantics
        .byLabel('Alpha')
        .evaluate()
        .single
        .getSemanticsData();
    final labels = (node.customSemanticsActionIds ?? const <int>[])
        .map((id) => CustomSemanticsAction.getAction(id)?.label)
        .toList();
    expect(
      labels,
      contains('Restore'),
      reason: 'an archived entry must offer Restore, not Archive',
    );

    handle.dispose();
    await disposeApp(tester);
  });

  testWidgets('keeps the copy contract under real gesture sequences', (
    tester,
  ) async {
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(entries: [testEntry('one', title: 'Alpha')]),
    );
    await pumpState(tester);

    final rowCenter = tester.getCenter(
      find.byKey(const Key('mobile-entry-one')),
    );

    // A real hold goes through the gesture arena, unlike tester.longPress.
    final hold = await tester.startGesture(rowCenter);
    await tester.pump(const Duration(milliseconds: 700));
    await hold.up();
    await tester.pumpAndSettle();
    expect(
      clipboard.writes,
      isEmpty,
      reason: 'a real long press must not copy',
    );
    expect(find.byKey(const Key('mobile-row-action-delete')), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // A drag that begins as a hold belongs to the list, not to either action.
    final drag = await tester.startGesture(rowCenter);
    await tester.pump(const Duration(milliseconds: 100));
    await drag.moveBy(const Offset(0, -120));
    await drag.up();
    await tester.pumpAndSettle();
    expect(clipboard.writes, isEmpty);
    expect(find.byKey(const Key('mobile-row-action-delete')), findsNothing);

    await disposeApp(tester);
  });

  testWidgets('a library stream error is shown without reaching the zone', (
    tester,
  ) async {
    final zoneErrors = <Object>[];
    await runZonedGuarded(() async {
      await pumpApp(tester);
      repository.emit(
        LibrarySnapshot(entries: [testEntry('one', title: 'Alpha')]),
      );
      await pumpState(tester);

      repository.emitObservationError(StateError('observer crashed'));
      await pumpState(tester);
    }, (error, stackTrace) => zoneErrors.add(error));
    expect(zoneErrors, isEmpty);
    expect(
      find.text('The library could not be updated. Try again.'),
      findsOneWidget,
      reason: 'the surface reports the stream error to the user',
    );
    await disposeApp(tester);
  });

  testWidgets('restored library starts at the top after replacement', (
    tester,
  ) async {
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(
        entries: [
          for (var i = 0; i < 100; i++)
            testEntry('old-$i', title: 'Old ${i.toString().padLeft(3, '0')}'),
        ],
      ),
    );
    await pumpState(tester);
    await tester.fling(
      find.byKey(const Key('mobile-library-list')),
      const Offset(0, -800),
      1000,
    );
    await pumpState(tester);

    await tester.tap(find.byKey(const Key('mobile-transfer-button')));
    await tester.pump();
    await tester.pumpAndSettle();
    files.pickResult = DocumentPicked(
      fileName: 'library.json',
      bytes: LibraryJsonCodec().encode(
        LibraryDocument(
          snapshot: LibrarySnapshot(
            entries: [
              for (var i = 0; i < 100; i++)
                testEntry(
                  'new-$i',
                  title: 'Restored ${i.toString().padLeft(3, '0')}',
                ),
            ],
          ),
          exportedAt: DateTime.utc(2026),
        ),
      ),
    );
    await tester.runAsync(() => transfer.startImport());
    await tester.runAsync(() => transfer.continueFromReview());
    files.exportResult = DocumentSaved(path: '/tmp/backup.json');
    await tester.runAsync(() => transfer.createBackupCopy());
    final current = await repository.getSnapshot();
    files.pickResult = DocumentPicked(
      fileName: 'backup.json',
      bytes: LibraryJsonCodec().encode(
        LibraryDocument(snapshot: current, exportedAt: DateTime.utc(2026)),
      ),
    );
    await tester.runAsync(() => transfer.verifyBackupCopy());
    await tester.runAsync(() => transfer.apply());
    await pumpState(tester);
    await tester.tap(find.byKey(const Key('transfer-restore-done-button')));
    await tester.pump();
    await tester.pumpAndSettle();

    final firstRow = find.byKey(const Key('mobile-entry-new-0'));
    expect(
      firstRow,
      findsOneWidget,
      reason: 'the first restored row is built at the top of the list',
    );
    final rowRect = tester.getRect(firstRow);
    final listRect = tester.getRect(
      find.byKey(const Key('mobile-library-list')),
    );
    expect(rowRect.top, greaterThanOrEqualTo(listRect.top));
    expect(rowRect.bottom, lessThanOrEqualTo(listRect.bottom));
  });

  // === Transfer entry point ===

  testWidgets('mobile transfer entry opens the route with an empty library', (
    tester,
  ) async {
    await pumpApp(tester);
    repository.emit(const LibrarySnapshot.empty());
    await pumpState(tester);

    expect(find.byKey(const Key('mobile-transfer-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('mobile-transfer-button')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(LibraryTransferScreen), findsOneWidget);
    expect(find.text('Export JSON'), findsOneWidget);

    await tester.pageBack();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byType(LibraryTransferScreen), findsNothing);
    expect(find.text('Your library is empty'), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('mobile transfer re-entry shows the owner state', (tester) async {
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(entries: [testEntry('one', title: 'Alpha')]),
    );
    await pumpState(tester);
    await tester.runAsync(
      () => transfer.prepareExport(DocumentExportKind.json),
    );
    await pumpState(tester);

    await tester.tap(find.byKey(const Key('mobile-transfer-button')));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('transfer-export-name')),
      findsOneWidget,
      reason: 'the opened route shows the composition owner state',
    );

    await tester.pageBack();
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-transfer-button')));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('transfer-export-name')),
      findsOneWidget,
      reason: 're-entering shows the state that survived route closure',
    );
    expect(find.byKey(const Key('transfer-idle')), findsNothing);
    await disposeApp(tester);
  });

  testWidgets('mobile transfer entry is unreachable while the editor is open', (
    tester,
  ) async {
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(entries: [testEntry('one', title: 'Alpha')]),
    );
    await pumpState(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-create-entry')));
    await tester.pumpAndSettle();
    expect(find.byType(MobileEntryEditorScreen), findsOneWidget);

    expect(
      find.byKey(const Key('mobile-transfer-button')),
      findsNothing,
      reason:
          'the opaque editor route moves the library offstage, so the entry '
          'cannot be hit or focused',
    );
    expect(
      find.byType(LibraryTransferScreen),
      findsNothing,
      reason: 'the full-screen editor covers the transfer entry',
    );
    await disposeApp(tester);
  });

  testWidgets('mobile transfer entry is unreachable while the detail is open', (
    tester,
  ) async {
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(entries: [testEntry('one', title: 'Alpha')]),
    );
    await pumpState(tester);

    await openDetail(tester, 'one');

    await tester.tap(
      find.byKey(const Key('mobile-transfer-button')),
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.byType(LibraryTransferScreen),
      findsNothing,
      reason: 'the full-screen detail absorbs taps meant for the entry',
    );
    expect(
      find.byType(MobileEntryDetailScreen),
      findsOneWidget,
      reason: 'the detail route stays on top',
    );
    await disposeApp(tester);
  });

  testWidgets('row tap copies and does not open the transfer route', (
    tester,
  ) async {
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(
        entries: [testEntry('one', title: 'Alpha', body: 'b1')],
      ),
    );
    await pumpState(tester);

    final rowCenter = tester.getCenter(
      find.byKey(const Key('mobile-entry-one')),
    );
    final tap = await tester.startGesture(rowCenter);
    await tester.pump(const Duration(milliseconds: 30));
    await tap.up();
    await pumpState(tester);

    expect(clipboard.writes, ['b1'], reason: 'the row tap still copies');
    expect(
      find.byType(LibraryTransferScreen),
      findsNothing,
      reason: 'the row tap must not open the transfer route',
    );
    await disposeApp(tester);
  });

  testWidgets('row custom semantic actions are unchanged by the entry', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(entries: [testEntry('one', title: 'Alpha')]),
    );
    await pumpState(tester);

    final node = find.semantics
        .byLabel('Alpha')
        .evaluate()
        .single
        .getSemanticsData();
    final labels = (node.customSemanticsActionIds ?? const <int>[])
        .map((id) => CustomSemanticsAction.getAction(id)?.label)
        .toSet();
    expect(labels, {
      'Add to favorites',
      'Archive',
      'Delete',
    }, reason: 'the row keeps exactly its three row actions');

    handle.dispose();
    await disposeApp(tester);
  });

  testWidgets('mobile transfer entry announces its tooltip', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(entries: [testEntry('one', title: 'Alpha')]),
    );
    await pumpState(tester);

    expect(
      tester
          .getSemantics(find.byKey(const Key('mobile-transfer-button')))
          .tooltip,
      'Transfer library',
    );
    handle.dispose();
    await disposeApp(tester);
  });

  testWidgets('replacement resets the mobile view and mode', (tester) async {
    await pumpApp(tester);
    repository.emit(
      LibrarySnapshot(
        entries: [
          testEntry('kept-a', title: 'Alpha'),
          testEntry('kept-c', title: 'Gamma', isArchived: true),
        ],
      ),
    );
    await pumpState(tester);
    await openFilters(tester);
    await tester.tap(find.byKey(const Key('mobile-mode-archived')));
    await pumpState(tester);
    await closeFilters(tester);
    await tester.enterText(
      find.byKey(const Key('mobile-library-search')),
      'Gam',
    );
    await pumpState(tester);
    expect(find.text('Gamma'), findsOneWidget);
    expect(find.text('Alpha'), findsNothing);

    files.pickResult = DocumentPicked(
      fileName: 'library.json',
      bytes: LibraryJsonCodec().encode(
        LibraryDocument(
          snapshot: LibrarySnapshot(
            entries: [
              testEntry('restored-1', title: 'Restored One'),
              testEntry('restored-2', title: 'Restored Two'),
            ],
          ),
          exportedAt: DateTime.utc(2026),
        ),
      ),
    );
    await tester.runAsync(() => transfer.startImport());
    await tester.runAsync(() => transfer.continueFromReview());
    files.exportResult = DocumentSaved(path: '/tmp/backup.json');
    await tester.runAsync(() => transfer.createBackupCopy());
    final current = await repository.getSnapshot();
    files.pickResult = DocumentPicked(
      fileName: 'backup.json',
      bytes: LibraryJsonCodec().encode(
        LibraryDocument(snapshot: current, exportedAt: DateTime.utc(2026)),
      ),
    );
    await tester.runAsync(() => transfer.verifyBackupCopy());
    await tester.runAsync(() => transfer.apply());
    await pumpState(tester);

    expect(
      find.text('Restored One'),
      findsOneWidget,
      reason: 'the restored library is visible under the default view',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('mobile-library-search')))
          .controller
          ?.text,
      isEmpty,
      reason: 'the mobile search field is cleared',
    );

    await openFilters(tester);
    expect(
      tester
          .widget<ListTile>(find.byKey(const Key('mobile-mode-all')))
          .selected,
      isTrue,
      reason: 'the mobile mode returns to all',
    );
    expect(
      tester
          .widget<ListTile>(find.byKey(const Key('mobile-mode-archived')))
          .selected,
      isFalse,
    );
    await closeFilters(tester);
    await disposeApp(tester);
  });

  testWidgets('mobile done returns exactly one route to the library', (
    tester,
  ) async {
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
                    clipboard: clipboard,
                    transfer: transfer,
                    share: const UnavailableLibraryShare(),
                    haptics: haptics,
                  ),
                ),
              ),
              child: const Text('Open library'),
            ),
          ),
        ),
      ),
    );
    repository.emit(
      LibrarySnapshot(entries: [testEntry('kept-a', title: 'Alpha')]),
    );
    await tester.tap(find.byKey(const Key('open-mobile-library')));
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-transfer-button')));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byType(LibraryTransferScreen), findsOneWidget);

    files.pickResult = DocumentPicked(
      fileName: 'library.json',
      bytes: LibraryJsonCodec().encode(
        LibraryDocument(
          snapshot: LibrarySnapshot(
            entries: [testEntry('restored-1', title: 'Restored One')],
          ),
          exportedAt: DateTime.utc(2026),
        ),
      ),
    );
    await tester.runAsync(() => transfer.startImport());
    await tester.runAsync(() => transfer.continueFromReview());
    files.exportResult = DocumentSaved(path: '/tmp/backup.json');
    await tester.runAsync(() => transfer.createBackupCopy());
    final current = await repository.getSnapshot();
    files.pickResult = DocumentPicked(
      fileName: 'backup.json',
      bytes: LibraryJsonCodec().encode(
        LibraryDocument(snapshot: current, exportedAt: DateTime.utc(2026)),
      ),
    );
    await tester.runAsync(() => transfer.verifyBackupCopy());
    await tester.runAsync(() => transfer.apply());
    await pumpState(tester);
    expect(find.byKey(const Key('transfer-restore-done')), findsOneWidget);

    await tester.tap(find.byKey(const Key('transfer-restore-done-button')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(LibraryTransferScreen), findsNothing);
    expect(
      find.byKey(const Key('mobile-library-search')),
      findsOneWidget,
      reason: 'Done popped exactly the transfer route, keeping the library',
    );
    expect(
      find.byKey(const Key('route-sentinel')),
      findsNothing,
      reason:
          'the sentinel stays offstage below the library; a double pop would '
          'show it instead of the search field',
    );
    await disposeApp(tester);
  });

  testWidgets('search bar with the transfer entry survives large text', (
    tester,
  ) async {
    await pumpApp(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 3.1;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    repository.emit(
      LibrarySnapshot(entries: [testEntry('one', title: 'Alpha')]),
    );
    await pumpState(tester);

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const Key('mobile-library-search'))).width,
      greaterThan(0),
      reason: 'the search field keeps a positive width',
    );
    expect(
      tester.getSize(find.byKey(const Key('mobile-transfer-button'))).width,
      greaterThan(0),
    );
    await disposeApp(tester);
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
          of: find.byKey(const Key('mobile-library-search')),
          matching: find.byType(EditableText),
        ),
      )
      .focusNode
      .hasFocus;
}

/// Point in the free list area below the last rendered row.
Offset _freeListPoint(WidgetTester tester, String lastEntryId) {
  final list = tester.getRect(find.byKey(const Key('mobile-library-list')));
  final lastRow = tester.getRect(find.byKey(Key('mobile-entry-$lastEntryId')));
  final point = Offset(list.left + 20, lastRow.bottom + 20);
  expect(
    list.contains(point),
    isTrue,
    reason: 'free list point $point must stay inside the list $list',
  );
  return point;
}

/// Collects labelled semantics in traversal order.
///
/// This is an ordering probe, not a transcript. It reaches nodes that carry a
/// label, which is enough to assert relative order, and claims nothing more:
/// icon-only controls expose their text through a separate tooltip field this
/// walk does not reach, and the role a reader speaks on top of a label is a
/// system concern no widget test can observe.
List<String> _traversalLabels(WidgetTester tester) {
  final labels = <String>[];
  void visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    final label = data.label.trim();
    if (label.isNotEmpty) labels.add(label);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(tester.getSemantics(find.byType(MaterialApp)));
  return labels;
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

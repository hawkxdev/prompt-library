/// Integrated iOS library journey.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:prompt_library/src/app/application_surface.dart';
import 'package:prompt_library/src/app/composition_root.dart';
import 'package:prompt_library/src/library/presentation/library_controller.dart';
import 'package:prompt_library/src/library/presentation/library_state.dart';
import 'package:prompt_library/src/library/presentation/mobile/mobile_entry_detail_screen.dart';

const _stateTimeout = Duration(seconds: 10);
const _pumpStep = Duration(milliseconds: 100);
const _pumpAttempts = 100;

// === Journey ===

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('iOS production journey persists edits across graph reopen', (
    tester,
  ) async {
    final marker = 'stage5-${DateTime.now().toUtc().microsecondsSinceEpoch}';
    final originalTitle = '$marker original';
    final updatedTitle = '$marker updated';
    const originalBody = '  Stage 5 line one\n\nStage 5 line two  ';
    const updatedBody =
        '  Stage 5 revised line one\n\nStage 5 revised line two  ';

    PromptLibraryComposition? activeComposition;
    Object? primaryError;
    StackTrace? primaryStackTrace;
    Object? cleanupError;
    StackTrace? cleanupStackTrace;

    try {
      try {
        final firstComposition = PromptLibraryComposition.production();
        activeComposition = firstComposition;
        expect(firstComposition.applicationSurface, ApplicationSurface.mobile);
        await tester.pumpWidget(
          PromptLibraryCompositionRoot(composition: firstComposition),
        );
        await _waitForReady(firstComposition.controller);
        await _pumpUntil(
          tester,
          () => find
              .byKey(const Key('mobile-library-search'))
              .evaluate()
              .isNotEmpty,
          'initial mobile library',
        );

        await _tapWhenReady(
          tester,
          find.byKey(const Key('mobile-create-entry')),
        );
        await _pumpUntil(
          tester,
          () => find
              .byKey(const Key('mobile-entry-editor-screen'))
              .evaluate()
              .isNotEmpty,
          'create editor',
        );
        await tester.enterText(
          find.byKey(const Key('editor-title')),
          originalTitle,
        );
        await tester.enterText(
          find.byKey(const Key('editor-body')),
          originalBody,
        );
        await _tapWhenReady(
          tester,
          find.byKey(const Key('mobile-editor-save')),
        );
        await _pumpUntil(
          tester,
          () =>
              find
                  .byKey(const Key('mobile-entry-editor-screen'))
                  .evaluate()
                  .isEmpty &&
              find.text(originalTitle).evaluate().isNotEmpty,
          'created entry',
        );

        final search = find.byKey(const Key('mobile-library-search'));
        await tester.enterText(search, marker);
        await _pumpUntil(
          tester,
          () => find.text(originalTitle).evaluate().isNotEmpty,
          'filtered entry',
        );
        await tester.enterText(search, '');
        await _pumpUntil(
          tester,
          () => find.text(originalTitle).evaluate().isNotEmpty,
          'cleared search',
        );

        await Clipboard.setData(
          const ClipboardData(text: 'stage5 clipboard sentinel'),
        );
        await _tapWhenReady(tester, find.text(originalTitle));
        await _pumpUntil(
          tester,
          () => find.text('Copied').evaluate().isNotEmpty,
          'copy confirmation',
        );
        final clipboard = await Clipboard.getData('text/plain');
        expect(clipboard?.text, originalBody);

        await _tapWhenReady(
          tester,
          find.bySemanticsLabel('Open details for $originalTitle'),
        );
        await _pumpUntil(
          tester,
          () =>
              find.byKey(const Key('mobile-detail-edit')).evaluate().isNotEmpty,
          'entry detail',
        );
        expect(_findDetailText(originalTitle), findsOneWidget);
        expect(_findDetailText(originalBody), findsOneWidget);

        await _tapWhenReady(
          tester,
          find.byKey(const Key('mobile-detail-edit')),
        );
        await _pumpUntil(
          tester,
          () => find
              .byKey(const Key('mobile-entry-editor-screen'))
              .evaluate()
              .isNotEmpty,
          'edit screen',
        );
        await tester.enterText(
          find.byKey(const Key('editor-title')),
          updatedTitle,
        );
        await tester.enterText(
          find.byKey(const Key('editor-body')),
          updatedBody,
        );
        await _tapWhenReady(
          tester,
          find.byKey(const Key('mobile-editor-save')),
        );
        await _pumpUntil(
          tester,
          () =>
              find
                  .byKey(const Key('mobile-entry-editor-screen'))
                  .evaluate()
                  .isEmpty &&
              _findDetailText(updatedTitle).evaluate().isNotEmpty &&
              _findDetailText(updatedBody).evaluate().isNotEmpty,
          'updated detail',
        );

        await _unmountGraph(tester, firstComposition);
        activeComposition = null;

        final reopenedComposition = PromptLibraryComposition.production();
        activeComposition = reopenedComposition;
        await tester.pumpWidget(
          PromptLibraryCompositionRoot(composition: reopenedComposition),
        );
        await _waitForReady(reopenedComposition.controller);
        await _pumpUntil(
          tester,
          () => find
              .byKey(const Key('mobile-library-search'))
              .evaluate()
              .isNotEmpty,
          'reopened mobile library',
        );

        final reopenedSearch = find.byKey(const Key('mobile-library-search'));
        await tester.enterText(reopenedSearch, marker);
        await _pumpUntil(
          tester,
          () => find.text(updatedTitle).evaluate().isNotEmpty,
          'reopened entry',
        );
        await _tapWhenReady(
          tester,
          find.bySemanticsLabel('Open details for $updatedTitle'),
        );
        await _pumpUntil(
          tester,
          () => find
              .byKey(const Key('mobile-detail-delete'))
              .evaluate()
              .isNotEmpty,
          'reopened detail',
        );
        expect(_findDetailText(updatedBody), findsOneWidget);

        await _tapWhenReady(
          tester,
          find.byKey(const Key('mobile-detail-delete')),
        );
        await _pumpUntil(
          tester,
          () => find.text('Delete prompt?').evaluate().isNotEmpty,
          'delete confirmation',
        );
        await _tapWhenReady(
          tester,
          find.widgetWithText(FilledButton, 'Delete'),
        );
        await _pumpUntil(
          tester,
          () =>
              find
                  .byKey(const Key('mobile-detail-delete'))
                  .evaluate()
                  .isEmpty &&
              find.text(updatedTitle).evaluate().isEmpty,
          'deleted entry',
        );
      } catch (error, stackTrace) {
        primaryError = error;
        primaryStackTrace = stackTrace;
      }
    } finally {
      final composition = activeComposition;
      if (composition != null) {
        try {
          await _cleanupGraph(tester, composition, marker);
        } catch (error, stackTrace) {
          cleanupError = error;
          cleanupStackTrace = stackTrace;
        }
      }
    }

    if (primaryError != null) {
      Error.throwWithStackTrace(primaryError, primaryStackTrace!);
    }
    if (cleanupError != null) {
      Error.throwWithStackTrace(cleanupError, cleanupStackTrace!);
    }
  }, skip: !Platform.isIOS);
}

// === Test helpers ===

/// Finds text within the active detail route.
Finder _findDetailText(String text) {
  return find.descendant(
    of: find.byType(MobileEntryDetailScreen),
    matching: find.text(text),
  );
}

/// Waits for the production snapshot.
Future<LibraryState> _waitForReady(LibraryController controller) {
  final current = controller.state;
  if (current.loadStatus == LibraryLoadStatus.ready) {
    return Future.value(current);
  }
  return controller.states
      .firstWhere((state) => state.loadStatus == LibraryLoadStatus.ready)
      .timeout(_stateTimeout);
}

/// Pumps until one observable condition holds.
Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition,
  String description,
) async {
  for (var attempt = 0; attempt < _pumpAttempts; attempt++) {
    final pendingException = tester.takeException();
    if (pendingException != null) {
      throw pendingException;
    }
    if (condition()) {
      return;
    }
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(_pumpStep);
  }
  final keyedWidgets = find
      .byWidgetPredicate((widget) => widget.key != null, skipOffstage: false)
      .evaluate()
      .map((element) => '${element.widget.runtimeType}:${element.widget.key}')
      .take(40)
      .join(', ');
  throw TimeoutException(
    'Timed out waiting for $description. Visible keys: $keyedWidgets',
    _stateTimeout,
  );
}

/// Taps one visible enabled target.
Future<void> _tapWhenReady(WidgetTester tester, Finder finder) async {
  await _pumpUntil(
    tester,
    () => finder.hitTestable().evaluate().length == 1,
    'a tappable target',
  );
  await tester.tap(finder);
  await tester.pump();
}

/// Unmounts the root before closing its graph.
Future<void> _unmountGraph(
  WidgetTester tester,
  PromptLibraryComposition composition,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await composition.dispose();
}

/// Deletes owned residue and closes the active graph.
Future<void> _cleanupGraph(
  WidgetTester tester,
  PromptLibraryComposition composition,
  String marker,
) async {
  Object? firstError;
  StackTrace? firstStackTrace;

  if (!composition.controller.isDisposed) {
    try {
      final ready = await _waitForReady(composition.controller);
      final snapshot = ready.snapshot;
      if (snapshot != null) {
        final remaining = snapshot.entries.where(
          (entry) =>
              entry.title.contains(marker) || entry.body.contains(marker),
        );
        for (final entry in remaining) {
          await composition.controller.deleteEntry(entry.id);
        }
      }
    } catch (error, stackTrace) {
      firstError = error;
      firstStackTrace = stackTrace;
    }
  }

  try {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  } catch (error, stackTrace) {
    firstError ??= error;
    firstStackTrace ??= stackTrace;
  }

  try {
    await composition.dispose();
  } catch (error, stackTrace) {
    firstError ??= error;
    firstStackTrace ??= stackTrace;
  }

  if (firstError != null) {
    Error.throwWithStackTrace(firstError, firstStackTrace!);
  }
}

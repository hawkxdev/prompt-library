/// Mobile entry editor tests.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/library/models/entry.dart';
import 'package:prompt_library/src/library/models/library_failure.dart';
import 'package:prompt_library/src/library/models/library_snapshot.dart';
import 'package:prompt_library/src/library/presentation/library_controller.dart';
import 'package:prompt_library/src/library/presentation/mobile/mobile_entry_editor_screen.dart';

import '../../../support/library_test_support.dart';

void main() {
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

  Future<void> pumpEditor(
    WidgetTester tester, {
    Entry? entry,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
        ),
        home: Scaffold(
          key: const Key('route-sentinel'),
          body: Builder(
            builder: (context) => FilledButton(
              key: const Key('open-editor'),
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => MobileEntryEditorScreen(
                    controller: controller,
                    entry: entry,
                  ),
                ),
              ),
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    });
    tester
        .widget<FilledButton>(find.byKey(const Key('open-editor')))
        .onPressed!();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(MobileEntryEditorScreen), findsOneWidget);
    expect(find.byKey(const Key('mobile-entry-editor-screen')), findsOneWidget);
  }

  Future<void> enterRequiredDraft(
    WidgetTester tester, {
    String title = 'Mobile title',
    String body = 'Mobile body',
  }) async {
    await tester.enterText(find.byKey(const Key('editor-title')), title);
    await tester.enterText(find.byKey(const Key('editor-body')), body);
  }

  testWidgets('creates an entry and closes only the editor route', (
    tester,
  ) async {
    repository.emit(const LibrarySnapshot.empty());
    await pumpEditor(tester);
    await enterRequiredDraft(tester);

    await tester.tap(find.byKey(const Key('mobile-editor-save')));
    await pumpState(tester);
    await tester.pumpAndSettle();

    expect(
      repository.calls.where((call) => call == 'createEntry'),
      hasLength(1),
    );
    expect(find.byKey(const Key('mobile-entry-editor-screen')), findsNothing);
    expect(find.byKey(const Key('route-sentinel')), findsOneWidget);
  });

  testWidgets('updates an entry and closes only the editor route', (
    tester,
  ) async {
    final entry = testEntry('entry-1', title: 'Old title', body: 'Old body');
    repository.emit(LibrarySnapshot(entries: [entry]));
    await pumpEditor(tester, entry: entry);
    await enterRequiredDraft(
      tester,
      title: 'Updated title',
      body: 'Updated body',
    );

    await tester.tap(find.byKey(const Key('mobile-editor-save')));
    await pumpState(tester);
    await tester.pumpAndSettle();

    final updated = (await repository.getSnapshot()).entries.single;
    expect(repository.calls, contains('updateEntryDetails:entry-1'));
    expect(updated.title, 'Updated title');
    expect(updated.body, 'Updated body');
    expect(find.byKey(const Key('mobile-entry-editor-screen')), findsNothing);
    expect(find.byKey(const Key('route-sentinel')), findsOneWidget);
  });

  testWidgets('retains the draft and message after a typed failure', (
    tester,
  ) async {
    repository.emit(const LibrarySnapshot.empty());
    await pumpEditor(tester);
    await enterRequiredDraft(
      tester,
      title: 'Private title',
      body: 'Private body',
    );
    repository.nextFailure = const LibraryFailure.databaseFailure(
      code: LibraryDatabaseFailureCode.transactionFailed,
    );

    await tester.tap(find.byKey(const Key('mobile-editor-save')));
    await pumpState(tester);

    expect(
      find.text('The library could not save this change.'),
      findsOneWidget,
    );
    expect(find.text('Private title'), findsOneWidget);
    expect(find.text('Private body'), findsOneWidget);
    expect(find.byKey(const Key('mobile-entry-editor-screen')), findsOneWidget);
  });

  testWidgets('shows validation messages without throwing', (tester) async {
    repository.emit(const LibrarySnapshot.empty());
    await pumpEditor(tester);

    await tester.tap(find.byKey(const Key('mobile-editor-save')));
    await tester.pump();
    expect(find.text('Title is required.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byKey(const Key('editor-title')), 'Title');
    await tester.tap(find.byKey(const Key('mobile-editor-save')));
    await tester.pump();
    expect(find.text('Body is required.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(repository.calls, isEmpty);
  });

  testWidgets('rejects a duplicate save while the mutation is pending', (
    tester,
  ) async {
    repository.emit(const LibrarySnapshot.empty());
    await pumpEditor(tester);
    await enterRequiredDraft(tester);
    final gate = Completer<void>();
    repository.nextMutationGate = gate;

    await tester.tap(find.byKey(const Key('mobile-editor-save')));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('mobile-editor-save')),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(
      repository.calls.where((call) => call == 'createEntry'),
      hasLength(1),
    );
    gate.complete();
    await pumpState(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-entry-editor-screen')), findsNothing);
    expect(find.byKey(const Key('route-sentinel')), findsOneWidget);
  });

  testWidgets('confirms cancellation only for a dirty draft', (tester) async {
    repository.emit(const LibrarySnapshot.empty());
    await pumpEditor(tester);
    await tester.enterText(
      find.byKey(const Key('editor-title')),
      'Unsaved title',
    );

    await tester.tap(find.byKey(const Key('mobile-editor-cancel')));
    await tester.pump();

    expect(find.text('Discard changes?'), findsOneWidget);
    expect(find.byKey(const Key('mobile-entry-editor-screen')), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Keep editing'));
    await tester.pump();
    expect(find.text('Unsaved title'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mobile-editor-cancel')));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-entry-editor-screen')), findsNothing);
    expect(repository.calls, isEmpty);
  });

  testWidgets('closes a clean draft without confirmation', (tester) async {
    repository.emit(const LibrarySnapshot.empty());
    await pumpEditor(tester);

    await tester.tap(find.byKey(const Key('mobile-editor-cancel')));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsNothing);
    expect(find.byKey(const Key('mobile-entry-editor-screen')), findsNothing);
    expect(find.byKey(const Key('route-sentinel')), findsOneWidget);
  });

  testWidgets('guards a dirty draft from the system back action', (
    tester,
  ) async {
    repository.emit(const LibrarySnapshot.empty());
    await pumpEditor(tester);
    await tester.enterText(
      find.byKey(const Key('editor-body')),
      'Unsaved body',
    );
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.text('Discard changes?'), findsOneWidget);
    expect(find.byKey(const Key('mobile-entry-editor-screen')), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Keep editing'));
    await tester.pump();
    expect(find.text('Unsaved body'), findsOneWidget);
  });

  testWidgets('keeps app bar actions reachable above keyboard insets', (
    tester,
  ) async {
    repository.emit(const LibrarySnapshot.empty());
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.resetViewInsets);
    await pumpEditor(tester);

    final screen = tester.getRect(
      find.byKey(const Key('mobile-entry-editor-screen')),
    );
    final save = tester.getRect(find.byKey(const Key('mobile-editor-save')));
    final cancel = tester.getRect(
      find.byKey(const Key('mobile-editor-cancel')),
    );
    expect(screen.contains(save.center), isTrue);
    expect(screen.contains(cancel.center), isTrue);
    expect(save.bottom, lessThanOrEqualTo(screen.bottom - 320));
    expect(cancel.bottom, lessThanOrEqualTo(screen.bottom - 320));
    expect(find.byKey(const Key('mobile-editor-save')).hitTestable(), findsOne);
    expect(
      find.byKey(const Key('mobile-editor-cancel')).hitTestable(),
      findsOne,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('reaches every field by scrolling in short landscape', (
    tester,
  ) async {
    repository.emit(
      LibrarySnapshot(
        categories: [testCategory('category-1', 'Agents')],
        tags: [testTag('tag-1', 'research')],
      ),
    );
    await pumpEditor(tester, size: const Size(844, 390));

    final viewport = tester.getRect(
      find.byKey(const Key('mobile-editor-body')),
    );
    final fields = tester.getRect(find.byKey(const Key('editor-fields')));
    expect(fields.height, greaterThan(viewport.height));

    for (final key in const [
      Key('editor-title'),
      Key('editor-body'),
      Key('editor-keyword'),
      Key('editor-category'),
      Key('editor-tag-tag-1'),
    ]) {
      await tester.ensureVisible(find.byKey(key));
      await tester.pump();
      final target = tester.getRect(find.byKey(key));
      expect(find.byKey(key), findsOneWidget);
      expect(target.bottom, greaterThan(viewport.top));
      expect(target.top, lessThan(viewport.bottom));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('fits fields and tag chips with large text in landscape', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    repository.emit(
      LibrarySnapshot(
        categories: [testCategory('category-1', 'Agents and assistants')],
        tags: [testTag('tag-1', 'research and analysis')],
      ),
    );
    await pumpEditor(tester, size: const Size(844, 390));

    await tester.ensureVisible(find.byKey(const Key('editor-tag-tag-1')));
    await tester.pump();

    final viewport = tester.getRect(
      find.byKey(const Key('mobile-editor-body')),
    );
    final tag = tester.getRect(find.byKey(const Key('editor-tag-tag-1')));
    expect(find.text('research and analysis'), findsOneWidget);
    expect(tag.bottom, lessThanOrEqualTo(viewport.bottom));
    expect(tag.top, greaterThanOrEqualTo(viewport.top));
    expect(find.byKey(const Key('mobile-editor-save')), findsOneWidget);
    expect(find.byKey(const Key('mobile-editor-cancel')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the category row inside the form at accessibility scale', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 3.1;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    repository.emit(
      LibrarySnapshot(
        categories: [testCategory('category-1', 'Agents and assistants')],
      ),
    );
    await pumpEditor(tester);

    await tester.ensureVisible(find.byKey(const Key('editor-category')));
    await tester.pump();

    final form = tester.getRect(find.byKey(const Key('mobile-editor-body')));
    final category = tester.getRect(find.byKey(const Key('editor-category')));
    expect(category.right, lessThanOrEqualTo(form.right));
    expect(category.left, greaterThanOrEqualTo(form.left));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the cancel label on one line at accessibility scale', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 3.1;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    repository.emit(const LibrarySnapshot.empty());
    await pumpEditor(tester);

    // Height alone does not differentiate: an ellipsis keeps the label on one
    // line while still hiding characters. Compare the painted width with the
    // width the same span needs unconstrained — a clipped label is narrower.
    final label = tester.renderObject<RenderParagraph>(find.text('Cancel'));
    final unconstrained = TextPainter(
      text: label.text,
      textDirection: TextDirection.ltr,
      textScaler: label.textScaler,
    )..layout();
    addTearDown(unconstrained.dispose);

    expect(label.size.width, closeTo(unconstrained.width, 1));
    expect(
      label.size.width,
      lessThanOrEqualTo(
        tester.getSize(find.byKey(const Key('mobile-editor-cancel'))).width,
      ),
    );

    // The save action shares the same bar. Widening the leading without a cap
    // on bar text growth pushes it out, so assert it is unclipped too.
    final action = tester.renderObject<RenderParagraph>(find.text('Save'));
    final actionUnconstrained = TextPainter(
      text: action.text,
      textDirection: TextDirection.ltr,
      textScaler: action.textScaler,
    )..layout();
    addTearDown(actionUnconstrained.dispose);

    expect(action.size.width, closeTo(actionUnconstrained.width, 1));
  });

  testWidgets('gives the refusal to the blocking field, not to a summary', (
    tester,
  ) async {
    repository.emit(const LibrarySnapshot.empty());
    await pumpEditor(tester);
    await tester.enterText(find.byKey(const Key('editor-title')), 'Title');

    await tester.tap(find.byKey(const Key('mobile-editor-save')));
    await tester.pump();

    // The message must belong to the field that blocks the save. Asserting
    // that the text exists somewhere passes on the pre-stage version too,
    // because a summary at the end of the form carries the same string.
    final body = tester.widget<TextField>(find.byKey(const Key('editor-body')));
    final title = tester.widget<TextField>(
      find.byKey(const Key('editor-title')),
    );
    expect(body.decoration?.errorText, 'Body is required.');
    expect(title.decoration?.errorText, isNull);
    expect(repository.calls, isEmpty);
  });

  testWidgets('moves focus to the first unfilled field without a frame', (
    tester,
  ) async {
    repository.emit(const LibrarySnapshot.empty());
    await pumpEditor(tester);
    await tester.enterText(find.byKey(const Key('editor-title')), 'Title');

    await tester.tap(find.byKey(const Key('mobile-editor-save')));
    // idle() drains microtasks without producing a frame, so a post-frame
    // focus request stays pending here while a synchronous one takes effect.
    await tester.idle();

    expect(
      _focusIsInside(const Key('editor-body')),
      isTrue,
      reason: 'the blocking field must hold focus right after the refusal',
    );
  });

  testWidgets('announces the refusal on the field node itself', (tester) async {
    final handle = tester.ensureSemantics();
    repository.emit(const LibrarySnapshot.empty());
    await pumpEditor(tester);
    await tester.enterText(find.byKey(const Key('editor-title')), 'Title');

    await tester.tap(find.byKey(const Key('mobile-editor-save')));
    await tester.pump();

    // getSemantics on the field returns an unmerged node with empty label and
    // hint even when the framework does announce the error, so the walk below
    // is what actually observes the announcement.
    final fields = _textFieldSemantics(tester);
    final blocked = fields.singleWhere((data) => data.label.contains('Body'));
    expect(blocked.hint, contains('Body is required.'));
    expect(blocked.validationResult, SemanticsValidationResult.invalid);
    handle.dispose();
  });

  testWidgets('clears the field refusal once the field is filled', (
    tester,
  ) async {
    repository.emit(const LibrarySnapshot.empty());
    await pumpEditor(tester);
    await tester.enterText(find.byKey(const Key('editor-title')), 'Title');
    await tester.tap(find.byKey(const Key('mobile-editor-save')));
    await tester.pump();

    await tester.enterText(find.byKey(const Key('editor-body')), 'Body');
    await tester.pump();

    final body = tester.widget<TextField>(find.byKey(const Key('editor-body')));
    expect(body.decoration?.errorText, isNull);
  });

  testWidgets('announces a persistence failure as a live region', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    repository.emit(const LibrarySnapshot.empty());
    await pumpEditor(tester);
    await enterRequiredDraft(tester);
    repository.nextFailure = const LibraryFailure.databaseFailure(
      code: LibraryDatabaseFailureCode.transactionFailed,
    );

    await tester.tap(find.byKey(const Key('mobile-editor-save')));
    await pumpState(tester);

    final message = tester.getSemantics(
      find.text('The library could not save this change.'),
    );
    expect(message.flagsCollection.isLiveRegion, isTrue);
    handle.dispose();
  });

  testWidgets('keeps validation out of the persistence summary', (
    tester,
  ) async {
    repository.emit(const LibrarySnapshot.empty());
    await pumpEditor(tester);

    await tester.tap(find.byKey(const Key('mobile-editor-save')));
    await tester.pump();

    // A refusal owned by a field must not also render the bottom summary:
    // two owners for one message is what made the refusal unreadable.
    expect(find.byKey(const Key('editor-failure')), findsNothing);
    final title = tester.widget<TextField>(
      find.byKey(const Key('editor-title')),
    );
    expect(title.decoration?.errorText, 'Title is required.');
  });

  testWidgets('preserves exact body and taxonomy assignments', (tester) async {
    const exactBody = '  leading\nand trailing  ';
    repository.emit(
      LibrarySnapshot(
        categories: [testCategory('category-1', 'Agents')],
        tags: [testTag('tag-1', 'research')],
      ),
    );
    await pumpEditor(tester);
    await enterRequiredDraft(tester, body: exactBody);

    await tester.tap(find.byKey(const Key('editor-category')));
    await tester.pump();
    await tester.tap(find.text('Agents').last);
    await tester.pump();
    await tester.tap(find.byKey(const Key('editor-tag-tag-1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mobile-editor-save')));
    await pumpState(tester);

    final created = (await repository.getSnapshot()).entries.single;
    expect(_escape(created.body), _escape(exactBody));
    expect(created.categoryId, 'category-1');
    expect(created.tagIds, ['tag-1']);
  });
}

/// Renders whitespace visibly.
String _escape(String value) {
  return value.replaceAll(' ', '<sp>').replaceAll('\n', '<nl>');
}

/// Reports whether primary focus sits inside the keyed subtree.
bool _focusIsInside(Key key) {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  var found = false;
  context.visitAncestorElements((element) {
    if (element.widget.key == key) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

/// Collects semantics of every rendered text field.
List<SemanticsData> _textFieldSemantics(WidgetTester tester) {
  final collected = <SemanticsData>[];
  void walk(SemanticsNode node) {
    final data = node.getSemanticsData();
    if (data.flagsCollection.isTextField) {
      collected.add(data);
    }
    node.visitChildren((child) {
      walk(child);
      return true;
    });
  }

  walk(tester.semantics.find(find.byKey(const Key('mobile-editor-body'))));
  return collected;
}

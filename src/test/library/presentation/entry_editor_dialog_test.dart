/// Entry editor dialog tests.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/library/models/entry.dart';
import 'package:prompt_library/src/library/models/library_failure.dart';
import 'package:prompt_library/src/library/models/entry_input.dart';
import 'package:prompt_library/src/library/models/library_snapshot.dart';
import 'package:prompt_library/src/library/presentation/entry_editor_dialog.dart';
import 'package:prompt_library/src/library/presentation/entry_editor_form.dart';
import 'package:prompt_library/src/library/presentation/library_controller.dart';

import '../../support/library_test_support.dart';

void main() {
  // === Draft ownership ===

  testWidgets('uses the shared editor form', (tester) async {
    final repository = TestLibraryRepository();
    final controller = LibraryController(repository: repository);
    addTearDown(() async {
      await controller.dispose();
      await repository.close();
    });
    repository.emit(const LibrarySnapshot.empty());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showEntryEditorDialog(context, controller: controller),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();

    expect(find.byType(EntryEditorForm), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('preserves exact body and retains draft on typed failure', (
    tester,
  ) async {
    final repository = TestLibraryRepository();
    final controller = LibraryController(repository: repository);
    repository.emit(const LibrarySnapshot.empty());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showEntryEditorDialog(context, controller: controller),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('editor-title')), 'Title');
    await tester.enterText(
      find.byKey(const Key('editor-body')),
      '  exact\nbody  ',
    );
    repository.nextFailure = const LibraryFailure.databaseFailure(
      code: LibraryDatabaseFailureCode.transactionFailed,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    expect(
      find.text('The library could not save this change.'),
      findsOneWidget,
    );
    expect(find.text('  exact\nbody  '), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();

    expect(
      repository.getSnapshot().then((value) => value.entries.single.body),
      completion('  exact\nbody  '),
    );
    expect(find.text('New prompt'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  // === Adaptive dialog layout ===

  testWidgets('keeps a full body height on a tall surface', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = TestLibraryRepository();
    final controller = LibraryController(repository: repository);
    addTearDown(() async {
      await controller.dispose();
      await repository.close();
    });
    repository.emit(const LibrarySnapshot.empty());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showEntryEditorDialog(context, controller: controller),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump(const Duration(milliseconds: 400));

    final body = tester.widget<TextField>(find.byKey(const Key('editor-body')));
    expect(body.minLines, 7);
    expect(body.maxLines, 14);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('fits body and tag chips at compact height', (tester) async {
    tester.view.physicalSize = const Size(1000, 620);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = TestLibraryRepository();
    final controller = LibraryController(repository: repository);
    addTearDown(() async {
      await controller.dispose();
      await repository.close();
    });
    repository.emit(LibrarySnapshot(tags: [testTag('tag-1', 'Tag A')]));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showEntryEditorDialog(context, controller: controller),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump(const Duration(milliseconds: 400));

    final body = tester.widget<TextField>(find.byKey(const Key('editor-body')));
    expect(body.minLines, lessThanOrEqualTo(4));
    expect(body.maxLines, lessThanOrEqualTo(8));

    await tester.drag(
      find.byKey(const Key('editor-content')),
      const Offset(0, -600),
    );
    await tester.pump();

    final content = tester.getRect(find.byKey(const Key('editor-content')));
    final chip = tester.getRect(find.widgetWithText(FilterChip, 'Tag A'));
    expect(chip.bottom, lessThanOrEqualTo(content.bottom - 8));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  // === Mutation guards ===

  testWidgets('disables save for an active create mutation', (tester) async {
    final repository = TestLibraryRepository();
    final controller = LibraryController(repository: repository);
    addTearDown(() async {
      await controller.dispose();
      await repository.close();
    });
    repository.emit(const LibrarySnapshot.empty());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    final gate = Completer<void>();
    repository.nextMutationGate = gate;
    final pending = controller.createEntry(
      EntryInput.validate(title: 'Existing create', body: 'Body'),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showEntryEditorDialog(context, controller: controller),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();

    final save = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(find.text('Saving…'), findsOneWidget);
    expect(save.onPressed, isNull);

    gate.complete();
    await pending;
  });

  testWidgets('disables save for an active update mutation', (tester) async {
    final repository = TestLibraryRepository();
    final controller = LibraryController(repository: repository);
    addTearDown(() async {
      await controller.dispose();
      await repository.close();
    });
    final entry = testEntry('entry-1');
    repository.emit(LibrarySnapshot(entries: [entry]));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    final gate = Completer<void>();
    repository.nextMutationGate = gate;
    final pending = controller.updateEntry(
      entry.id,
      EntryInput.validate(title: 'Pending update', body: 'Body'),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showEntryEditorDialog(
              context,
              controller: controller,
              entry: entry,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();

    final save = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(find.text('Saving…'), findsOneWidget);
    expect(save.onPressed, isNull);

    gate.complete();
    await pending;
  });

  // === Shared form lifecycle ===

  testWidgets('defers saving notification after controller replacement', (
    tester,
  ) async {
    final firstRepository = TestLibraryRepository();
    final secondRepository = TestLibraryRepository();
    final firstController = LibraryController(repository: firstRepository);
    final secondController = LibraryController(repository: secondRepository);
    firstRepository.emit(const LibrarySnapshot.empty());
    secondRepository.emit(const LibrarySnapshot.empty());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));

    final gate = Completer<void>();
    secondRepository.nextMutationGate = gate;
    final pending = secondController.createEntry(
      EntryInput.validate(title: 'Pending', body: 'Body'),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));

    final formController = EntryEditorFormController.forEditor(
      controller: firstController,
    );
    final harnessKey = GlobalKey<_EditorFormHarnessState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _EditorFormHarness(
            key: harnessKey,
            controller: firstController,
            formController: formController,
          ),
        ),
      ),
    );

    final errors = <FlutterErrorDetails>[];
    final previousErrorHandler = FlutterError.onError;
    FlutterError.onError = errors.add;
    try {
      harnessKey.currentState!.replaceController(secondController);
      await tester.pump();
    } finally {
      FlutterError.onError = previousErrorHandler;
    }
    final savingState = formController.isSaving;

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    gate.complete();
    await tester.runAsync(() async {
      await pending;
      await firstController.dispose();
      await secondController.dispose();
      await firstRepository.close();
      await secondRepository.close();
    });
    formController.dispose();

    expect(errors, isEmpty);
    expect(savingState, isTrue);
  });

  testWidgets('replaces the complete draft when the edited entry changes', (
    tester,
  ) async {
    final repository = TestLibraryRepository();
    final controller = LibraryController(repository: repository);
    final firstEntry = testEntry(
      'entry-1',
      title: 'First title',
      body: 'First body',
    );
    final secondEntry = testEntry(
      'entry-2',
      title: 'Second title',
      body: 'Second body',
    );
    repository.emit(LibrarySnapshot(entries: [firstEntry, secondEntry]));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));

    final formController = EntryEditorFormController.forEditor(
      controller: controller,
      entry: firstEntry,
    );
    final harnessKey = GlobalKey<_EditorFormHarnessState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _EditorFormHarness(
            key: harnessKey,
            controller: controller,
            formController: formController,
            entry: firstEntry,
          ),
        ),
      ),
    );

    harnessKey.currentState!.replaceEntry(secondEntry);
    await tester.pump();

    expect(tester.takeException(), isNull);
    final title = tester.widget<TextField>(
      find.byKey(const Key('editor-title')),
    );
    final body = tester.widget<TextField>(find.byKey(const Key('editor-body')));
    expect(title.controller!.text, 'Second title');
    expect(body.controller!.text, 'Second body');

    await tester.runAsync(formController.save);
    expect(repository.calls, contains('updateEntry:entry-2'));
    final snapshot = await repository.getSnapshot();
    expect(
      snapshot.entries.singleWhere((entry) => entry.id == 'entry-2').title,
      'Second title',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    formController.dispose();
    await tester.runAsync(() async {
      await controller.dispose();
      await repository.close();
    });
  });
}

/// Hosts replaceable editor inputs.
final class _EditorFormHarness extends StatefulWidget {
  /// Creates editor form harness.
  const _EditorFormHarness({
    required this.controller,
    required this.formController,
    this.entry,
    super.key,
  });

  /// Initial library controller.
  final LibraryController controller;

  /// Shared form controller.
  final EntryEditorFormController formController;

  /// Initial edited entry.
  final Entry? entry;

  /// Creates harness state.
  @override
  State<_EditorFormHarness> createState() => _EditorFormHarnessState();
}

/// Owns replaceable editor inputs.
final class _EditorFormHarnessState extends State<_EditorFormHarness> {
  late LibraryController _controller;
  Entry? _entry;

  /// Initializes editor inputs.
  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _entry = widget.entry;
  }

  /// Replaces the library controller.
  void replaceController(LibraryController controller) {
    setState(() => _controller = controller);
  }

  /// Replaces the edited entry.
  void replaceEntry(Entry entry) {
    setState(() => _entry = entry);
  }

  /// Builds shared editor form.
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.formController,
      builder: (context, _) => EntryEditorForm(
        controller: _controller,
        formController: widget.formController,
        bodySizePolicy: (_) =>
            const EntryEditorBodySize(minLines: 4, maxLines: 8),
        entry: _entry,
        onSaved: () {},
      ),
    );
  }
}

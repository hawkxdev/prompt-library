/// Entry editor dialog tests.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/library/models/library_failure.dart';
import 'package:prompt_library/src/library/models/entry_input.dart';
import 'package:prompt_library/src/library/models/library_snapshot.dart';
import 'package:prompt_library/src/library/presentation/entry_editor_dialog.dart';
import 'package:prompt_library/src/library/presentation/library_controller.dart';

import '../../support/library_test_support.dart';

void main() {
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
}

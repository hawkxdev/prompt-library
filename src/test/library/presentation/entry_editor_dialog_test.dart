/// Entry editor dialog tests.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/library/models/library_failure.dart';
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
}

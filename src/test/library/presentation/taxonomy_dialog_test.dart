/// Taxonomy dialog tests.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/library/models/library_failure.dart';
import 'package:prompt_library/src/library/models/library_snapshot.dart';
import 'package:prompt_library/src/library/presentation/library_controller.dart';
import 'package:prompt_library/src/library/presentation/taxonomy_dialog.dart';

import '../../support/library_test_support.dart';

void main() {
  IconButton actionButton(WidgetTester tester, IconData icon) {
    return tester.widget<IconButton>(find.widgetWithIcon(IconButton, icon));
  }

  testWidgets('renames category through explicit edit action', (tester) async {
    final repository = TestLibraryRepository();
    final controller = LibraryController(repository: repository);
    repository.emit(
      LibrarySnapshot(categories: [testCategory('category-1', 'Old')]),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showTaxonomyDialog(context, controller: controller),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();

    await tester.tap(find.byTooltip('Edit category'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('taxonomy-name')), 'Renamed');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();

    expect(repository.calls, contains('renameCategory:category-1'));
    expect(find.text('Renamed'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Close'));
    await tester.pump(const Duration(seconds: 1));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('retains category draft after create failure', (tester) async {
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
                showTaxonomyDialog(context, controller: controller),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'Draft category');
    repository.nextFailure = const LibraryFailure.databaseFailure(
      code: LibraryDatabaseFailureCode.transactionFailed,
    );

    await tester.tap(find.byTooltip('Add category'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    expect(find.text('Draft category'), findsOneWidget);
    expect(
      find.text('The library could not save this change.'),
      findsOneWidget,
    );
  });

  testWidgets('keeps rename dialog open after failure', (tester) async {
    final repository = TestLibraryRepository();
    final controller = LibraryController(repository: repository);
    addTearDown(() async {
      await controller.dispose();
      await repository.close();
    });
    repository.emit(
      LibrarySnapshot(categories: [testCategory('category-1', 'Old')]),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showTaxonomyDialog(context, controller: controller),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.tap(find.byTooltip('Edit category'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('taxonomy-name')),
      'Draft rename',
    );
    repository.nextFailure = const LibraryFailure.databaseFailure(
      code: LibraryDatabaseFailureCode.transactionFailed,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    expect(find.byKey(const Key('taxonomy-name')), findsOneWidget);
    expect(find.text('Draft rename'), findsOneWidget);
    expect(
      find.text('The library could not save this change.'),
      findsOneWidget,
    );
  });

  testWidgets('disables only an active category create', (tester) async {
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
    final pending = controller.createCategory('Pending');
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showTaxonomyDialog(context, controller: controller),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();

    expect(actionButton(tester, Icons.add).onPressed, isNull);
    gate.complete();
    await pending;
  });

  testWidgets('disables only an active category rename', (tester) async {
    final repository = TestLibraryRepository();
    final controller = LibraryController(repository: repository);
    addTearDown(() async {
      await controller.dispose();
      await repository.close();
    });
    final category = testCategory('category-1', 'Old');
    repository.emit(LibrarySnapshot(categories: [category]));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    final gate = Completer<void>();
    repository.nextMutationGate = gate;
    final pending = controller.renameCategory(category.id, 'Pending');
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showTaxonomyDialog(context, controller: controller),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();

    expect(actionButton(tester, Icons.edit_outlined).onPressed, isNull);
    expect(actionButton(tester, Icons.delete_outline).onPressed, isNotNull);
    gate.complete();
    await pending;
  });

  testWidgets('moves a category down with keyboard control', (tester) async {
    final repository = TestLibraryRepository();
    final controller = LibraryController(repository: repository);
    addTearDown(() async {
      await controller.dispose();
      await repository.close();
    });
    repository.emit(
      LibrarySnapshot(
        categories: [
          testCategory('category-1', 'Category A'),
          testCategory('category-2', 'Category B', sortOrder: 1),
        ],
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showTaxonomyDialog(context, controller: controller),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();

    await tester.tap(find.byTooltip('Move Category A down'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    expect(
      controller.state.snapshot?.categories.map((category) => category.id),
      ['category-2', 'category-1'],
    );
  });
}

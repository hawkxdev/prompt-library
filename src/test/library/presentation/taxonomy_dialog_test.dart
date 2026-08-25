/// Taxonomy dialog tests.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/library/models/library_snapshot.dart';
import 'package:prompt_library/src/library/presentation/library_controller.dart';
import 'package:prompt_library/src/library/presentation/taxonomy_dialog.dart';

import '../../support/library_test_support.dart';

void main() {
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
}

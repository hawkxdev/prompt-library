/// Integrated acceptance over real Drift and production controllers.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:prompt_library/src/library/data/drift_library_repository.dart';
import 'package:prompt_library/src/library/data/library_database.dart';
import 'package:prompt_library/src/library/models/entry_input.dart';
import 'package:prompt_library/src/library/presentation/library_controller.dart';
import 'package:prompt_library/src/library/presentation/library_filter.dart';
import 'package:prompt_library/src/library/presentation/library_state.dart';

void main() {
  test(
    'real Drift and controllers preserve the release journey across reopen',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'prompt_library_acceptance_',
      );
      final databaseFile = File(
        p.join(tempDirectory.path, 'prompt_library_acceptance.sqlite'),
      );
      final identifiers = <String>[
        'acceptance-category',
        'acceptance-tag',
        'acceptance-entry-primary',
        'acceptance-entry-secondary',
      ].iterator;
      var currentTime = DateTime.utc(2026, 8, 30, 12);

      String nextIdentifier() {
        if (!identifiers.moveNext()) {
          throw StateError('Acceptance identifier fixture exhausted');
        }
        return identifiers.current;
      }

      LibraryDatabase? database;
      LibraryController? controller;

      Future<void> closeGraph() async {
        final activeController = controller;
        controller = null;
        await activeController?.dispose();
        final activeDatabase = database;
        database = null;
        await activeDatabase?.close();
      }

      try {
        database = LibraryDatabase.forTesting(NativeDatabase(databaseFile));
        final repository = DriftLibraryRepository(
          database!,
          uuidGenerator: nextIdentifier,
          clock: () => currentTime,
        );
        controller = LibraryController(repository: repository);

        await _waitForState(
          controller!,
          (state) =>
              state.loadStatus == LibraryLoadStatus.ready &&
              state.snapshot?.entries.isEmpty == true,
        );

        await controller!.createCategory('  Operations  ');
        await _waitForState(
          controller!,
          (state) => state.snapshot?.categories.length == 1,
        );
        final categoryId = controller!.state.snapshot!.categories.single.id;

        await controller!.createTag('  Launch  ');
        await _waitForState(
          controller!,
          (state) => state.snapshot?.tags.length == 1,
        );
        final tagId = controller!.state.snapshot!.tags.single.id;

        const exactBody =
            '  First acceptance line\n\n'
            'Second acceptance line  ';
        await controller!.createEntry(
          EntryInput.validate(
            title: 'Release Checklist',
            body: exactBody,
            keyword: 'готовность',
            categoryId: categoryId,
            tagIds: [tagId],
          ),
        );
        currentTime = DateTime.utc(2026, 8, 30, 12, 1);
        await controller!.createEntry(
          EntryInput.validate(
            title: 'Secondary Prompt',
            body: 'Secondary body',
          ),
        );
        await _waitForState(
          controller!,
          (state) => state.snapshot?.entries.length == 2,
        );

        expect(controller!.state.visibleEntries.map((entry) => entry.id), [
          'acceptance-entry-secondary',
          'acceptance-entry-primary',
        ]);

        controller!.updateSearchQuery('ГОТОВНОСТЬ');
        expect(
          controller!.state.visibleEntries.single.id,
          'acceptance-entry-primary',
        );
        controller!.updateSearchQuery('');

        currentTime = DateTime.utc(2026, 8, 30, 12, 2);
        await controller!.markCopied('acceptance-entry-primary');
        await _waitForState(
          controller!,
          (state) =>
              state.snapshot?.entries.any(
                (entry) =>
                    entry.id == 'acceptance-entry-primary' &&
                    entry.lastCopiedAt == currentTime,
              ) ==
              true,
        );
        expect(
          controller!.state.visibleEntries.first.id,
          'acceptance-entry-primary',
        );

        currentTime = DateTime.utc(2026, 8, 30, 12, 3);
        await controller!.updateEntry(
          'acceptance-entry-primary',
          EntryInput.validate(
            title: 'Release Checklist Updated',
            body: exactBody,
            keyword: 'готовность',
            categoryId: categoryId,
            tagIds: [tagId],
          ),
        );
        await controller!.setFavorite(
          'acceptance-entry-primary',
          isFavorite: true,
        );
        currentTime = DateTime.utc(2026, 8, 30, 12, 4);
        await controller!.setArchived(
          'acceptance-entry-secondary',
          isArchived: true,
        );
        await _waitForState(
          controller!,
          (state) =>
              state.snapshot?.entries.any(
                (entry) =>
                    entry.id == 'acceptance-entry-secondary' &&
                    entry.isArchived,
              ) ==
              true,
        );

        expect(controller!.state.visibleEntries.map((entry) => entry.id), [
          'acceptance-entry-primary',
        ]);
        controller!.setFilterScope(LibraryFilterScope.archived);
        expect(
          controller!.state.visibleEntries.single.id,
          'acceptance-entry-secondary',
        );

        await closeGraph();

        database = LibraryDatabase.forTesting(NativeDatabase(databaseFile));
        controller = LibraryController(
          repository: DriftLibraryRepository(database!),
        );
        final reopened = await _waitForState(
          controller!,
          (state) => state.snapshot?.entries.length == 2,
        );

        final primary = reopened.snapshot!.entries.firstWhere(
          (entry) => entry.id == 'acceptance-entry-primary',
        );
        expect(primary.title, 'Release Checklist Updated');
        expect(primary.body, exactBody);
        expect(primary.keyword, 'готовность');
        expect(primary.categoryId, categoryId);
        expect(primary.tagIds, [tagId]);
        expect(primary.isFavorite, isTrue);
        expect(primary.lastCopiedAt, DateTime.utc(2026, 8, 30, 12, 2));
        expect(
          reopened.snapshot!.entries
              .firstWhere((entry) => entry.id == 'acceptance-entry-secondary')
              .isArchived,
          isTrue,
        );
        expect(reopened.snapshot!.categories.single.name, 'Operations');
        expect(reopened.snapshot!.tags.single.name, 'Launch');

        controller!.updateSearchQuery('operations');
        expect(
          controller!.state.visibleEntries.single.id,
          'acceptance-entry-primary',
        );
        controller!.updateSearchQuery('launch');
        expect(
          controller!.state.visibleEntries.single.id,
          'acceptance-entry-primary',
        );
        controller!.updateSearchQuery('');

        await controller!.deleteEntry('acceptance-entry-primary');
        await controller!.deleteEntry('acceptance-entry-secondary');
        await controller!.deleteTag(tagId);
        await controller!.deleteCategory(categoryId);
        await _waitForState(
          controller!,
          (state) =>
              state.snapshot?.entries.isEmpty == true &&
              state.snapshot?.categories.isEmpty == true &&
              state.snapshot?.tags.isEmpty == true,
        );

        await closeGraph();

        database = LibraryDatabase.forTesting(NativeDatabase(databaseFile));
        final finalSnapshot = await DriftLibraryRepository(database!)
            .getSnapshot();
        expect(finalSnapshot.entries, isEmpty);
        expect(finalSnapshot.categories, isEmpty);
        expect(finalSnapshot.tags, isEmpty);
      } finally {
        await closeGraph();
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      }
    },
  );
}

Future<LibraryState> _waitForState(
  LibraryController controller,
  bool Function(LibraryState state) predicate,
) {
  final current = controller.state;
  if (predicate(current)) {
    return Future.value(current);
  }
  return controller.states
      .firstWhere(predicate)
      .timeout(const Duration(seconds: 5));
}

/// Domain entity model tests.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/library/models/category.dart';
import 'package:prompt_library/src/library/models/entry.dart';
import 'package:prompt_library/src/library/models/tag.dart';

void main() {
  // === Category model tests ===
  group('Category', () {
    final utcCreatedAt = DateTime.utc(2026, 8, 24, 12, 0, 0);

    test('instantiates with all required fields', () {
      final category = Category(
        id: 'cat-1',
        name: 'Workflows',
        normalizedName: 'workflows',
        sortOrder: 1,
        createdAt: utcCreatedAt,
      );

      expect(category.id, 'cat-1');
      expect(category.name, 'Workflows');
      expect(category.normalizedName, 'workflows');
      expect(category.sortOrder, 1);
      expect(category.createdAt, utcCreatedAt);
      expect(category.createdAt.isUtc, isTrue);
    });

    test('converts non-UTC createdAt to UTC', () {
      final localCreatedAt = DateTime(2026, 8, 24, 15, 30, 0);
      final category = Category(
        id: 'cat-2',
        name: 'Engineering',
        normalizedName: 'engineering',
        sortOrder: 2,
        createdAt: localCreatedAt,
      );

      expect(category.createdAt.isUtc, isTrue);
      expect(category.createdAt, localCreatedAt.toUtc());
    });

    test('preserves already UTC createdAt without modification', () {
      final category = Category(
        id: 'cat-3',
        name: 'Personal',
        normalizedName: 'personal',
        sortOrder: 3,
        createdAt: utcCreatedAt,
      );

      expect(category.createdAt.isUtc, isTrue);
      expect(category.createdAt, utcCreatedAt);
    });

    test('supports value equality and hashCode consistency', () {
      final catA = Category(
        id: 'cat-1',
        name: 'Workflows',
        normalizedName: 'workflows',
        sortOrder: 1,
        createdAt: utcCreatedAt,
      );
      final catB = Category(
        id: 'cat-1',
        name: 'Workflows',
        normalizedName: 'workflows',
        sortOrder: 1,
        createdAt: utcCreatedAt,
      );
      final catDifferentOrder = Category(
        id: 'cat-1',
        name: 'Workflows',
        normalizedName: 'workflows',
        sortOrder: 2,
        createdAt: utcCreatedAt,
      );

      expect(catA, equals(catB));
      expect(catA.hashCode, equals(catB.hashCode));
      expect(catA, isNot(equals(catDifferentOrder)));
    });

    test('supports copyWith changing one field while preserving others', () {
      final original = Category(
        id: 'cat-1',
        name: 'Workflows',
        normalizedName: 'workflows',
        sortOrder: 1,
        createdAt: utcCreatedAt,
      );

      final updatedId = original.copyWith(id: 'cat-99');
      expect(updatedId.id, 'cat-99');
      expect(updatedId.name, 'Workflows');
      expect(updatedId.normalizedName, 'workflows');
      expect(updatedId.sortOrder, 1);
      expect(updatedId.createdAt, utcCreatedAt);

      final updatedName = original.copyWith(name: 'New Name');
      expect(updatedName.id, 'cat-1');
      expect(updatedName.name, 'New Name');
      expect(updatedName.normalizedName, 'workflows');
      expect(updatedName.sortOrder, 1);
      expect(updatedName.createdAt, utcCreatedAt);

      final updatedNormalized = original.copyWith(normalizedName: 'new name');
      expect(updatedNormalized.id, 'cat-1');
      expect(updatedNormalized.name, 'Workflows');
      expect(updatedNormalized.normalizedName, 'new name');
      expect(updatedNormalized.sortOrder, 1);
      expect(updatedNormalized.createdAt, utcCreatedAt);

      final updatedOrder = original.copyWith(sortOrder: 42);
      expect(updatedOrder.id, 'cat-1');
      expect(updatedOrder.name, 'Workflows');
      expect(updatedOrder.normalizedName, 'workflows');
      expect(updatedOrder.sortOrder, 42);
      expect(updatedOrder.createdAt, utcCreatedAt);

      final newTime = DateTime.utc(2026, 8, 25, 0, 0, 0);
      final updatedCreatedAt = original.copyWith(createdAt: newTime);
      expect(updatedCreatedAt.id, 'cat-1');
      expect(updatedCreatedAt.name, 'Workflows');
      expect(updatedCreatedAt.normalizedName, 'workflows');
      expect(updatedCreatedAt.sortOrder, 1);
      expect(updatedCreatedAt.createdAt, newTime);
    });

    test('copyWith converts non-UTC replacement createdAt to UTC', () {
      final original = Category(
        id: 'cat-1',
        name: 'Workflows',
        normalizedName: 'workflows',
        sortOrder: 1,
        createdAt: utcCreatedAt,
      );
      final localTime = DateTime(2026, 8, 25, 9, 0, 0);
      final updated = original.copyWith(createdAt: localTime);

      expect(updated.createdAt.isUtc, isTrue);
      expect(updated.createdAt, localTime.toUtc());
    });
  });

  // === Tag model tests ===
  group('Tag', () {
    final utcCreatedAt = DateTime.utc(2026, 8, 24, 12, 0, 0);

    test('instantiates with all required fields', () {
      final tag = Tag(
        id: 'tag-1',
        name: 'Dart',
        normalizedName: 'dart',
        createdAt: utcCreatedAt,
      );

      expect(tag.id, 'tag-1');
      expect(tag.name, 'Dart');
      expect(tag.normalizedName, 'dart');
      expect(tag.createdAt, utcCreatedAt);
      expect(tag.createdAt.isUtc, isTrue);
    });

    test('converts non-UTC createdAt to UTC', () {
      final localCreatedAt = DateTime(2026, 8, 24, 18, 0, 0);
      final tag = Tag(
        id: 'tag-2',
        name: 'Flutter',
        normalizedName: 'flutter',
        createdAt: localCreatedAt,
      );

      expect(tag.createdAt.isUtc, isTrue);
      expect(tag.createdAt, localCreatedAt.toUtc());
    });

    test('preserves already UTC createdAt without modification', () {
      final tag = Tag(
        id: 'tag-3',
        name: 'Mac',
        normalizedName: 'mac',
        createdAt: utcCreatedAt,
      );

      expect(tag.createdAt.isUtc, isTrue);
      expect(tag.createdAt, utcCreatedAt);
    });

    test('supports value equality and hashCode consistency', () {
      final tagA = Tag(
        id: 'tag-1',
        name: 'Dart',
        normalizedName: 'dart',
        createdAt: utcCreatedAt,
      );
      final tagB = Tag(
        id: 'tag-1',
        name: 'Dart',
        normalizedName: 'dart',
        createdAt: utcCreatedAt,
      );
      final tagDifferentName = Tag(
        id: 'tag-1',
        name: 'Python',
        normalizedName: 'dart',
        createdAt: utcCreatedAt,
      );

      expect(tagA, equals(tagB));
      expect(tagA.hashCode, equals(tagB.hashCode));
      expect(tagA, isNot(equals(tagDifferentName)));
    });

    test('supports copyWith changing one field while preserving others', () {
      final original = Tag(
        id: 'tag-1',
        name: 'Dart',
        normalizedName: 'dart',
        createdAt: utcCreatedAt,
      );

      final updatedId = original.copyWith(id: 'tag-99');
      expect(updatedId.id, 'tag-99');
      expect(updatedId.name, 'Dart');
      expect(updatedId.normalizedName, 'dart');
      expect(updatedId.createdAt, utcCreatedAt);

      final updatedName = original.copyWith(name: 'Flutter');
      expect(updatedName.id, 'tag-1');
      expect(updatedName.name, 'Flutter');
      expect(updatedName.normalizedName, 'dart');
      expect(updatedName.createdAt, utcCreatedAt);

      final updatedNormalized = original.copyWith(normalizedName: 'flutter');
      expect(updatedNormalized.id, 'tag-1');
      expect(updatedNormalized.name, 'Dart');
      expect(updatedNormalized.normalizedName, 'flutter');
      expect(updatedNormalized.createdAt, utcCreatedAt);

      final newTime = DateTime.utc(2026, 8, 25, 1, 1, 1);
      final updatedCreatedAt = original.copyWith(createdAt: newTime);
      expect(updatedCreatedAt.id, 'tag-1');
      expect(updatedCreatedAt.name, 'Dart');
      expect(updatedCreatedAt.normalizedName, 'dart');
      expect(updatedCreatedAt.createdAt, newTime);
    });

    test('copyWith converts non-UTC replacement createdAt to UTC', () {
      final original = Tag(
        id: 'tag-1',
        name: 'Dart',
        normalizedName: 'dart',
        createdAt: utcCreatedAt,
      );
      final localTime = DateTime(2026, 8, 25, 20, 0, 0);
      final updated = original.copyWith(createdAt: localTime);

      expect(updated.createdAt.isUtc, isTrue);
      expect(updated.createdAt, localTime.toUtc());
    });
  });

  // === Entry model tests ===
  group('Entry', () {
    final utcCreatedAt = DateTime.utc(2026, 8, 24, 10, 0, 0);
    final utcUpdatedAt = DateTime.utc(2026, 8, 24, 11, 0, 0);
    final utcLastCopiedAt = DateTime.utc(2026, 8, 24, 12, 0, 0);

    test('instantiates with all fields and normalizes timestamps to UTC', () {
      final entry = Entry(
        id: 'entry-1',
        title: 'System Architect Prompt',
        body: 'Act as a principal system architect.\nAnalyze trade-offs.',
        keyword: 'sys-arch',
        categoryId: 'cat-1',
        tagIds: ['tag-b', 'tag-a'],
        isFavorite: true,
        isArchived: false,
        createdAt: utcCreatedAt,
        updatedAt: utcUpdatedAt,
        lastCopiedAt: utcLastCopiedAt,
      );

      expect(entry.id, 'entry-1');
      expect(entry.title, 'System Architect Prompt');
      expect(
        entry.body,
        'Act as a principal system architect.\nAnalyze trade-offs.',
      );
      expect(entry.keyword, 'sys-arch');
      expect(entry.categoryId, 'cat-1');
      expect(entry.tagIds, ['tag-a', 'tag-b']);
      expect(entry.isFavorite, isTrue);
      expect(entry.isArchived, isFalse);
      expect(entry.createdAt, utcCreatedAt);
      expect(entry.createdAt.isUtc, isTrue);
      expect(entry.updatedAt, utcUpdatedAt);
      expect(entry.updatedAt.isUtc, isTrue);
      expect(entry.lastCopiedAt, utcLastCopiedAt);
      expect(entry.lastCopiedAt!.isUtc, isTrue);
    });

    test(
      'instantiates with nullable fields omitted/null and default flags',
      () {
        final entry = Entry(
          id: 'entry-2',
          title: 'Minimal Prompt',
          body: 'Minimal body text',
          createdAt: utcCreatedAt,
          updatedAt: utcUpdatedAt,
        );

        expect(entry.id, 'entry-2');
        expect(entry.title, 'Minimal Prompt');
        expect(entry.body, 'Minimal body text');
        expect(entry.keyword, isNull);
        expect(entry.categoryId, isNull);
        expect(entry.tagIds, isEmpty);
        expect(entry.isFavorite, isFalse);
        expect(entry.isArchived, isFalse);
        expect(entry.lastCopiedAt, isNull);
      },
    );

    test('converts non-UTC timestamps to UTC', () {
      final localCreated = DateTime(2026, 8, 24, 8, 30, 0);
      final localUpdated = DateTime(2026, 8, 24, 9, 30, 0);
      final localCopied = DateTime(2026, 8, 24, 10, 30, 0);

      final entry = Entry(
        id: 'entry-3',
        title: 'Local Time Prompt',
        body: 'Body',
        createdAt: localCreated,
        updatedAt: localUpdated,
        lastCopiedAt: localCopied,
      );

      expect(entry.createdAt.isUtc, isTrue);
      expect(entry.createdAt, localCreated.toUtc());
      expect(entry.updatedAt.isUtc, isTrue);
      expect(entry.updatedAt, localUpdated.toUtc());
      expect(entry.lastCopiedAt!.isUtc, isTrue);
      expect(entry.lastCopiedAt, localCopied.toUtc());
    });

    test('preserves already UTC timestamps without modification', () {
      final entry = Entry(
        id: 'entry-4',
        title: 'UTC Prompt',
        body: 'Body',
        createdAt: utcCreatedAt,
        updatedAt: utcUpdatedAt,
        lastCopiedAt: utcLastCopiedAt,
      );

      expect(entry.createdAt.isUtc, isTrue);
      expect(entry.createdAt, utcCreatedAt);
      expect(entry.updatedAt.isUtc, isTrue);
      expect(entry.updatedAt, utcUpdatedAt);
      expect(entry.lastCopiedAt!.isUtc, isTrue);
      expect(entry.lastCopiedAt, utcLastCopiedAt);
    });

    test('tagIds are deduplicated and sorted deterministically', () {
      final entry = Entry(
        id: 'entry-5',
        title: 'Sorted Tags Prompt',
        body: 'Body',
        tagIds: ['tag-z', 'tag-a', 'tag-m', 'tag-a', 'tag-z', 'tag-b'],
        createdAt: utcCreatedAt,
        updatedAt: utcUpdatedAt,
      );

      expect(entry.tagIds, ['tag-a', 'tag-b', 'tag-m', 'tag-z']);
    });

    test('tagIds list is unmodifiable and decoupled from input collection', () {
      final mutableInput = <String>['tag-2', 'tag-1'];
      final entry = Entry(
        id: 'entry-6',
        title: 'Immutable Tags Prompt',
        body: 'Body',
        tagIds: mutableInput,
        createdAt: utcCreatedAt,
        updatedAt: utcUpdatedAt,
      );

      expect(entry.tagIds, ['tag-1', 'tag-2']);

      mutableInput.add('tag-3');
      expect(entry.tagIds, [
        'tag-1',
        'tag-2',
      ], reason: 'Mutating input list must not affect Entry.tagIds');

      expect(() => entry.tagIds.add('tag-4'), throwsA(isA<UnsupportedError>()));
      expect(() => entry.tagIds.removeAt(0), throwsA(isA<UnsupportedError>()));
    });

    test(
      'supports value equality and hashCode independent of input tag order',
      () {
        final entryA = Entry(
          id: 'entry-1',
          title: 'Title',
          body: 'Body',
          keyword: 'key',
          categoryId: 'cat-1',
          tagIds: ['tag-2', 'tag-1', 'tag-2'],
          isFavorite: true,
          isArchived: false,
          createdAt: utcCreatedAt,
          updatedAt: utcUpdatedAt,
          lastCopiedAt: utcLastCopiedAt,
        );

        final entryB = Entry(
          id: 'entry-1',
          title: 'Title',
          body: 'Body',
          keyword: 'key',
          categoryId: 'cat-1',
          tagIds: ['tag-1', 'tag-2'],
          isFavorite: true,
          isArchived: false,
          createdAt: utcCreatedAt,
          updatedAt: utcUpdatedAt,
          lastCopiedAt: utcLastCopiedAt,
        );

        expect(entryA, equals(entryB));
        expect(entryA.hashCode, equals(entryB.hashCode));

        final diffId = entryA.copyWith(id: 'entry-99');
        final diffTitle = entryA.copyWith(title: 'Other Title');
        final diffBody = entryA.copyWith(body: 'Other Body');
        final diffKeyword = entryA.copyWith(keyword: 'other-key');
        final diffCategory = entryA.copyWith(categoryId: 'cat-2');
        final diffTags = entryA.copyWith(tagIds: ['tag-1']);
        final diffFav = entryA.copyWith(isFavorite: false);
        final diffArchived = entryA.copyWith(isArchived: true);
        final diffCreated = entryA.copyWith(
          createdAt: DateTime.utc(2025, 1, 1),
        );
        final diffUpdated = entryA.copyWith(
          updatedAt: DateTime.utc(2025, 1, 2),
        );
        final diffCopied = entryA.copyWith(
          lastCopiedAt: DateTime.utc(2025, 1, 3),
        );

        expect(entryA, isNot(equals(diffId)));
        expect(entryA, isNot(equals(diffTitle)));
        expect(entryA, isNot(equals(diffBody)));
        expect(entryA, isNot(equals(diffKeyword)));
        expect(entryA, isNot(equals(diffCategory)));
        expect(entryA, isNot(equals(diffTags)));
        expect(entryA, isNot(equals(diffFav)));
        expect(entryA, isNot(equals(diffArchived)));
        expect(entryA, isNot(equals(diffCreated)));
        expect(entryA, isNot(equals(diffUpdated)));
        expect(entryA, isNot(equals(diffCopied)));
      },
    );

    test(
      'supports copyWith preserving all fields when no arguments passed',
      () {
        final original = Entry(
          id: 'entry-1',
          title: 'Title',
          body: 'Body',
          keyword: 'key',
          categoryId: 'cat-1',
          tagIds: ['tag-1', 'tag-2'],
          isFavorite: true,
          isArchived: false,
          createdAt: utcCreatedAt,
          updatedAt: utcUpdatedAt,
          lastCopiedAt: utcLastCopiedAt,
        );

        final copy = original.copyWith();
        expect(copy, equals(original));
        expect(copy.hashCode, equals(original.hashCode));
        expect(copy.id, original.id);
        expect(copy.title, original.title);
        expect(copy.body, original.body);
        expect(copy.keyword, original.keyword);
        expect(copy.categoryId, original.categoryId);
        expect(copy.tagIds, original.tagIds);
        expect(copy.isFavorite, original.isFavorite);
        expect(copy.isArchived, original.isArchived);
        expect(copy.createdAt, original.createdAt);
        expect(copy.updatedAt, original.updatedAt);
        expect(copy.lastCopiedAt, original.lastCopiedAt);
      },
    );

    test(
      'supports copyWith changing individual fields while preserving others',
      () {
        final original = Entry(
          id: 'entry-1',
          title: 'Title',
          body: 'Body',
          keyword: 'key',
          categoryId: 'cat-1',
          tagIds: ['tag-1', 'tag-2'],
          isFavorite: false,
          isArchived: false,
          createdAt: utcCreatedAt,
          updatedAt: utcUpdatedAt,
          lastCopiedAt: utcLastCopiedAt,
        );

        final updatedId = original.copyWith(id: 'entry-2');
        expect(updatedId.id, 'entry-2');
        expect(updatedId.title, 'Title');

        final updatedTitle = original.copyWith(title: 'New Title');
        expect(updatedTitle.title, 'New Title');
        expect(updatedTitle.id, 'entry-1');

        final updatedBody = original.copyWith(body: 'New Body');
        expect(updatedBody.body, 'New Body');

        final updatedKeyword = original.copyWith(keyword: 'new-key');
        expect(updatedKeyword.keyword, 'new-key');

        final updatedCategory = original.copyWith(categoryId: 'cat-9');
        expect(updatedCategory.categoryId, 'cat-9');

        final updatedTags = original.copyWith(tagIds: ['tag-z', 'tag-a']);
        expect(updatedTags.tagIds, ['tag-a', 'tag-z']);

        final updatedFav = original.copyWith(isFavorite: true);
        expect(updatedFav.isFavorite, isTrue);

        final updatedArchived = original.copyWith(isArchived: true);
        expect(updatedArchived.isArchived, isTrue);

        final newCreated = DateTime.utc(2026, 9, 1);
        final updatedCreated = original.copyWith(createdAt: newCreated);
        expect(updatedCreated.createdAt, newCreated);

        final newUpdated = DateTime.utc(2026, 9, 2);
        final updatedUpdated = original.copyWith(updatedAt: newUpdated);
        expect(updatedUpdated.updatedAt, newUpdated);

        final newCopied = DateTime.utc(2026, 9, 3);
        final updatedCopied = original.copyWith(lastCopiedAt: newCopied);
        expect(updatedCopied.lastCopiedAt, newCopied);
      },
    );

    test('copyWith explicitly clears nullable fields when passed null', () {
      final original = Entry(
        id: 'entry-1',
        title: 'Title',
        body: 'Body',
        keyword: 'key',
        categoryId: 'cat-1',
        tagIds: ['tag-1'],
        isFavorite: true,
        isArchived: false,
        createdAt: utcCreatedAt,
        updatedAt: utcUpdatedAt,
        lastCopiedAt: utcLastCopiedAt,
      );

      final clearedKeyword = original.copyWith(keyword: null);
      expect(clearedKeyword.keyword, isNull);
      expect(clearedKeyword.categoryId, 'cat-1');
      expect(clearedKeyword.lastCopiedAt, utcLastCopiedAt);

      final clearedCategory = original.copyWith(categoryId: null);
      expect(clearedCategory.keyword, 'key');
      expect(clearedCategory.categoryId, isNull);
      expect(clearedCategory.lastCopiedAt, utcLastCopiedAt);

      final clearedCopied = original.copyWith(lastCopiedAt: null);
      expect(clearedCopied.keyword, 'key');
      expect(clearedCopied.categoryId, 'cat-1');
      expect(clearedCopied.lastCopiedAt, isNull);

      final clearedAllNullable = original.copyWith(
        keyword: null,
        categoryId: null,
        lastCopiedAt: null,
      );
      expect(clearedAllNullable.keyword, isNull);
      expect(clearedAllNullable.categoryId, isNull);
      expect(clearedAllNullable.lastCopiedAt, isNull);
      expect(clearedAllNullable.id, 'entry-1');
      expect(clearedAllNullable.title, 'Title');
      expect(clearedAllNullable.body, 'Body');
      expect(clearedAllNullable.tagIds, ['tag-1']);
      expect(clearedAllNullable.isFavorite, isTrue);
      expect(clearedAllNullable.isArchived, isFalse);
      expect(clearedAllNullable.createdAt, utcCreatedAt);
      expect(clearedAllNullable.updatedAt, utcUpdatedAt);
    });

    test('copyWith converts non-UTC replacement timestamps to UTC', () {
      final original = Entry(
        id: 'entry-1',
        title: 'Title',
        body: 'Body',
        createdAt: utcCreatedAt,
        updatedAt: utcUpdatedAt,
      );

      final localCreated = DateTime(2026, 9, 1, 10, 0, 0);
      final localUpdated = DateTime(2026, 9, 1, 11, 0, 0);
      final localCopied = DateTime(2026, 9, 1, 12, 0, 0);

      final updated = original.copyWith(
        createdAt: localCreated,
        updatedAt: localUpdated,
        lastCopiedAt: localCopied,
      );

      expect(updated.createdAt.isUtc, isTrue);
      expect(updated.createdAt, localCreated.toUtc());
      expect(updated.updatedAt.isUtc, isTrue);
      expect(updated.updatedAt, localUpdated.toUtc());
      expect(updated.lastCopiedAt!.isUtc, isTrue);
      expect(updated.lastCopiedAt, localCopied.toUtc());
    });
  });
}

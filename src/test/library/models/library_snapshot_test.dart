/// Library snapshot model tests.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/library/models/category.dart';
import 'package:prompt_library/src/library/models/entry.dart';
import 'package:prompt_library/src/library/models/library_snapshot.dart';
import 'package:prompt_library/src/library/models/tag.dart';

void main() {
  final testDate = DateTime.utc(2026, 8, 24, 10, 0, 0);

  Category makeCategory({
    required String id,
    required String name,
    required String normalizedName,
    int sortOrder = 0,
  }) {
    return Category(
      id: id,
      name: name,
      normalizedName: normalizedName,
      sortOrder: sortOrder,
      createdAt: testDate,
    );
  }

  Tag makeTag({
    required String id,
    required String name,
    required String normalizedName,
  }) {
    return Tag(
      id: id,
      name: name,
      normalizedName: normalizedName,
      createdAt: testDate,
    );
  }

  Entry makeEntry({
    required String id,
    String title = 'Title',
    String body = 'Body',
    String? categoryId,
    Iterable<String> tagIds = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Entry(
      id: id,
      title: title,
      body: body,
      categoryId: categoryId,
      tagIds: tagIds,
      createdAt: createdAt ?? testDate,
      updatedAt: updatedAt ?? testDate,
    );
  }

  group('LibrarySnapshot', () {
    test('empty snapshot produces empty collections and lookup maps', () {
      const emptyConst = LibrarySnapshot.empty();
      expect(emptyConst.entries, isEmpty);
      expect(emptyConst.categories, isEmpty);
      expect(emptyConst.tags, isEmpty);
      expect(emptyConst.categoryById, isEmpty);
      expect(emptyConst.tagById, isEmpty);
      expect(emptyConst.tagsForEntry, isEmpty);

      final emptyDefault = LibrarySnapshot();
      expect(emptyDefault.entries, isEmpty);
      expect(emptyDefault.categories, isEmpty);
      expect(emptyDefault.tags, isEmpty);
      expect(emptyDefault.categoryById, isEmpty);
      expect(emptyDefault.tagById, isEmpty);
      expect(emptyDefault.tagsForEntry, isEmpty);

      expect(emptyDefault, equals(emptyConst));
      expect(emptyDefault.hashCode, equals(emptyConst.hashCode));
    });

    test('input lists are defensively copied and unmodifiable', () {
      final mutableEntries = [makeEntry(id: 'entry-1')];
      final mutableCategories = [
        makeCategory(id: 'cat-1', name: 'Work', normalizedName: 'work'),
      ];
      final mutableTags = [
        makeTag(id: 'tag-1', name: 'Dart', normalizedName: 'dart'),
      ];

      final snapshot = LibrarySnapshot(
        entries: mutableEntries,
        categories: mutableCategories,
        tags: mutableTags,
      );

      mutableEntries.add(makeEntry(id: 'entry-2'));
      mutableCategories.add(
        makeCategory(id: 'cat-2', name: 'Life', normalizedName: 'life'),
      );
      mutableTags.add(
        makeTag(id: 'tag-2', name: 'Flutter', normalizedName: 'flutter'),
      );

      expect(snapshot.entries, hasLength(1));
      expect(snapshot.entries.first.id, equals('entry-1'));
      expect(snapshot.categories, hasLength(1));
      expect(snapshot.categories.first.id, equals('cat-1'));
      expect(snapshot.tags, hasLength(1));
      expect(snapshot.tags.first.id, equals('tag-1'));

      expect(
        () => (snapshot.entries as dynamic).add(makeEntry(id: 'entry-3')),
        throwsUnsupportedError,
      );
      expect(
        () => (snapshot.categories as dynamic).add(
          makeCategory(id: 'cat-3', name: 'Study', normalizedName: 'study'),
        ),
        throwsUnsupportedError,
      );
      expect(
        () => (snapshot.tags as dynamic).add(
          makeTag(id: 'tag-3', name: 'Rust', normalizedName: 'rust'),
        ),
        throwsUnsupportedError,
      );
      expect(
        () => (snapshot.categoryById as dynamic)['cat-99'] = makeCategory(
          id: 'cat-99',
          name: 'Other',
          normalizedName: 'other',
        ),
        throwsUnsupportedError,
      );
      expect(
        () => (snapshot.tagById as dynamic)['tag-99'] = makeTag(
          id: 'tag-99',
          name: 'Other',
          normalizedName: 'other',
        ),
        throwsUnsupportedError,
      );
      expect(
        () => (snapshot.tagsForEntry as dynamic)['entry-99'] = <Tag>[],
        throwsUnsupportedError,
      );
      expect(
        () => (snapshot.tagsForEntry['entry-1'] as dynamic).add(
          makeTag(id: 'tag-99', name: 'Other', normalizedName: 'other'),
        ),
        throwsUnsupportedError,
      );
    });

    test('sorts entries deterministically by updatedAt DESC then id DESC', () {
      final time10 = DateTime.utc(2026, 8, 24, 10, 0, 0);
      final time12 = DateTime.utc(2026, 8, 24, 12, 0, 0);
      final time14 = DateTime.utc(2026, 8, 24, 14, 0, 0);

      final entryOldA = makeEntry(id: 'entry-a', updatedAt: time10);
      final entryOldZ = makeEntry(id: 'entry-z', updatedAt: time10);
      final entryMidB = makeEntry(id: 'entry-b', updatedAt: time12);
      final entryMidM = makeEntry(id: 'entry-m', updatedAt: time12);
      final entryNewX = makeEntry(id: 'entry-x', updatedAt: time14);

      final snapshot = LibrarySnapshot(
        entries: [entryOldA, entryMidB, entryOldZ, entryNewX, entryMidM],
      );

      expect(
        snapshot.entries.map((e) => e.id).toList(),
        equals(['entry-x', 'entry-m', 'entry-b', 'entry-z', 'entry-a']),
      );
    });

    test('sorts categories deterministically by sortOrder then id', () {
      final cat1 = makeCategory(
        id: 'cat-z',
        name: 'Alpha Z',
        normalizedName: 'alpha first',
        sortOrder: 1,
      );
      final cat2 = makeCategory(
        id: 'cat-a',
        name: 'Alpha A',
        normalizedName: 'zeta last',
        sortOrder: 1,
      );
      final cat3 = makeCategory(
        id: 'cat-0-b',
        name: 'Beta',
        normalizedName: 'beta',
        sortOrder: 0,
      );
      final cat4 = makeCategory(
        id: 'cat-0-a',
        name: 'Alpha',
        normalizedName: 'alpha',
        sortOrder: 0,
      );
      final cat5 = makeCategory(
        id: 'cat-0-a2',
        name: 'Alpha duplicate',
        normalizedName: 'alpha',
        sortOrder: 0,
      );

      final snapshot = LibrarySnapshot(
        categories: [cat1, cat2, cat3, cat4, cat5],
      );

      expect(
        snapshot.categories.map((c) => c.id).toList(),
        equals(['cat-0-a', 'cat-0-a2', 'cat-0-b', 'cat-a', 'cat-z']),
      );
    });

    test('sorts tags deterministically by name then id', () {
      final tagZ = makeTag(id: 'tag-3', name: 'Alpha', normalizedName: 'zeta');
      final tagB = makeTag(id: 'tag-2', name: 'Zulu', normalizedName: 'beta');
      final tagA2 = makeTag(
        id: 'tag-1b',
        name: 'Middle 2',
        normalizedName: 'alpha',
      );
      final tagA1 = makeTag(
        id: 'tag-1a',
        name: 'Middle 1',
        normalizedName: 'alpha',
      );

      final snapshot = LibrarySnapshot(tags: [tagZ, tagB, tagA2, tagA1]);

      expect(
        snapshot.tags.map((t) => t.id).toList(),
        equals(['tag-3', 'tag-1a', 'tag-1b', 'tag-2']),
      );
    });

    test('categoryById and tagById map IDs to instances accurately', () {
      final catWork = makeCategory(
        id: 'cat-work',
        name: 'Work',
        normalizedName: 'work',
      );
      final catPersonal = makeCategory(
        id: 'cat-personal',
        name: 'Personal',
        normalizedName: 'personal',
      );
      final tagDart = makeTag(
        id: 'tag-dart',
        name: 'Dart',
        normalizedName: 'dart',
      );
      final tagFlutter = makeTag(
        id: 'tag-flutter',
        name: 'Flutter',
        normalizedName: 'flutter',
      );

      final snapshot = LibrarySnapshot(
        categories: [catWork, catPersonal],
        tags: [tagDart, tagFlutter],
      );

      expect(snapshot.categoryById['cat-work'], equals(catWork));
      expect(snapshot.categoryById['cat-personal'], equals(catPersonal));
      expect(snapshot.categoryById['cat-unknown'], isNull);

      expect(snapshot.tagById['tag-dart'], equals(tagDart));
      expect(snapshot.tagById['tag-flutter'], equals(tagFlutter));
      expect(snapshot.tagById['tag-unknown'], isNull);
    });

    test(
      'tagsForEntry includes every entry with tags resolved in tagId order',
      () {
        final tagA = makeTag(id: 'tag-a', name: 'A', normalizedName: 'a');
        final tagB = makeTag(id: 'tag-b', name: 'B', normalizedName: 'b');
        final tagC = makeTag(id: 'tag-c', name: 'C', normalizedName: 'c');

        final entryWithTags = makeEntry(
          id: 'entry-1',
          tagIds: ['tag-c', 'tag-a'],
        );
        final entryNoTags = makeEntry(id: 'entry-2', tagIds: []);

        final snapshot = LibrarySnapshot(
          entries: [entryWithTags, entryNoTags],
          tags: [tagC, tagB, tagA],
        );

        expect(snapshot.tagsForEntry.containsKey('entry-1'), isTrue);
        expect(snapshot.tagsForEntry.containsKey('entry-2'), isTrue);

        expect(
          snapshot.tagsForEntry['entry-1']!.map((t) => t.id).toList(),
          equals(['tag-a', 'tag-c']),
        );
        expect(snapshot.tagsForEntry['entry-2'], isEmpty);
      },
    );

    test('unknown tag IDs are ignored rather than creating nulls', () {
      final tagKnown = makeTag(
        id: 'tag-known',
        name: 'Known',
        normalizedName: 'known',
      );

      final entry = makeEntry(
        id: 'entry-1',
        tagIds: ['tag-missing-1', 'tag-known', 'tag-missing-2'],
      );

      final snapshot = LibrarySnapshot(entries: [entry], tags: [tagKnown]);

      final resolvedTags = snapshot.tagsForEntry['entry-1']!;
      expect(resolvedTags, hasLength(1));
      expect(resolvedTags.first, equals(tagKnown));
      expect(resolvedTags, equals([tagKnown]));
    });

    test(
      'unused categories and unused tags remain present in the full snapshot',
      () {
        final catUsed = makeCategory(
          id: 'cat-used',
          name: 'Used',
          normalizedName: 'used',
        );
        final catUnused = makeCategory(
          id: 'cat-unused',
          name: 'Unused',
          normalizedName: 'unused',
        );

        final tagUsed = makeTag(
          id: 'tag-used',
          name: 'Used Tag',
          normalizedName: 'used tag',
        );
        final tagUnused = makeTag(
          id: 'tag-unused',
          name: 'Unused Tag',
          normalizedName: 'unused tag',
        );

        final entry = makeEntry(
          id: 'entry-1',
          categoryId: 'cat-used',
          tagIds: ['tag-used'],
        );

        final snapshot = LibrarySnapshot(
          entries: [entry],
          categories: [catUsed, catUnused],
          tags: [tagUsed, tagUnused],
        );

        expect(snapshot.categories, containsAll([catUsed, catUnused]));
        expect(snapshot.categoryById.containsKey('cat-unused'), isTrue);
        expect(snapshot.tags, containsAll([tagUsed, tagUnused]));
        expect(snapshot.tagById.containsKey('tag-unused'), isTrue);
      },
    );

    test('supports value equality and hashCode consistency', () {
      final cat1 = makeCategory(
        id: 'cat-1',
        name: 'Work',
        normalizedName: 'work',
      );
      final tag1 = makeTag(id: 'tag-1', name: 'Dart', normalizedName: 'dart');
      final entry1 = makeEntry(
        id: 'entry-1',
        categoryId: 'cat-1',
        tagIds: ['tag-1'],
      );

      final snapshotA = LibrarySnapshot(
        entries: [entry1],
        categories: [cat1],
        tags: [tag1],
      );

      final snapshotB = LibrarySnapshot(
        entries: [
          makeEntry(id: 'entry-1', categoryId: 'cat-1', tagIds: ['tag-1']),
        ],
        categories: [
          makeCategory(id: 'cat-1', name: 'Work', normalizedName: 'work'),
        ],
        tags: [makeTag(id: 'tag-1', name: 'Dart', normalizedName: 'dart')],
      );

      final snapshotDiff = LibrarySnapshot(
        entries: [
          makeEntry(id: 'entry-2', categoryId: 'cat-1', tagIds: ['tag-1']),
        ],
        categories: [cat1],
        tags: [tag1],
      );

      expect(snapshotA, equals(snapshotB));
      expect(snapshotA.hashCode, equals(snapshotB.hashCode));

      expect(snapshotA, isNot(equals(snapshotDiff)));
      expect(snapshotA, isNot(equals(Object())));
    });
  });
}

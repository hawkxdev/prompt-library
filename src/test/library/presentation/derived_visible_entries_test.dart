/// Visible entry derivation tests.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/library/models/category.dart';
import 'package:prompt_library/src/library/models/entry.dart';
import 'package:prompt_library/src/library/models/library_snapshot.dart';
import 'package:prompt_library/src/library/models/tag.dart';
import 'package:prompt_library/src/library/presentation/derived_visible_entries.dart';
import 'package:prompt_library/src/library/presentation/library_filter.dart';

void main() {
  // === Scope tests ===
  group('deriveVisibleEntries scopes', () {
    final active = _entry(id: 'active');
    final favorite = _entry(id: 'favorite', isFavorite: true);
    final archived = _entry(id: 'archived', isArchived: true);
    final archivedFavorite = _entry(
      id: 'archived-favorite',
      isFavorite: true,
      isArchived: true,
    );
    final snapshot = LibrarySnapshot(
      entries: [active, favorite, archived, archivedFavorite],
    );

    test('separates active favorite and archived scopes', () {
      expect(_ids(deriveVisibleEntries(snapshot, LibraryFilter())), [
        'favorite',
        'active',
      ]);
      expect(
        _ids(
          deriveVisibleEntries(
            snapshot,
            LibraryFilter(scope: LibraryFilterScope.favorites),
          ),
        ),
        ['favorite'],
      );
      expect(
        _ids(
          deriveVisibleEntries(
            snapshot,
            LibraryFilter(scope: LibraryFilterScope.archived),
          ),
        ),
        ['archived-favorite', 'archived'],
      );
    });
  });

  // === Taxonomy tests ===
  group('deriveVisibleEntries taxonomy filters', () {
    final snapshot = LibrarySnapshot(
      entries: [
        _entry(
          id: 'all-tags',
          categoryId: 'category-a',
          tagIds: const ['tag-a', 'tag-b'],
        ),
        _entry(
          id: 'one-tag',
          categoryId: 'category-a',
          tagIds: const ['tag-a'],
        ),
        _entry(
          id: 'other-category',
          categoryId: 'category-b',
          tagIds: const ['tag-a', 'tag-b'],
        ),
      ],
      categories: [
        _category('category-a', 'Architecture'),
        _category('category-b', 'Writing'),
      ],
      tags: [_tag('tag-a', 'Dart'), _tag('tag-b', 'Flutter')],
    );

    test('combines exact category with all selected tags', () {
      final visible = deriveVisibleEntries(
        snapshot,
        LibraryFilter(
          categoryId: 'category-a',
          tagIds: const ['tag-b', 'tag-a'],
        ),
      );

      expect(_ids(visible), ['all-tags']);
    });

    test('does not match entries missing a selected tag', () {
      final visible = deriveVisibleEntries(
        snapshot,
        LibraryFilter(tagIds: const ['tag-a', 'missing-tag']),
      );

      expect(visible, isEmpty);
    });
  });

  // === Search tests ===
  group('deriveVisibleEntries search', () {
    final entries = [
      _entry(id: 'title', title: 'Системный Промпт'),
      _entry(id: 'body', body: 'Reusable HTTP response body'),
      _entry(id: 'keyword', keyword: '!deploy'),
      _entry(id: 'category', categoryId: 'category-a'),
      _entry(id: 'tag', tagIds: const ['tag-a']),
    ];
    final snapshot = LibrarySnapshot(
      entries: entries,
      categories: [_category('category-a', 'Архитектура')],
      tags: [_tag('tag-a', 'Разработка')],
    );
    final cases = <String, String>{
      'сИсТеМнЫй': 'title',
      'http RESPONSE': 'body',
      '!DEPLOY': 'keyword',
      'АРХИТЕКТУРА': 'category',
      'разРАБОтка': 'tag',
    };

    for (final MapEntry(key: query, value: expectedId) in cases.entries) {
      test('matches normalized query $query', () {
        final visible = deriveVisibleEntries(
          snapshot,
          LibraryFilter(searchQuery: query),
        );

        expect(_ids(visible), [expectedId]);
      });
    }

    test('treats whitespace-only query as empty', () {
      final visible = deriveVisibleEntries(
        snapshot,
        LibraryFilter(searchQuery: '  \n\t  '),
      );

      expect(visible, hasLength(entries.length));
    });

    test('ignores missing taxonomy references during search', () {
      final missingReferences = LibrarySnapshot(
        entries: [
          _entry(
            id: 'entry',
            categoryId: 'missing-category',
            tagIds: const ['missing-tag'],
          ),
        ],
      );

      expect(
        deriveVisibleEntries(
          missingReferences,
          LibraryFilter(searchQuery: 'missing'),
        ),
        isEmpty,
      );
    });
  });

  // === Ordering tests ===
  group('deriveVisibleEntries ordering', () {
    test('applies every deterministic ordering level', () {
      final sharedUpdatedAt = DateTime.utc(2026, 8, 25, 12);
      final snapshot = LibrarySnapshot(
        entries: [
          _entry(
            id: 'favorite',
            title: 'Zulu',
            isFavorite: true,
            updatedAt: DateTime.utc(2026, 8, 20),
          ),
          _entry(
            id: 'copied-new',
            lastCopiedAt: DateTime.utc(2026, 8, 25),
            updatedAt: DateTime.utc(2026, 8, 20),
          ),
          _entry(
            id: 'copied-old',
            lastCopiedAt: DateTime.utc(2026, 8, 24),
            updatedAt: DateTime.utc(2026, 8, 25),
          ),
          _entry(
            id: 'updated-new',
            title: 'Zulu',
            updatedAt: DateTime.utc(2026, 8, 25, 13),
          ),
          _entry(id: 'title-zulu', title: 'Zulu', updatedAt: sharedUpdatedAt),
          _entry(id: 'id-b', title: 'Alpha', updatedAt: sharedUpdatedAt),
          _entry(id: 'id-a', title: 'alpha', updatedAt: sharedUpdatedAt),
        ],
      );

      final visible = deriveVisibleEntries(snapshot, LibraryFilter());

      expect(_ids(visible), [
        'favorite',
        'copied-new',
        'copied-old',
        'updated-new',
        'id-a',
        'id-b',
        'title-zulu',
      ]);
    });

    test('returns an unmodifiable materialized list', () {
      final visible = deriveVisibleEntries(
        LibrarySnapshot(entries: [_entry(id: 'entry')]),
        LibraryFilter(),
      );

      expect(() => visible.clear(), throwsUnsupportedError);
    });
  });

  // === Selection tests ===
  group('resolveSelectedEntryId', () {
    final entries = [_entry(id: 'first'), _entry(id: 'second')];

    test('preserves a visible selection', () {
      expect(
        resolveSelectedEntryId(
          visibleEntries: entries,
          currentSelectedId: 'second',
        ),
        'second',
      );
    });

    test('falls back to the first visible entry', () {
      expect(
        resolveSelectedEntryId(
          visibleEntries: entries,
          currentSelectedId: 'missing',
        ),
        'first',
      );
    });

    test('returns null for an empty result', () {
      expect(
        resolveSelectedEntryId(
          visibleEntries: const [],
          currentSelectedId: 'missing',
        ),
        isNull,
      );
    });
  });
}

/// Returns entry identifiers.
List<String> _ids(List<Entry> entries) {
  return entries.map((entry) => entry.id).toList();
}

/// Creates deterministic entry.
Entry _entry({
  required String id,
  String? title,
  String? body,
  String? keyword,
  String? categoryId,
  Iterable<String> tagIds = const [],
  bool isFavorite = false,
  bool isArchived = false,
  DateTime? updatedAt,
  DateTime? lastCopiedAt,
}) {
  return Entry(
    id: id,
    title: title ?? 'Title $id',
    body: body ?? 'Body $id',
    keyword: keyword,
    categoryId: categoryId,
    tagIds: tagIds,
    isFavorite: isFavorite,
    isArchived: isArchived,
    createdAt: DateTime.utc(2026, 8, 20),
    updatedAt: updatedAt ?? DateTime.utc(2026, 8, 20),
    lastCopiedAt: lastCopiedAt,
  );
}

/// Creates deterministic category.
Category _category(String id, String name) {
  return Category(
    id: id,
    name: name,
    normalizedName: name.toLowerCase(),
    sortOrder: 0,
    createdAt: DateTime.utc(2026, 8, 20),
  );
}

/// Creates deterministic tag.
Tag _tag(String id, String name) {
  return Tag(
    id: id,
    name: name,
    normalizedName: name.toLowerCase(),
    createdAt: DateTime.utc(2026, 8, 20),
  );
}

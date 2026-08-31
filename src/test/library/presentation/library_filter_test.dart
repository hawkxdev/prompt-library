/// Library filter tests.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/library/presentation/library_filter.dart';

void main() {
  // === Construction tests ===
  group('LibraryFilter', () {
    test('defaults to active scope with empty criteria', () {
      final filter = LibraryFilter();

      expect(filter.searchQuery, isEmpty);
      expect(filter.scope, LibraryFilterScope.active);
      expect(filter.categoryId, isNull);
      expect(filter.tagIds, isEmpty);
    });

    test('deduplicates sorts and freezes tag identifiers', () {
      final source = <String>['tag-b', 'tag-a', 'tag-b'];
      final filter = LibraryFilter(tagIds: source);

      source.add('tag-c');

      expect(filter.tagIds, ['tag-a', 'tag-b']);
      expect(() => filter.tagIds.add('tag-c'), throwsUnsupportedError);
    });

    test('supports value equality and matching hash codes', () {
      final first = LibraryFilter(
        searchQuery: 'query',
        scope: LibraryFilterScope.favorites,
        categoryId: 'category-1',
        tagIds: const ['tag-b', 'tag-a'],
      );
      final second = LibraryFilter(
        searchQuery: 'query',
        scope: LibraryFilterScope.favorites,
        categoryId: 'category-1',
        tagIds: const ['tag-a', 'tag-b'],
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('copyWith changes and explicitly clears nullable criteria', () {
      final filter = LibraryFilter(
        searchQuery: 'query',
        scope: LibraryFilterScope.archived,
        categoryId: 'category-1',
        tagIds: const ['tag-a'],
      );

      final changed = filter.copyWith(
        searchQuery: 'next',
        scope: LibraryFilterScope.active,
        tagIds: const ['tag-b'],
      );
      final cleared = changed.copyWith(categoryId: null);

      expect(changed.categoryId, 'category-1');
      expect(changed.searchQuery, 'next');
      expect(changed.scope, LibraryFilterScope.active);
      expect(changed.tagIds, ['tag-b']);
      expect(cleared.categoryId, isNull);
    });
  });
}

/// Library filter models.
library;

/// Available library scopes.
enum LibraryFilterScope {
  /// Non-archived entries.
  active,

  /// Favorite non-archived entries.
  favorites,

  /// Archived entries.
  archived,
}

/// Immutable library filter.
final class LibraryFilter {
  /// Creates library filter.
  LibraryFilter({
    this.searchQuery = '',
    this.scope = LibraryFilterScope.active,
    this.categoryId,
    Iterable<String> tagIds = const [],
  }) : tagIds = _freezeTagIds(tagIds);

  static const Object _unset = Object();

  /// Raw search query.
  final String searchQuery;

  /// Selected library scope.
  final LibraryFilterScope scope;

  /// Selected category identifier.
  final String? categoryId;

  /// Selected tag identifiers.
  final List<String> tagIds;

  /// Copies filter values.
  LibraryFilter copyWith({
    String? searchQuery,
    LibraryFilterScope? scope,
    Object? categoryId = _unset,
    Iterable<String>? tagIds,
  }) {
    return LibraryFilter(
      searchQuery: searchQuery ?? this.searchQuery,
      scope: scope ?? this.scope,
      categoryId: identical(categoryId, _unset)
          ? this.categoryId
          : categoryId as String?,
      tagIds: tagIds ?? this.tagIds,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LibraryFilter &&
            other.searchQuery == searchQuery &&
            other.scope == scope &&
            other.categoryId == categoryId &&
            _listEquals(other.tagIds, tagIds);
  }

  @override
  int get hashCode {
    return Object.hash(searchQuery, scope, categoryId, Object.hashAll(tagIds));
  }
}

/// Freezes tag identifiers.
List<String> _freezeTagIds(Iterable<String> tagIds) {
  final values = tagIds.toSet().toList()..sort();
  if (values.isEmpty) {
    return const [];
  }
  return List.unmodifiable(values);
}

/// Compares ordered lists.
bool _listEquals<T>(List<T> first, List<T> second) {
  if (identical(first, second)) {
    return true;
  }
  if (first.length != second.length) {
    return false;
  }
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) {
      return false;
    }
  }
  return true;
}

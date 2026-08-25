/// Visible entry derivation.
library;

import '../models/entry.dart';
import '../models/library_snapshot.dart';
import '../models/normalization.dart';
import 'library_filter.dart';

/// Derives visible entries.
List<Entry> deriveVisibleEntries(
  LibrarySnapshot snapshot,
  LibraryFilter filter,
) {
  final normalizedQuery = normalizeSearchQuery(filter.searchQuery);
  final candidates = <_DerivedEntry>[];

  for (final entry in snapshot.entries) {
    if (!_matchesScope(entry, filter.scope)) {
      continue;
    }
    if (filter.categoryId != null && entry.categoryId != filter.categoryId) {
      continue;
    }
    if (!_containsAllSorted(entry.tagIds, filter.tagIds)) {
      continue;
    }
    if (normalizedQuery.isNotEmpty &&
        !_matchesSearch(entry, snapshot, normalizedQuery)) {
      continue;
    }
    candidates.add(
      _DerivedEntry(
        entry: entry,
        normalizedTitle: normalizeSearchQuery(entry.title),
      ),
    );
  }

  candidates.sort(_compareDerivedEntries);
  if (candidates.isEmpty) {
    return const [];
  }
  return List.unmodifiable(candidates.map((candidate) => candidate.entry));
}

/// Resolves selected entry.
String? resolveSelectedEntryId({
  required List<Entry> visibleEntries,
  required String? currentSelectedId,
}) {
  if (visibleEntries.isEmpty) {
    return null;
  }
  if (currentSelectedId != null) {
    for (final entry in visibleEntries) {
      if (entry.id == currentSelectedId) {
        return currentSelectedId;
      }
    }
  }
  return visibleEntries.first.id;
}

/// Holds decorated entry.
final class _DerivedEntry {
  /// Creates decorated entry.
  const _DerivedEntry({required this.entry, required this.normalizedTitle});

  /// Source entry.
  final Entry entry;

  /// Cached normalized title.
  final String normalizedTitle;
}

/// Checks selected scope.
bool _matchesScope(Entry entry, LibraryFilterScope scope) {
  return switch (scope) {
    LibraryFilterScope.active => !entry.isArchived,
    LibraryFilterScope.favorites => entry.isFavorite && !entry.isArchived,
    LibraryFilterScope.archived => entry.isArchived,
  };
}

/// Matches normalized search.
bool _matchesSearch(
  Entry entry,
  LibrarySnapshot snapshot,
  String normalizedQuery,
) {
  if (normalizeSearchQuery(entry.title).contains(normalizedQuery) ||
      normalizeSearchQuery(entry.body).contains(normalizedQuery) ||
      normalizeSearchQuery(entry.keyword ?? '').contains(normalizedQuery)) {
    return true;
  }

  final category = entry.categoryId == null
      ? null
      : snapshot.categoryById[entry.categoryId];
  if (category != null && category.normalizedName.contains(normalizedQuery)) {
    return true;
  }

  for (final tagId in entry.tagIds) {
    final tag = snapshot.tagById[tagId];
    if (tag != null && tag.normalizedName.contains(normalizedQuery)) {
      return true;
    }
  }
  return false;
}

/// Checks sorted subset.
bool _containsAllSorted(List<String> available, List<String> required) {
  var availableIndex = 0;
  var requiredIndex = 0;

  while (requiredIndex < required.length) {
    if (availableIndex >= available.length) {
      return false;
    }
    final comparison = available[availableIndex].compareTo(
      required[requiredIndex],
    );
    if (comparison < 0) {
      availableIndex++;
    } else if (comparison == 0) {
      availableIndex++;
      requiredIndex++;
    } else {
      return false;
    }
  }
  return true;
}

/// Compares decorated entries.
int _compareDerivedEntries(_DerivedEntry first, _DerivedEntry second) {
  if (first.entry.isFavorite != second.entry.isFavorite) {
    return first.entry.isFavorite ? -1 : 1;
  }

  final copiedComparison = _compareNullableDatesDescending(
    first.entry.lastCopiedAt,
    second.entry.lastCopiedAt,
  );
  if (copiedComparison != 0) {
    return copiedComparison;
  }

  final updatedComparison = second.entry.updatedAt.compareTo(
    first.entry.updatedAt,
  );
  if (updatedComparison != 0) {
    return updatedComparison;
  }

  final titleComparison = first.normalizedTitle.compareTo(
    second.normalizedTitle,
  );
  if (titleComparison != 0) {
    return titleComparison;
  }

  return first.entry.id.compareTo(second.entry.id);
}

/// Compares nullable dates.
int _compareNullableDatesDescending(DateTime? first, DateTime? second) {
  if (first == null) {
    return second == null ? 0 : 1;
  }
  if (second == null) {
    return -1;
  }
  return second.compareTo(first);
}

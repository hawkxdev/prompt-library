/// Mobile presentation modes.
library;

import '../../models/entry.dart';
import '../../models/normalization.dart';
import '../library_filter.dart';

/// Selects the mobile presentation mode.
enum MobileLibraryMode { all, favorites, recent, archived }

/// Maps a mobile mode onto the shared library scope.
LibraryFilterScope scopeForMobileMode(MobileLibraryMode mode) {
  return switch (mode) {
    MobileLibraryMode.all => LibraryFilterScope.active,
    MobileLibraryMode.favorites => LibraryFilterScope.favorites,
    MobileLibraryMode.recent => LibraryFilterScope.active,
    MobileLibraryMode.archived => LibraryFilterScope.archived,
  };
}

/// Projects controller-visible entries onto the selected mobile mode.
List<Entry> projectMobileEntries(
  List<Entry> visibleEntries,
  MobileLibraryMode mode,
) {
  if (mode != MobileLibraryMode.recent) {
    return visibleEntries;
  }
  final candidates = <_RecentEntry>[
    for (final entry in visibleEntries)
      if (!entry.isArchived && entry.lastCopiedAt != null)
        _RecentEntry(
          entry: entry,
          normalizedTitle: normalizeSearchQuery(entry.title),
        ),
  ];
  if (candidates.isEmpty) {
    return const [];
  }
  candidates.sort(_compareRecentEntries);
  return List.unmodifiable(candidates.map((candidate) => candidate.entry));
}

/// Holds a decorated recent entry.
final class _RecentEntry {
  /// Creates a decorated recent entry.
  const _RecentEntry({required this.entry, required this.normalizedTitle});

  /// Source entry.
  final Entry entry;

  /// Cached normalized title.
  final String normalizedTitle;
}

/// Compares recent entries by copied, updated, title and identifier.
int _compareRecentEntries(_RecentEntry first, _RecentEntry second) {
  final copiedComparison = second.entry.lastCopiedAt!.compareTo(
    first.entry.lastCopiedAt!,
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

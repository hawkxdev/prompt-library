/// Library snapshot model.
library;

import 'category.dart';
import 'entry.dart';
import 'tag.dart';

/// Library state snapshot.
final class LibrarySnapshot {
  /// Immutable entries list.
  final List<Entry> entries;

  /// Immutable categories list.
  final List<Category> categories;

  /// Immutable tags list.
  final List<Tag> tags;

  /// Creates empty snapshot.
  const LibrarySnapshot.empty()
    : entries = const [],
      categories = const [],
      tags = const [];

  /// Creates sorted snapshot.
  LibrarySnapshot({
    Iterable<Entry> entries = const [],
    Iterable<Category> categories = const [],
    Iterable<Tag> tags = const [],
  }) : entries = List<Entry>.unmodifiable(
         entries.toList()..sort((a, b) {
           final updated = b.updatedAt.compareTo(a.updatedAt);
           if (updated != 0) return updated;
           return b.id.compareTo(a.id);
         }),
       ),
       categories = List<Category>.unmodifiable(
         categories.toList()..sort((a, b) {
           final sort = a.sortOrder.compareTo(b.sortOrder);
           if (sort != 0) return sort;
           final norm = a.normalizedName.compareTo(b.normalizedName);
           if (norm != 0) return norm;
           return a.id.compareTo(b.id);
         }),
       ),
       tags = List<Tag>.unmodifiable(
         tags.toList()..sort((a, b) {
           final norm = a.normalizedName.compareTo(b.normalizedName);
           if (norm != 0) return norm;
           return a.id.compareTo(b.id);
         }),
       );

  /// Maps identifier to category.
  Map<String, Category> get categoryById =>
      Map<String, Category>.unmodifiable(<String, Category>{
        for (final category in categories) category.id: category,
      });

  /// Maps identifier to tag.
  Map<String, Tag> get tagById => Map<String, Tag>.unmodifiable(<String, Tag>{
    for (final tag in tags) tag.id: tag,
  });

  /// Maps entry to tags.
  Map<String, List<Tag>> get tagsForEntry {
    final tagsMap = tagById;
    return Map<String, List<Tag>>.unmodifiable(<String, List<Tag>>{
      for (final entry in entries)
        entry.id: List<Tag>.unmodifiable(<Tag>[
          for (final tagId in entry.tagIds)
            if (tagsMap.containsKey(tagId)) tagsMap[tagId]!,
        ]),
    });
  }

  /// Checks value equality.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LibrarySnapshot &&
        _listEquals(other.entries, entries) &&
        _listEquals(other.categories, categories) &&
        _listEquals(other.tags, tags);
  }

  /// Computes hash code.
  @override
  int get hashCode => Object.hash(
    Object.hashAll(entries),
    Object.hashAll(categories),
    Object.hashAll(tags),
  );
}

/// Compares generic lists.
bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

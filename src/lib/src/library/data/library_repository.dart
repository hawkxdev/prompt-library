/// Library repository contract.
library;

import '../models/category.dart';
import '../models/entry.dart';
import '../models/entry_input.dart';
import '../models/entry_update.dart';
import '../models/library_snapshot.dart';
import '../models/tag.dart';

/// Library repository interface.
abstract interface class LibraryRepository {
  /// Watches library snapshots.
  Stream<LibrarySnapshot> watchSnapshot();

  /// Reads library snapshot.
  Future<LibrarySnapshot> getSnapshot();

  /// Restores a full library snapshot atomically.
  ///
  /// Fails with [LibraryFailure.staleSnapshot] when the current snapshot is
  /// not exactly [expectedCurrent]; otherwise replaces the whole library with
  /// [replacement] preserving identifiers and dates.
  Future<LibrarySnapshot> restoreSnapshot({
    required LibrarySnapshot expectedCurrent,
    required LibrarySnapshot replacement,
  });

  /// Adds imported Raycast entries atomically.
  ///
  /// Fails with [LibraryFailure.staleSnapshot] when the current snapshot is
  /// not exactly [expectedCurrent]; otherwise appends every draft with a new
  /// identifier and keeps [RaycastEntryDraft.keyword] verbatim.
  Future<List<Entry>> addRaycastEntries({
    required LibrarySnapshot expectedCurrent,
    required List<RaycastEntryDraft> drafts,
  });

  /// Creates library entry.
  Future<Entry> createEntry(EntryInput input);

  /// Updates library entry.
  Future<Entry> updateEntry(String id, EntryInput input);

  /// Updates library entry with explicit keyword intent.
  ///
  /// [KeywordUpdate.keepExisting] preserves the stored keyword verbatim;
  /// [KeywordUpdate.replace] normalizes the requested value like
  /// [EntryInput].
  Future<Entry> updateEntryDetails(String id, EntryUpdate update);

  /// Deletes library entry.
  Future<void> deleteEntry(String id);

  /// Marks entry copied.
  Future<void> markCopied(String id);

  /// Sets favorite status.
  Future<void> setFavorite(String id, {required bool isFavorite});

  /// Sets archived status.
  Future<void> setArchived(String id, {required bool isArchived});

  /// Creates library category.
  Future<Category> createCategory(String name);

  /// Renames library category.
  Future<Category> renameCategory(String id, String newName);

  /// Deletes library category.
  Future<void> deleteCategory(String id);

  /// Reorders library categories.
  Future<void> reorderCategories(List<String> orderedCategoryIds);

  /// Creates library tag.
  Future<Tag> createTag(String name);

  /// Renames library tag.
  Future<Tag> renameTag(String id, String newName);

  /// Deletes library tag.
  Future<void> deleteTag(String id);
}

/// Draft of an imported Raycast entry applied without normalization.
final class RaycastEntryDraft {
  /// Prompt title.
  final String title;

  /// Prompt body kept verbatim.
  final String body;

  /// Quick search keyword kept verbatim, including empty and blank strings.
  final String? keyword;

  /// Creates imported entry draft.
  const RaycastEntryDraft({
    required this.title,
    required this.body,
    this.keyword,
  });

  /// Checks value equality.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RaycastEntryDraft &&
          other.title == title &&
          other.body == body &&
          other.keyword == keyword);

  /// Computes hash code.
  @override
  int get hashCode => Object.hash(title, body, keyword);
}

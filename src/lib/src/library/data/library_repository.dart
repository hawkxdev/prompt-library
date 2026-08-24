/// Library repository contract.
library;

import '../models/category.dart';
import '../models/entry.dart';
import '../models/entry_input.dart';
import '../models/library_snapshot.dart';
import '../models/tag.dart';

/// Library repository interface.
abstract interface class LibraryRepository {
  /// Watches library snapshots.
  Stream<LibrarySnapshot> watchSnapshot();

  /// Reads library snapshot.
  Future<LibrarySnapshot> getSnapshot();

  /// Creates library entry.
  Future<Entry> createEntry(EntryInput input);

  /// Updates library entry.
  Future<Entry> updateEntry(String id, EntryInput input);

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

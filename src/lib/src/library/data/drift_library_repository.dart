/// Drift repository implementation.
library;

import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:uuid/uuid.dart';

import '../models/category.dart';
import '../models/entry.dart';
import '../models/entry_input.dart';
import '../models/library_failure.dart';
import '../models/library_snapshot.dart';
import '../models/normalization.dart';
import '../models/tag.dart';
import 'library_database.dart' hide Entry, Category, Tag;
import 'library_repository.dart';

/// Unique identifier generator.
typedef UuidGenerator = String Function();

/// Current clock provider.
typedef Clock = DateTime Function();

/// Drift library repository.
final class DriftLibraryRepository implements LibraryRepository {
  /// SQLite unique constraint code.
  static const int _sqliteConstraintUnique = 2067;

  /// SQLite corrupt error code.
  static const int _sqliteCorrupt = 11;

  /// SQLite invalid database code.
  static const int _sqliteNotDatabase = 26;

  /// Local database instance.
  final LibraryDatabase _db;

  /// Identifier generator provider.
  final UuidGenerator _uuidGenerator;

  /// Clock timestamp provider.
  final Clock _clock;

  /// Creates drift repository.
  DriftLibraryRepository(
    LibraryDatabase db, {
    UuidGenerator? uuidGenerator,
    Clock? clock,
  }) : _db = db,
       _uuidGenerator = uuidGenerator ?? (() => const Uuid().v4()),
       _clock = clock ?? DateTime.now;

  /// Gets identifier generator.
  UuidGenerator get uuidGenerator => _uuidGenerator;

  /// Gets clock provider.
  Clock get clock => _clock;

  /// Watches library snapshots.
  @override
  Stream<LibrarySnapshot> watchSnapshot() {
    final source = _db
        .customSelect(
          'SELECT 1',
          readsFrom: {_db.entries, _db.categories, _db.tags, _db.entryTags},
        )
        .watch()
        .asyncMap((_) => getSnapshot());

    return Stream<LibrarySnapshot>.multi((controller) {
      var emitted = false;
      final subscription = source.listen(
        (snapshot) {
          emitted = true;
          controller.add(snapshot);
        },
        onError: (Object error, StackTrace stackTrace) {
          controller.addError(_mapReadError(error), stackTrace);
        },
        onDone: () async {
          if (!emitted) {
            try {
              controller.add(await getSnapshot());
            } on Object catch (error, stackTrace) {
              controller.addError(_mapReadError(error), stackTrace);
            }
          }
          controller.close();
        },
      );
      controller.onCancel = subscription.cancel;
    });
  }

  /// Reads library snapshot.
  @override
  Future<LibrarySnapshot> getSnapshot() {
    return _wrapDbRead(
      () => _db.transaction(() async {
        final entriesData = await _db.select(_db.entries).get();
        final categoriesData = await _db.select(_db.categories).get();
        final tagsData = await _db.select(_db.tags).get();
        final entryTagsData = await _db.select(_db.entryTags).get();

        final tagIdsByEntryId = <String, List<String>>{};
        for (final entryTag in entryTagsData) {
          (tagIdsByEntryId[entryTag.entryId] ??= <String>[]).add(
            entryTag.tagId,
          );
        }

        final entries = entriesData.map((row) {
          return Entry(
            id: row.id,
            title: row.title,
            body: row.body,
            keyword: row.keyword,
            categoryId: row.categoryId,
            tagIds: tagIdsByEntryId[row.id] ?? const [],
            isFavorite: row.isFavorite,
            isArchived: row.isArchived,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt,
            lastCopiedAt: row.lastCopiedAt,
          );
        });

        final categories = categoriesData.map((row) {
          return Category(
            id: row.id,
            name: row.name,
            normalizedName: row.normalizedName,
            sortOrder: row.sortOrder,
            createdAt: row.createdAt,
          );
        });

        final tags = tagsData.map((row) {
          return Tag(
            id: row.id,
            name: row.name,
            normalizedName: row.normalizedName,
            createdAt: row.createdAt,
          );
        });

        return LibrarySnapshot(
          entries: entries,
          categories: categories,
          tags: tags,
        );
      }),
    );
  }

  /// Creates library entry.
  @override
  Future<Entry> createEntry(EntryInput input) {
    final trimmedTitle = input.title.trim();
    if (trimmedTitle.isEmpty) {
      throw const LibraryFailure.invalidInput(
        LibraryInputFailureReason.emptyTitle,
      );
    }
    if (input.body.trim().isEmpty) {
      throw const LibraryFailure.invalidInput(
        LibraryInputFailureReason.emptyBody,
      );
    }
    final trimmedKeyword =
        (input.keyword != null && input.keyword!.trim().isNotEmpty)
        ? input.keyword!.trim()
        : null;
    final sortedTagIds = List<String>.unmodifiable(
      input.tagIds.toSet().toList()..sort(),
    );

    return _wrapDb(
      () => _db.transaction(() async {
        if (input.categoryId != null) {
          final cat = await (_db.select(
            _db.categories,
          )..where((t) => t.id.equals(input.categoryId!))).getSingleOrNull();
          if (cat == null) {
            throw const LibraryFailure.invalidInput(
              LibraryInputFailureReason.unknownCategory,
            );
          }
        }

        if (sortedTagIds.isNotEmpty) {
          final existingTags = await (_db.select(
            _db.tags,
          )..where((t) => t.id.isIn(sortedTagIds))).get();
          if (existingTags.length != sortedTagIds.length) {
            throw const LibraryFailure.invalidInput(
              LibraryInputFailureReason.unknownTag,
            );
          }
        }

        final id = _uuidGenerator();
        final now = _clock().toUtc();

        await _db
            .into(_db.entries)
            .insert(
              EntriesCompanion.insert(
                id: id,
                title: trimmedTitle,
                body: input.body,
                keyword: Value(trimmedKeyword),
                categoryId: Value(input.categoryId),
                isFavorite: Value(input.isFavorite),
                isArchived: Value(input.isArchived),
                createdAt: now,
                updatedAt: now,
              ),
            );

        if (sortedTagIds.isNotEmpty) {
          await _db.batch((batch) {
            for (final tagId in sortedTagIds) {
              batch.insert(
                _db.entryTags,
                EntryTagsCompanion.insert(entryId: id, tagId: tagId),
              );
            }
          });
        }

        return Entry(
          id: id,
          title: trimmedTitle,
          body: input.body,
          keyword: trimmedKeyword,
          categoryId: input.categoryId,
          tagIds: sortedTagIds,
          isFavorite: input.isFavorite,
          isArchived: input.isArchived,
          createdAt: now,
          updatedAt: now,
          lastCopiedAt: null,
        );
      }),
    );
  }

  /// Updates library entry.
  @override
  Future<Entry> updateEntry(String id, EntryInput input) {
    final trimmedTitle = input.title.trim();
    if (trimmedTitle.isEmpty) {
      throw const LibraryFailure.invalidInput(
        LibraryInputFailureReason.emptyTitle,
      );
    }
    if (input.body.trim().isEmpty) {
      throw const LibraryFailure.invalidInput(
        LibraryInputFailureReason.emptyBody,
      );
    }
    final trimmedKeyword =
        (input.keyword != null && input.keyword!.trim().isNotEmpty)
        ? input.keyword!.trim()
        : null;
    final sortedTagIds = List<String>.unmodifiable(
      input.tagIds.toSet().toList()..sort(),
    );

    return _wrapDb(
      () => _db.transaction(() async {
        final existing = await (_db.select(
          _db.entries,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (existing == null) {
          throw LibraryFailure.entryNotFound(id: id);
        }

        if (input.categoryId != null) {
          final cat = await (_db.select(
            _db.categories,
          )..where((t) => t.id.equals(input.categoryId!))).getSingleOrNull();
          if (cat == null) {
            throw const LibraryFailure.invalidInput(
              LibraryInputFailureReason.unknownCategory,
            );
          }
        }

        if (sortedTagIds.isNotEmpty) {
          final existingTags = await (_db.select(
            _db.tags,
          )..where((t) => t.id.isIn(sortedTagIds))).get();
          if (existingTags.length != sortedTagIds.length) {
            throw const LibraryFailure.invalidInput(
              LibraryInputFailureReason.unknownTag,
            );
          }
        }

        final existingJoins = await (_db.select(
          _db.entryTags,
        )..where((t) => t.entryId.equals(id))).get();
        final existingTagIds = List<String>.unmodifiable(
          existingJoins.map((j) => j.tagId).toSet().toList()..sort(),
        );

        final isSameTitle = existing.title == trimmedTitle;
        final isSameBody = existing.body == input.body;
        final isSameKeyword = existing.keyword == trimmedKeyword;
        final isSameCategory = existing.categoryId == input.categoryId;
        final isSameFavorite = existing.isFavorite == input.isFavorite;
        final isSameArchived = existing.isArchived == input.isArchived;
        final isSameTags = _areListsEqual(existingTagIds, sortedTagIds);
        if (isSameTitle &&
            isSameBody &&
            isSameKeyword &&
            isSameCategory &&
            isSameFavorite &&
            isSameArchived &&
            isSameTags) {
          return Entry(
            id: id,
            title: existing.title,
            body: existing.body,
            keyword: existing.keyword,
            categoryId: existing.categoryId,
            tagIds: existingTagIds,
            isFavorite: existing.isFavorite,
            isArchived: existing.isArchived,
            createdAt: existing.createdAt.toUtc(),
            updatedAt: existing.updatedAt.toUtc(),
            lastCopiedAt: existing.lastCopiedAt?.toUtc(),
          );
        }

        final now = _clock().toUtc();

        await (_db.update(_db.entries)..where((t) => t.id.equals(id))).write(
          EntriesCompanion(
            title: Value(trimmedTitle),
            body: Value(input.body),
            keyword: Value(trimmedKeyword),
            categoryId: Value(input.categoryId),
            isFavorite: Value(input.isFavorite),
            isArchived: Value(input.isArchived),
            updatedAt: Value(now),
          ),
        );

        if (!isSameTags) {
          await (_db.delete(
            _db.entryTags,
          )..where((t) => t.entryId.equals(id))).go();
          if (sortedTagIds.isNotEmpty) {
            await _db.batch((batch) {
              for (final tagId in sortedTagIds) {
                batch.insert(
                  _db.entryTags,
                  EntryTagsCompanion.insert(entryId: id, tagId: tagId),
                );
              }
            });
          }
        }

        return Entry(
          id: id,
          title: trimmedTitle,
          body: input.body,
          keyword: trimmedKeyword,
          categoryId: input.categoryId,
          tagIds: sortedTagIds,
          isFavorite: input.isFavorite,
          isArchived: input.isArchived,
          createdAt: existing.createdAt.toUtc(),
          updatedAt: now,
          lastCopiedAt: existing.lastCopiedAt?.toUtc(),
        );
      }),
    );
  }

  /// Deletes library entry.
  @override
  Future<void> deleteEntry(String id) {
    return _wrapDb(
      () => _db.transaction(() async {
        final rowsAffected = await (_db.delete(
          _db.entries,
        )..where((t) => t.id.equals(id))).go();
        if (rowsAffected == 0) {
          throw LibraryFailure.entryNotFound(id: id);
        }
      }),
    );
  }

  /// Marks entry copied.
  @override
  Future<void> markCopied(String id) {
    return _wrapDb(
      () => _db.transaction(() async {
        final existing = await (_db.select(
          _db.entries,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (existing == null) {
          throw LibraryFailure.entryNotFound(id: id);
        }
        final now = _clock().toUtc();
        await (_db.update(_db.entries)..where((t) => t.id.equals(id))).write(
          EntriesCompanion(lastCopiedAt: Value(now)),
        );
      }),
    );
  }

  /// Sets favorite status.
  @override
  Future<void> setFavorite(String id, {required bool isFavorite}) {
    return _wrapDb(
      () => _db.transaction(() async {
        final existing = await (_db.select(
          _db.entries,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (existing == null) {
          throw LibraryFailure.entryNotFound(id: id);
        }
        if (existing.isFavorite == isFavorite) {
          return;
        }
        final now = _clock().toUtc();
        await (_db.update(_db.entries)..where((t) => t.id.equals(id))).write(
          EntriesCompanion(
            isFavorite: Value(isFavorite),
            updatedAt: Value(now),
          ),
        );
      }),
    );
  }

  /// Sets archived status.
  @override
  Future<void> setArchived(String id, {required bool isArchived}) {
    return _wrapDb(
      () => _db.transaction(() async {
        final existing = await (_db.select(
          _db.entries,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (existing == null) {
          throw LibraryFailure.entryNotFound(id: id);
        }
        if (existing.isArchived == isArchived) {
          return;
        }
        final now = _clock().toUtc();
        await (_db.update(_db.entries)..where((t) => t.id.equals(id))).write(
          EntriesCompanion(
            isArchived: Value(isArchived),
            updatedAt: Value(now),
          ),
        );
      }),
    );
  }

  /// Creates library category.
  @override
  Future<Category> createCategory(String name) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const LibraryFailure.invalidInput(
        LibraryInputFailureReason.emptyCategoryName,
      );
    }
    final normalized = normalizeMetadataName(trimmedName);

    return _wrapDb(
      () => _db.transaction(() async {
        final existing = await (_db.select(
          _db.categories,
        )..where((t) => t.normalizedName.equals(normalized))).getSingleOrNull();
        if (existing != null) {
          throw const LibraryFailure.duplicateCategoryName();
        }

        final maxSortOrderExp = _db.categories.sortOrder.max();
        final maxSortOrderQuery = _db.selectOnly(_db.categories)
          ..addColumns([maxSortOrderExp]);
        final maxSortOrder = await maxSortOrderQuery
            .map((row) => row.read(maxSortOrderExp))
            .getSingleOrNull();
        final nextSortOrder = maxSortOrder == null ? 0 : maxSortOrder + 1;

        final id = _uuidGenerator();
        final now = _clock().toUtc();

        await _db
            .into(_db.categories)
            .insert(
              CategoriesCompanion.insert(
                id: id,
                name: trimmedName,
                normalizedName: normalized,
                sortOrder: nextSortOrder,
                createdAt: now,
              ),
            );

        return Category(
          id: id,
          name: trimmedName,
          normalizedName: normalized,
          sortOrder: nextSortOrder,
          createdAt: now,
        );
      }),
    );
  }

  /// Renames library category.
  @override
  Future<Category> renameCategory(String id, String newName) {
    final trimmedName = newName.trim();
    if (trimmedName.isEmpty) {
      throw const LibraryFailure.invalidInput(
        LibraryInputFailureReason.emptyCategoryName,
      );
    }
    final normalized = normalizeMetadataName(trimmedName);

    return _wrapDb(
      () => _db.transaction(() async {
        final existing = await (_db.select(
          _db.categories,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (existing == null) {
          throw LibraryFailure.categoryNotFound(id: id);
        }

        final duplicate =
            await (_db.select(_db.categories)..where(
                  (t) =>
                      t.normalizedName.equals(normalized) &
                      t.id.equals(id).not(),
                ))
                .getSingleOrNull();
        if (duplicate != null) {
          throw const LibraryFailure.duplicateCategoryName();
        }

        if (existing.name != trimmedName ||
            existing.normalizedName != normalized) {
          await (_db.update(
            _db.categories,
          )..where((t) => t.id.equals(id))).write(
            CategoriesCompanion(
              name: Value(trimmedName),
              normalizedName: Value(normalized),
            ),
          );
        }

        return Category(
          id: existing.id,
          name: trimmedName,
          normalizedName: normalized,
          sortOrder: existing.sortOrder,
          createdAt: existing.createdAt.toUtc(),
        );
      }),
    );
  }

  /// Deletes library category.
  @override
  Future<void> deleteCategory(String id) {
    return _wrapDb(
      () => _db.transaction(() async {
        final rowsAffected = await (_db.delete(
          _db.categories,
        )..where((t) => t.id.equals(id))).go();
        if (rowsAffected == 0) {
          throw LibraryFailure.categoryNotFound(id: id);
        }
      }),
    );
  }

  /// Reorders library categories.
  @override
  Future<void> reorderCategories(List<String> orderedCategoryIds) {
    return _wrapDb(
      () => _db.transaction(() async {
        final existingCategories = await _db.select(_db.categories).get();
        final expectedCount = existingCategories.length;
        final actualCount = orderedCategoryIds.length;

        if (expectedCount == 0 && actualCount == 0) {
          return;
        }

        final existingIdSet = existingCategories.map((c) => c.id).toSet();
        final orderedIdSet = orderedCategoryIds.toSet();

        if (actualCount != expectedCount ||
            orderedIdSet.length != actualCount ||
            !orderedIdSet.containsAll(existingIdSet) ||
            !existingIdSet.containsAll(orderedIdSet)) {
          throw LibraryFailure.invalidCategoryReorder(
            expectedCount: expectedCount,
            actualCount: actualCount,
          );
        }

        await _db.batch((batch) {
          for (var i = 0; i < orderedCategoryIds.length; i++) {
            final catId = orderedCategoryIds[i];
            batch.update(
              _db.categories,
              CategoriesCompanion(sortOrder: Value(i)),
              where: (t) => t.id.equals(catId),
            );
          }
        });
      }),
    );
  }

  /// Creates library tag.
  @override
  Future<Tag> createTag(String name) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const LibraryFailure.invalidInput(
        LibraryInputFailureReason.emptyTagName,
      );
    }
    final normalized = normalizeMetadataName(trimmedName);

    return _wrapDb(
      () => _db.transaction(() async {
        final existing = await (_db.select(
          _db.tags,
        )..where((t) => t.normalizedName.equals(normalized))).getSingleOrNull();
        if (existing != null) {
          throw const LibraryFailure.duplicateTagName();
        }

        final id = _uuidGenerator();
        final now = _clock().toUtc();

        await _db
            .into(_db.tags)
            .insert(
              TagsCompanion.insert(
                id: id,
                name: trimmedName,
                normalizedName: normalized,
                createdAt: now,
              ),
            );

        return Tag(
          id: id,
          name: trimmedName,
          normalizedName: normalized,
          createdAt: now,
        );
      }),
    );
  }

  /// Renames library tag.
  @override
  Future<Tag> renameTag(String id, String newName) {
    final trimmedName = newName.trim();
    if (trimmedName.isEmpty) {
      throw const LibraryFailure.invalidInput(
        LibraryInputFailureReason.emptyTagName,
      );
    }
    final normalized = normalizeMetadataName(trimmedName);

    return _wrapDb(
      () => _db.transaction(() async {
        final existing = await (_db.select(
          _db.tags,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (existing == null) {
          throw LibraryFailure.tagNotFound(id: id);
        }

        final duplicate =
            await (_db.select(_db.tags)..where(
                  (t) =>
                      t.normalizedName.equals(normalized) &
                      t.id.equals(id).not(),
                ))
                .getSingleOrNull();
        if (duplicate != null) {
          throw const LibraryFailure.duplicateTagName();
        }

        if (existing.name != trimmedName ||
            existing.normalizedName != normalized) {
          await (_db.update(_db.tags)..where((t) => t.id.equals(id))).write(
            TagsCompanion(
              name: Value(trimmedName),
              normalizedName: Value(normalized),
            ),
          );
        }

        return Tag(
          id: existing.id,
          name: trimmedName,
          normalizedName: normalized,
          createdAt: existing.createdAt.toUtc(),
        );
      }),
    );
  }

  /// Deletes library tag.
  @override
  Future<void> deleteTag(String id) {
    return _wrapDb(
      () => _db.transaction(() async {
        final rowsAffected = await (_db.delete(
          _db.tags,
        )..where((t) => t.id.equals(id))).go();
        if (rowsAffected == 0) {
          throw LibraryFailure.tagNotFound(id: id);
        }
      }),
    );
  }

  /// Wraps database operations.
  Future<T> _wrapDb<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on LibraryFailure {
      rethrow;
    } on DriftWrappedException catch (error) {
      if (!_containsSqliteException(error)) rethrow;
      throw _mapDatabaseFailure(
        error,
        fallback: LibraryDatabaseFailureCode.transactionFailed,
      );
    } on SqliteException catch (error) {
      throw _mapDatabaseFailure(
        error,
        fallback: LibraryDatabaseFailureCode.transactionFailed,
      );
    }
  }

  /// Maps read error.
  static Object _mapReadError(Object error) {
    if (error is LibraryFailure) return error;
    if (_containsSqliteException(error)) {
      return _mapDatabaseFailure(
        error,
        fallback: LibraryDatabaseFailureCode.readFailed,
      );
    }
    return error;
  }

  /// Wraps database reads.
  Future<T> _wrapDbRead<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on LibraryFailure {
      rethrow;
    } on DriftWrappedException catch (error) {
      if (!_containsSqliteException(error)) rethrow;
      throw _mapDatabaseFailure(
        error,
        fallback: LibraryDatabaseFailureCode.readFailed,
      );
    } on SqliteException catch (error) {
      throw _mapDatabaseFailure(
        error,
        fallback: LibraryDatabaseFailureCode.readFailed,
      );
    }
  }

  /// Maps database failure.
  static LibraryFailure _mapDatabaseFailure(
    Object error, {
    required LibraryDatabaseFailureCode fallback,
  }) {
    if (_isDuplicateCategoryError(error)) {
      return const LibraryFailure.duplicateCategoryName();
    }
    if (_isDuplicateTagError(error)) {
      return const LibraryFailure.duplicateTagName();
    }
    if (_isConstraintError(error)) {
      return const LibraryFailure.databaseFailure(
        code: LibraryDatabaseFailureCode.constraintViolation,
      );
    }
    final sqlite = _findSqliteException(error);
    if (sqlite != null &&
        (sqlite.resultCode == _sqliteCorrupt ||
            sqlite.resultCode == _sqliteNotDatabase)) {
      return const LibraryFailure.databaseFailure(
        code: LibraryDatabaseFailureCode.corrupt,
      );
    }
    return LibraryFailure.databaseFailure(code: fallback);
  }

  /// Finds SQLite exception.
  static SqliteException? _findSqliteException(Object error) {
    if (error is SqliteException) return error;
    if (error is DriftWrappedException && error.cause != null) {
      return _findSqliteException(error.cause!);
    }
    return null;
  }

  /// Detects SQLite exception.
  static bool _containsSqliteException(Object error) {
    return _findSqliteException(error) != null;
  }

  /// Checks duplicate category error.
  static bool _isDuplicateCategoryError(Object error) {
    if (error is DriftWrappedException && error.cause != null) {
      return _isDuplicateCategoryError(error.cause!);
    }
    if (error is! SqliteException) return false;
    return error.extendedResultCode == _sqliteConstraintUnique &&
        error.message.toLowerCase().contains('categories.normalized_name');
  }

  /// Checks duplicate tag error.
  static bool _isDuplicateTagError(Object error) {
    if (error is DriftWrappedException && error.cause != null) {
      return _isDuplicateTagError(error.cause!);
    }
    if (error is! SqliteException) return false;
    return error.extendedResultCode == _sqliteConstraintUnique &&
        error.message.toLowerCase().contains('tags.normalized_name');
  }

  /// Checks constraint violation error.
  static bool _isConstraintError(Object error) {
    if (error is SqliteException) {
      return error.resultCode == 19 ||
          error.extendedResultCode == 1555 ||
          error.message.toLowerCase().contains('constraint');
    }
    if (error is DriftWrappedException) {
      final cause = error.cause;
      if (cause != null) {
        return _isConstraintError(cause);
      }
    }
    final errStr = error.toString().toLowerCase();
    return errStr.contains('constraint') || errStr.contains('unique');
  }

  /// Compares string lists.
  static bool _areListsEqual(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

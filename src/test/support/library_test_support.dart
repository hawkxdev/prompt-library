/// Shared library test support.
library;

import 'dart:async';

import 'package:prompt_library/src/library/data/library_repository.dart';
import 'package:prompt_library/src/library/models/category.dart';
import 'package:prompt_library/src/library/models/entry.dart';
import 'package:prompt_library/src/library/models/entry_input.dart';
import 'package:prompt_library/src/library/models/library_failure.dart';
import 'package:prompt_library/src/library/models/library_snapshot.dart';
import 'package:prompt_library/src/library/models/tag.dart';

/// Controllable in-memory repository.
final class TestLibraryRepository implements LibraryRepository {
  final StreamController<LibrarySnapshot> _snapshots =
      StreamController<LibrarySnapshot>.broadcast(sync: true);
  LibrarySnapshot _snapshot = const LibrarySnapshot.empty();
  int _nextId = 1;

  /// Recorded mutation calls.
  final List<String> calls = [];

  /// Next typed mutation failure.
  LibraryFailure? nextFailure;

  /// Blocks the next repository mutation until completed.
  Completer<void>? nextMutationGate;

  /// Emits a complete snapshot.
  void emit(LibrarySnapshot snapshot) {
    _snapshot = snapshot;
    _snapshots.add(snapshot);
  }

  /// Closes stream resources.
  Future<void> close() => _snapshots.close();

  Future<void> _failIfNeeded() async {
    final failure = nextFailure;
    nextFailure = null;
    if (failure != null) throw failure;
  }

  Future<void> _waitIfNeeded() async {
    final gate = nextMutationGate;
    nextMutationGate = null;
    await gate?.future;
  }

  void _publish({
    Iterable<Entry>? entries,
    Iterable<Category>? categories,
    Iterable<Tag>? tags,
  }) {
    emit(
      LibrarySnapshot(
        entries: entries ?? _snapshot.entries,
        categories: categories ?? _snapshot.categories,
        tags: tags ?? _snapshot.tags,
      ),
    );
  }

  @override
  Stream<LibrarySnapshot> watchSnapshot() => _snapshots.stream;

  @override
  Future<LibrarySnapshot> getSnapshot() async => _snapshot;

  @override
  Future<Entry> createEntry(EntryInput input) async {
    calls.add('createEntry');
    await _waitIfNeeded();
    await _failIfNeeded();
    final now = DateTime.utc(2026, 1, 1, 12, _nextId);
    final entry = Entry(
      id: 'entry-${_nextId++}',
      title: input.title,
      body: input.body,
      keyword: input.keyword,
      categoryId: input.categoryId,
      tagIds: input.tagIds,
      isFavorite: input.isFavorite,
      isArchived: input.isArchived,
      createdAt: now,
      updatedAt: now,
    );
    _publish(entries: [..._snapshot.entries, entry]);
    return entry;
  }

  @override
  Future<Entry> updateEntry(String id, EntryInput input) async {
    calls.add('updateEntry:$id');
    await _waitIfNeeded();
    await _failIfNeeded();
    final current = _snapshot.entries.singleWhere((entry) => entry.id == id);
    final updated = current.copyWith(
      title: input.title,
      body: input.body,
      keyword: input.keyword,
      categoryId: input.categoryId,
      tagIds: input.tagIds,
      isFavorite: input.isFavorite,
      isArchived: input.isArchived,
      updatedAt: current.updatedAt.add(const Duration(minutes: 1)),
    );
    _publish(
      entries: _snapshot.entries.map(
        (entry) => entry.id == id ? updated : entry,
      ),
    );
    return updated;
  }

  @override
  Future<void> deleteEntry(String id) async {
    calls.add('deleteEntry:$id');
    await _waitIfNeeded();
    await _failIfNeeded();
    _publish(entries: _snapshot.entries.where((entry) => entry.id != id));
  }

  @override
  Future<void> markCopied(String id) async {
    calls.add('markCopied:$id');
    await _failIfNeeded();
    _publish(
      entries: _snapshot.entries.map(
        (entry) => entry.id == id
            ? entry.copyWith(lastCopiedAt: DateTime.utc(2026, 1, 2))
            : entry,
      ),
    );
  }

  @override
  Future<void> setFavorite(String id, {required bool isFavorite}) async {
    calls.add('setFavorite:$id:$isFavorite');
    await _waitIfNeeded();
    await _failIfNeeded();
    _publish(
      entries: _snapshot.entries.map(
        (entry) =>
            entry.id == id ? entry.copyWith(isFavorite: isFavorite) : entry,
      ),
    );
  }

  @override
  Future<void> setArchived(String id, {required bool isArchived}) async {
    calls.add('setArchived:$id:$isArchived');
    await _waitIfNeeded();
    await _failIfNeeded();
    _publish(
      entries: _snapshot.entries.map(
        (entry) =>
            entry.id == id ? entry.copyWith(isArchived: isArchived) : entry,
      ),
    );
  }

  @override
  Future<Category> createCategory(String name) async {
    calls.add('createCategory');
    await _waitIfNeeded();
    await _failIfNeeded();
    final category = testCategory(
      'category-${_nextId++}',
      name,
      sortOrder: _snapshot.categories.length,
    );
    _publish(categories: [..._snapshot.categories, category]);
    return category;
  }

  @override
  Future<Category> renameCategory(String id, String newName) async {
    calls.add('renameCategory:$id');
    await _waitIfNeeded();
    await _failIfNeeded();
    final current = _snapshot.categories.singleWhere((value) => value.id == id);
    final updated = current.copyWith(
      name: newName,
      normalizedName: newName.toLowerCase(),
    );
    _publish(
      categories: _snapshot.categories.map(
        (value) => value.id == id ? updated : value,
      ),
    );
    return updated;
  }

  @override
  Future<void> deleteCategory(String id) async {
    calls.add('deleteCategory:$id');
    await _waitIfNeeded();
    await _failIfNeeded();
    _publish(
      categories: _snapshot.categories.where((value) => value.id != id),
      entries: _snapshot.entries.map(
        (entry) =>
            entry.categoryId == id ? entry.copyWith(categoryId: null) : entry,
      ),
    );
  }

  @override
  Future<void> reorderCategories(List<String> orderedCategoryIds) async {
    calls.add('reorderCategories');
    await _waitIfNeeded();
    await _failIfNeeded();
    final byId = {
      for (final category in _snapshot.categories) category.id: category,
    };
    _publish(
      categories: [
        for (var index = 0; index < orderedCategoryIds.length; index++)
          byId[orderedCategoryIds[index]]!.copyWith(sortOrder: index),
      ],
    );
  }

  @override
  Future<Tag> createTag(String name) async {
    calls.add('createTag');
    await _waitIfNeeded();
    await _failIfNeeded();
    final tag = testTag('tag-${_nextId++}', name);
    _publish(tags: [..._snapshot.tags, tag]);
    return tag;
  }

  @override
  Future<Tag> renameTag(String id, String newName) async {
    calls.add('renameTag:$id');
    await _waitIfNeeded();
    await _failIfNeeded();
    final current = _snapshot.tags.singleWhere((value) => value.id == id);
    final updated = current.copyWith(
      name: newName,
      normalizedName: newName.toLowerCase(),
    );
    _publish(
      tags: _snapshot.tags.map((value) => value.id == id ? updated : value),
    );
    return updated;
  }

  @override
  Future<void> deleteTag(String id) async {
    calls.add('deleteTag:$id');
    await _waitIfNeeded();
    await _failIfNeeded();
    _publish(
      tags: _snapshot.tags.where((value) => value.id != id),
      entries: _snapshot.entries.map(
        (entry) =>
            entry.copyWith(tagIds: entry.tagIds.where((tagId) => tagId != id)),
      ),
    );
  }
}

/// Creates deterministic entry.
Entry testEntry(
  String id, {
  String title = 'Prompt title',
  String body = 'Prompt body',
  String? categoryId,
  Iterable<String> tagIds = const [],
  bool isFavorite = false,
  bool isArchived = false,
}) {
  return Entry(
    id: id,
    title: title,
    body: body,
    categoryId: categoryId,
    tagIds: tagIds,
    isFavorite: isFavorite,
    isArchived: isArchived,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

/// Creates deterministic category.
Category testCategory(String id, String name, {int sortOrder = 0}) {
  return Category(
    id: id,
    name: name,
    normalizedName: name.toLowerCase(),
    sortOrder: sortOrder,
    createdAt: DateTime.utc(2026),
  );
}

/// Creates deterministic tag.
Tag testTag(String id, String name) {
  return Tag(
    id: id,
    name: name,
    normalizedName: name.toLowerCase(),
    createdAt: DateTime.utc(2026),
  );
}

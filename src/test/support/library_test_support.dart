/// Shared library test support.
library;

import 'dart:async';

import 'dart:typed_data';

import 'package:prompt_library/src/library/data/library_repository.dart';
import 'package:prompt_library/src/library/models/category.dart';
import 'package:prompt_library/src/library/models/entry.dart';
import 'package:prompt_library/src/library/models/entry_input.dart';
import 'package:prompt_library/src/library/models/entry_update.dart';
import 'package:prompt_library/src/library/models/library_failure.dart';
import 'package:prompt_library/src/library/models/library_snapshot.dart';
import 'package:prompt_library/src/library/models/tag.dart';
import 'package:prompt_library/src/library/presentation/library_document_files.dart';

/// Controllable in-memory repository.
final class TestLibraryRepository implements LibraryRepository {
  final StreamController<LibrarySnapshot> _snapshots =
      StreamController<LibrarySnapshot>.broadcast(sync: true);
  LibrarySnapshot _snapshot = const LibrarySnapshot.empty();
  int _nextId = 1;

  /// Recorded mutation calls.
  final List<String> calls = [];

  /// Captured update commands by entry identifier.
  final Map<String, EntryUpdate> savedUpdates = {};

  /// Next typed mutation failure.
  LibraryFailure? nextFailure;

  /// Next typed snapshot read failure.
  LibraryFailure? nextReadFailure;

  /// Blocks the next repository mutation until completed.
  Completer<void>? nextMutationGate;

  /// Blocks the next repository markCopied until completed.
  Completer<void>? nextMarkCopiedGate;

  /// Runs once after the next snapshot read has captured its result and
  /// before the reader resumes, modelling a publication in that window.
  void Function()? onNextRead;

  /// Emits a complete snapshot.
  void emit(LibrarySnapshot snapshot) {
    _snapshot = snapshot;
    _snapshots.add(snapshot);
  }

  /// Emits a typed failure on the snapshot stream.
  void emitFailure(LibraryFailure failure) {
    _snapshots.addError(failure);
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
  Future<LibrarySnapshot> getSnapshot() async {
    final failure = nextReadFailure;
    nextReadFailure = null;
    if (failure != null) throw failure;
    final captured = _snapshot;
    final hook = onNextRead;
    onNextRead = null;
    hook?.call();
    return captured;
  }

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
  Future<LibrarySnapshot> restoreSnapshot({
    required LibrarySnapshot expectedCurrent,
    required LibrarySnapshot replacement,
  }) async {
    calls.add('restoreSnapshot');
    await _waitIfNeeded();
    await _failIfNeeded();
    if (_snapshot != expectedCurrent) {
      throw const LibraryFailure.staleSnapshot();
    }
    _publish(
      entries: replacement.entries,
      categories: replacement.categories,
      tags: replacement.tags,
    );
    return _snapshot;
  }

  @override
  Future<List<Entry>> addRaycastEntries({
    required LibrarySnapshot expectedCurrent,
    required List<RaycastEntryDraft> drafts,
  }) async {
    calls.add('addRaycastEntries');
    await _waitIfNeeded();
    await _failIfNeeded();
    if (_snapshot != expectedCurrent) {
      throw const LibraryFailure.staleSnapshot();
    }
    final now = DateTime.utc(2026, 1, 1, 12, _nextId);
    final created = <Entry>[];
    final entries = [..._snapshot.entries];
    for (final draft in drafts) {
      final entry = Entry(
        id: 'entry-${_nextId++}',
        title: draft.title,
        body: draft.body,
        keyword: draft.keyword,
        createdAt: now,
        updatedAt: now,
      );
      entries.add(entry);
      created.add(entry);
    }
    _publish(entries: entries);
    return List.unmodifiable(created);
  }

  @override
  Future<Entry> updateEntryDetails(String id, EntryUpdate update) async {
    calls.add('updateEntryDetails:$id');
    savedUpdates[id] = update;
    await _waitIfNeeded();
    await _failIfNeeded();
    final current = _snapshot.entries.singleWhere((entry) => entry.id == id);
    var nextKeyword = current.keyword;
    final intent = update.keyword;
    if (intent is ReplaceKeyword) {
      final trimmed = intent.value?.trim();
      nextKeyword = (trimmed != null && trimmed.isNotEmpty) ? trimmed : null;
    }
    final updated = current.copyWith(
      title: update.title,
      body: update.body,
      keyword: nextKeyword,
      categoryId: update.categoryId,
      tagIds: update.tagIds,
      isFavorite: update.isFavorite,
      isArchived: update.isArchived,
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
    final gate = nextMarkCopiedGate;
    nextMarkCopiedGate = null;
    await gate?.future;
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
  String? keyword,
  String? categoryId,
  Iterable<String> tagIds = const [],
  bool isFavorite = false,
  bool isArchived = false,
  DateTime? lastCopiedAt,
}) {
  return Entry(
    id: id,
    title: title,
    body: body,
    keyword: keyword,
    categoryId: categoryId,
    tagIds: tagIds,
    isFavorite: isFavorite,
    isArchived: isArchived,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    lastCopiedAt: lastCopiedAt,
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

/// Queueing fake of the document file boundary.
final class TestDocumentFiles implements LibraryDocumentFiles {
  /// Result returned by the next pick call.
  DocumentPickResult? pickResult;

  /// Result returned by the next export call.
  DocumentExportResult? exportResult;

  /// Kind recorded by the last export call.
  DocumentExportKind? lastKind;

  /// Blocks the next pick call until completed.
  Completer<void>? pickGate;

  /// Blocks the next export call until completed.
  Completer<void>? exportGate;

  /// Recorded boundary calls.
  final List<String> calls = [];

  @override
  Future<DocumentPickResult> pickDocument() async {
    calls.add('pickDocument');
    final gate = pickGate;
    if (gate != null) {
      await gate.future;
    }
    return pickResult!;
  }

  @override
  Future<DocumentExportResult> exportDocument({
    required DocumentExportKind kind,
    required String suggestedName,
    required Uint8List bytes,
  }) async {
    calls.add('exportDocument:$suggestedName');
    lastKind = kind;
    final gate = exportGate;
    if (gate != null) {
      await gate.future;
    }
    return exportResult!;
  }
}

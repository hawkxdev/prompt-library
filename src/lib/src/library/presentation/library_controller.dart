/// Library state controller.
library;

import 'dart:async';

import '../data/library_repository.dart';
import '../models/entry_input.dart';
import '../models/library_failure.dart';
import '../models/library_snapshot.dart';
import 'derived_visible_entries.dart';
import 'library_filter.dart';
import 'library_state.dart';

/// Coordinates library state.
final class LibraryController {
  /// Creates library controller.
  factory LibraryController({required LibraryRepository repository}) {
    return LibraryController._(repository);
  }

  /// Creates internal controller.
  LibraryController._(this._repository)
    : _state = LibraryState.loading(),
      _statesController = StreamController<LibraryState>.broadcast() {
    _snapshotSubscription = _repository.watchSnapshot().listen(
      _handleSnapshot,
      onError: _handleSnapshotError,
    );
  }

  final LibraryRepository _repository;
  final StreamController<LibraryState> _statesController;
  final Map<LibraryMutationKey, Future<void>> _inFlightMutations = {};

  StreamSubscription<LibrarySnapshot>? _snapshotSubscription;
  LibraryState _state;
  Future<void>? _disposeFuture;
  bool _isDisposed = false;

  /// Returns current state.
  LibraryState get state => _state;

  /// Whether lifecycle teardown has started.
  bool get isDisposed => _isDisposed;

  /// Publishes future states.
  Stream<LibraryState> get states => _statesController.stream;

  /// Replaces current filter.
  void setFilter(LibraryFilter filter) {
    _ensureActive();
    if (filter == _state.filter) {
      return;
    }
    _applyFilter(filter);
  }

  /// Updates search query.
  void updateSearchQuery(String query) {
    setFilter(_state.filter.copyWith(searchQuery: query));
  }

  /// Updates filter scope.
  void setFilterScope(LibraryFilterScope scope) {
    setFilter(_state.filter.copyWith(scope: scope));
  }

  /// Updates category filter.
  void setCategoryFilter(String? categoryId) {
    setFilter(_state.filter.copyWith(categoryId: categoryId));
  }

  /// Updates tag filter.
  void setTagFilter(List<String> tagIds) {
    setFilter(_state.filter.copyWith(tagIds: tagIds));
  }

  /// Selects visible entry.
  void selectEntry(String? id) {
    _ensureActive();
    if (id != null && !_state.visibleEntries.any((entry) => entry.id == id)) {
      throw ArgumentError.value(id, 'id');
    }
    if (_state.selectedEntryId == id) {
      return;
    }
    _emit(_state.copyWith(selectedEntryId: id));
  }

  /// Dismisses current failure.
  void dismissFailure() {
    _ensureActive();
    _emit(_state.dismissFailure());
  }

  /// Creates library entry.
  Future<void> createEntry(EntryInput input) {
    return _runMutation(
      const LibraryMutationKey(LibraryMutationKind.createEntry),
      () async {
        await _repository.createEntry(input);
      },
    );
  }

  /// Updates library entry.
  Future<void> updateEntry(String id, EntryInput input) {
    return _runMutation(
      LibraryMutationKey(LibraryMutationKind.updateEntry, entityId: id),
      () async {
        await _repository.updateEntry(id, input);
      },
    );
  }

  /// Deletes library entry.
  Future<void> deleteEntry(String id) {
    return _runMutation(
      LibraryMutationKey(LibraryMutationKind.deleteEntry, entityId: id),
      () => _repository.deleteEntry(id),
    );
  }

  /// Records copied entry.
  Future<void> markCopied(String id) {
    return _runMutation(
      LibraryMutationKey(LibraryMutationKind.markCopied, entityId: id),
      () => _repository.markCopied(id),
    );
  }

  /// Updates favorite state.
  Future<void> setFavorite(String id, {required bool isFavorite}) {
    return _runMutation(
      LibraryMutationKey(LibraryMutationKind.setFavorite, entityId: id),
      () => _repository.setFavorite(id, isFavorite: isFavorite),
    );
  }

  /// Updates archive state.
  Future<void> setArchived(String id, {required bool isArchived}) {
    return _runMutation(
      LibraryMutationKey(LibraryMutationKind.setArchived, entityId: id),
      () => _repository.setArchived(id, isArchived: isArchived),
    );
  }

  /// Creates library category.
  Future<void> createCategory(String name) {
    return _runMutation(
      const LibraryMutationKey(LibraryMutationKind.createCategory),
      () async {
        await _repository.createCategory(name);
      },
    );
  }

  /// Renames library category.
  Future<void> renameCategory(String id, String newName) {
    return _runMutation(
      LibraryMutationKey(LibraryMutationKind.renameCategory, entityId: id),
      () async {
        await _repository.renameCategory(id, newName);
      },
    );
  }

  /// Deletes library category.
  Future<void> deleteCategory(String id) {
    return _runMutation(
      LibraryMutationKey(LibraryMutationKind.deleteCategory, entityId: id),
      () => _repository.deleteCategory(id),
    );
  }

  /// Reorders library categories.
  Future<void> reorderCategories(List<String> orderedCategoryIds) {
    return _runMutation(
      const LibraryMutationKey(LibraryMutationKind.reorderCategories),
      () => _repository.reorderCategories(orderedCategoryIds),
    );
  }

  /// Creates library tag.
  Future<void> createTag(String name) {
    return _runMutation(
      const LibraryMutationKey(LibraryMutationKind.createTag),
      () async {
        await _repository.createTag(name);
      },
    );
  }

  /// Renames library tag.
  Future<void> renameTag(String id, String newName) {
    return _runMutation(
      LibraryMutationKey(LibraryMutationKind.renameTag, entityId: id),
      () async {
        await _repository.renameTag(id, newName);
      },
    );
  }

  /// Deletes library tag.
  Future<void> deleteTag(String id) {
    return _runMutation(
      LibraryMutationKey(LibraryMutationKind.deleteTag, entityId: id),
      () => _repository.deleteTag(id),
    );
  }

  /// Disposes controller resources.
  Future<void> dispose() {
    return _disposeFuture ??= _dispose();
  }

  /// Applies current filter.
  void _applyFilter(LibraryFilter filter) {
    final snapshot = _state.snapshot;
    final visibleEntries = snapshot == null
        ? const <Never>[]
        : deriveVisibleEntries(snapshot, filter);
    final selectedEntryId = resolveSelectedEntryId(
      visibleEntries: visibleEntries,
      currentSelectedId: _state.selectedEntryId,
    );
    _emit(
      _state.copyWith(
        filter: filter,
        visibleEntries: visibleEntries,
        selectedEntryId: selectedEntryId,
      ),
    );
  }

  /// Handles repository snapshot.
  void _handleSnapshot(LibrarySnapshot snapshot) {
    if (_isDisposed) {
      return;
    }
    final visibleEntries = deriveVisibleEntries(snapshot, _state.filter);
    final selectedEntryId = resolveSelectedEntryId(
      visibleEntries: visibleEntries,
      currentSelectedId: _state.selectedEntryId,
    );
    _emit(
      _state.copyWith(
        loadStatus: LibraryLoadStatus.ready,
        snapshot: snapshot,
        visibleEntries: visibleEntries,
        selectedEntryId: selectedEntryId,
        failure: null,
      ),
    );
  }

  /// Handles repository error.
  void _handleSnapshotError(Object error, StackTrace stackTrace) {
    if (_isDisposed) {
      return;
    }
    if (error case final LibraryFailure failure) {
      _emit(_state.withFailure(failure));
      return;
    }
    _statesController.addError(error, stackTrace);
  }

  /// Runs guarded mutation.
  Future<void> _runMutation(
    LibraryMutationKey key,
    Future<void> Function() operation,
  ) {
    _ensureActive();
    final existing = _inFlightMutations[key];
    if (existing != null) {
      return existing;
    }
    final future = _executeMutation(key, operation);
    _inFlightMutations[key] = future;
    return future;
  }

  /// Executes guarded mutation.
  Future<void> _executeMutation(
    LibraryMutationKey key,
    Future<void> Function() operation,
  ) async {
    _emit(_state.startMutation(key));
    try {
      await operation();
      if (!_isDisposed) {
        _emit(_state.dismissFailure());
      }
    } on LibraryFailure catch (failure) {
      if (!_isDisposed) {
        _emit(_state.withFailure(failure));
      }
      rethrow;
    } finally {
      _inFlightMutations.remove(key);
      if (!_isDisposed) {
        _emit(_state.finishMutation(key));
      }
    }
  }

  /// Publishes state transition.
  void _emit(LibraryState nextState) {
    if (_isDisposed || nextState == _state) {
      return;
    }
    _state = nextState;
    _statesController.add(nextState);
  }

  /// Validates active lifecycle.
  void _ensureActive() {
    if (_isDisposed) {
      throw StateError('LibraryController is disposed');
    }
  }

  /// Performs resource disposal.
  Future<void> _dispose() async {
    _isDisposed = true;
    final subscription = _snapshotSubscription;
    _snapshotSubscription = null;
    await subscription?.cancel();
    await _statesController.close();
  }
}

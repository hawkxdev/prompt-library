/// Library state models.
library;

import '../models/entry.dart';
import '../models/library_failure.dart';
import '../models/library_snapshot.dart';
import 'library_filter.dart';

/// Library loading phases.
enum LibraryLoadStatus {
  /// Snapshot loading state.
  loading,

  /// Snapshot available state.
  ready,

  /// Initial loading failure.
  failure,
}

/// Library mutation kinds.
enum LibraryMutationKind {
  /// Creates entry.
  createEntry,

  /// Updates entry.
  updateEntry,

  /// Deletes entry.
  deleteEntry,

  /// Records entry copy.
  markCopied,

  /// Changes favorite state.
  setFavorite,

  /// Changes archive state.
  setArchived,

  /// Creates category.
  createCategory,

  /// Renames category.
  renameCategory,

  /// Deletes category.
  deleteCategory,

  /// Reorders categories.
  reorderCategories,

  /// Creates tag.
  createTag,

  /// Renames tag.
  renameTag,

  /// Deletes tag.
  deleteTag,
}

/// Identifies pending mutation.
final class LibraryMutationKey implements Comparable<LibraryMutationKey> {
  /// Creates mutation key.
  const LibraryMutationKey(this.kind, {this.entityId});

  /// Mutation operation kind.
  final LibraryMutationKind kind;

  /// Optional entity identifier.
  final String? entityId;

  @override
  int compareTo(LibraryMutationKey other) {
    final kindComparison = kind.index.compareTo(other.kind.index);
    if (kindComparison != 0) {
      return kindComparison;
    }
    final ownId = entityId;
    final otherId = other.entityId;
    if (ownId == null) {
      return otherId == null ? 0 : -1;
    }
    if (otherId == null) {
      return 1;
    }
    return ownId.compareTo(otherId);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LibraryMutationKey &&
            other.kind == kind &&
            other.entityId == entityId;
  }

  @override
  int get hashCode => Object.hash(kind, entityId);
}

/// Immutable library state.
final class LibraryState {
  /// Creates library state.
  LibraryState({
    required this.loadStatus,
    this.snapshot,
    LibraryFilter? filter,
    Iterable<Entry> visibleEntries = const [],
    this.selectedEntryId,
    Iterable<LibraryMutationKey> activeMutations = const [],
    this.failure,
  }) : filter = filter ?? LibraryFilter(),
       visibleEntries = _freezeEntries(visibleEntries),
       activeMutations = _freezeMutationKeys(activeMutations);

  static const Object _unset = Object();

  /// Creates loading state.
  factory LibraryState.loading({LibraryFilter? filter}) {
    return LibraryState(loadStatus: LibraryLoadStatus.loading, filter: filter);
  }

  /// Current loading phase.
  final LibraryLoadStatus loadStatus;

  /// Latest usable snapshot.
  final LibrarySnapshot? snapshot;

  /// Current library filter.
  final LibraryFilter filter;

  /// Materialized visible entries.
  final List<Entry> visibleEntries;

  /// Selected entry identifier.
  final String? selectedEntryId;

  /// Pending mutation keys.
  final List<LibraryMutationKey> activeMutations;

  /// Current typed failure.
  final LibraryFailure? failure;

  /// Whether snapshot exists.
  bool get hasUsableSnapshot => snapshot != null;

  /// Whether mutation is active.
  bool isMutationActive(LibraryMutationKey key) {
    return activeMutations.contains(key);
  }

  /// Starts pending mutation.
  LibraryState startMutation(LibraryMutationKey key) {
    if (isMutationActive(key)) {
      return this;
    }
    return copyWith(activeMutations: [...activeMutations, key]);
  }

  /// Finishes pending mutation.
  LibraryState finishMutation(LibraryMutationKey key) {
    if (!isMutationActive(key)) {
      return this;
    }
    return copyWith(
      activeMutations: activeMutations.where((active) => active != key),
    );
  }

  /// Records typed failure.
  LibraryState withFailure(LibraryFailure failure) {
    return copyWith(
      loadStatus: snapshot == null ? LibraryLoadStatus.failure : loadStatus,
      failure: failure,
    );
  }

  /// Dismisses current failure.
  LibraryState dismissFailure() {
    if (failure == null) {
      return this;
    }
    return copyWith(
      loadStatus: snapshot == null ? LibraryLoadStatus.loading : loadStatus,
      failure: null,
    );
  }

  /// Copies state values.
  LibraryState copyWith({
    LibraryLoadStatus? loadStatus,
    Object? snapshot = _unset,
    LibraryFilter? filter,
    Iterable<Entry>? visibleEntries,
    Object? selectedEntryId = _unset,
    Iterable<LibraryMutationKey>? activeMutations,
    Object? failure = _unset,
  }) {
    return LibraryState(
      loadStatus: loadStatus ?? this.loadStatus,
      snapshot: identical(snapshot, _unset)
          ? this.snapshot
          : snapshot as LibrarySnapshot?,
      filter: filter ?? this.filter,
      visibleEntries: visibleEntries ?? this.visibleEntries,
      selectedEntryId: identical(selectedEntryId, _unset)
          ? this.selectedEntryId
          : selectedEntryId as String?,
      activeMutations: activeMutations ?? this.activeMutations,
      failure: identical(failure, _unset)
          ? this.failure
          : failure as LibraryFailure?,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LibraryState &&
            other.loadStatus == loadStatus &&
            other.snapshot == snapshot &&
            other.filter == filter &&
            _listEquals(other.visibleEntries, visibleEntries) &&
            other.selectedEntryId == selectedEntryId &&
            _listEquals(other.activeMutations, activeMutations) &&
            other.failure == failure;
  }

  @override
  int get hashCode {
    return Object.hash(
      loadStatus,
      snapshot,
      filter,
      Object.hashAll(visibleEntries),
      selectedEntryId,
      Object.hashAll(activeMutations),
      failure,
    );
  }
}

/// Freezes visible entries.
List<Entry> _freezeEntries(Iterable<Entry> entries) {
  if (entries.isEmpty) {
    return const [];
  }
  return List.unmodifiable(entries);
}

/// Freezes mutation keys.
List<LibraryMutationKey> _freezeMutationKeys(
  Iterable<LibraryMutationKey> keys,
) {
  final values = keys.toSet().toList()..sort();
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

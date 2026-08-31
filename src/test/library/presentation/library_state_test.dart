/// Library state tests.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/library/models/entry.dart';
import 'package:prompt_library/src/library/models/library_failure.dart';
import 'package:prompt_library/src/library/models/library_snapshot.dart';
import 'package:prompt_library/src/library/presentation/library_filter.dart';
import 'package:prompt_library/src/library/presentation/library_state.dart';

void main() {
  // === Mutation key tests ===
  group('LibraryMutationKey', () {
    test('uses kind and entity identifier for value equality', () {
      const first = LibraryMutationKey(
        LibraryMutationKind.updateEntry,
        entityId: 'entry-1',
      );
      const same = LibraryMutationKey(
        LibraryMutationKind.updateEntry,
        entityId: 'entry-1',
      );
      const otherKind = LibraryMutationKey(
        LibraryMutationKind.deleteEntry,
        entityId: 'entry-1',
      );
      const otherId = LibraryMutationKey(
        LibraryMutationKind.updateEntry,
        entityId: 'entry-2',
      );

      expect(first, same);
      expect(first.hashCode, same.hashCode);
      expect(first, isNot(otherKind));
      expect(first, isNot(otherId));
    });
  });

  // === State construction tests ===
  group('LibraryState', () {
    test('starts loading without a usable snapshot', () {
      final state = LibraryState.loading();

      expect(state.loadStatus, LibraryLoadStatus.loading);
      expect(state.snapshot, isNull);
      expect(state.visibleEntries, isEmpty);
      expect(state.selectedEntryId, isNull);
      expect(state.activeMutations, isEmpty);
      expect(state.failure, isNull);
      expect(state.hasUsableSnapshot, isFalse);
    });

    test('copies and freezes visible entries and mutation keys', () {
      final entry = _entry('entry-1');
      final visibleEntries = <Entry>[entry];
      final activeMutations = <LibraryMutationKey>[
        const LibraryMutationKey(
          LibraryMutationKind.updateEntry,
          entityId: 'entry-1',
        ),
      ];
      final state = LibraryState(
        loadStatus: LibraryLoadStatus.ready,
        snapshot: LibrarySnapshot(entries: [entry]),
        visibleEntries: visibleEntries,
        selectedEntryId: entry.id,
        activeMutations: activeMutations,
      );

      visibleEntries.clear();
      activeMutations.clear();

      expect(state.visibleEntries, [entry]);
      expect(state.activeMutations, hasLength(1));
      expect(() => state.visibleEntries.clear(), throwsUnsupportedError);
      expect(() => state.activeMutations.clear(), throwsUnsupportedError);
      expect(state.hasUsableSnapshot, isTrue);
    });

    test('canonicalizes mutation key order and removes duplicates', () {
      const first = LibraryMutationKey(
        LibraryMutationKind.deleteEntry,
        entityId: 'entry-2',
      );
      const second = LibraryMutationKey(
        LibraryMutationKind.updateEntry,
        entityId: 'entry-1',
      );
      final state = LibraryState(
        loadStatus: LibraryLoadStatus.loading,
        activeMutations: const [first, second, first],
      );

      expect(state.activeMutations, [second, first]);
    });

    test('supports value equality and matching hash codes', () {
      final entry = _entry('entry-1');
      final snapshot = LibrarySnapshot(entries: [entry]);
      final first = LibraryState(
        loadStatus: LibraryLoadStatus.ready,
        snapshot: snapshot,
        filter: LibraryFilter(searchQuery: 'query'),
        visibleEntries: [entry],
        selectedEntryId: entry.id,
      );
      final second = LibraryState(
        loadStatus: LibraryLoadStatus.ready,
        snapshot: snapshot,
        filter: LibraryFilter(searchQuery: 'query'),
        visibleEntries: [entry],
        selectedEntryId: entry.id,
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('copyWith preserves and explicitly clears nullable fields', () {
      final entry = _entry('entry-1');
      final failure = LibraryFailure.databaseFailure(
        code: LibraryDatabaseFailureCode.readFailed,
      );
      final state = LibraryState(
        loadStatus: LibraryLoadStatus.ready,
        snapshot: LibrarySnapshot(entries: [entry]),
        visibleEntries: [entry],
        selectedEntryId: entry.id,
        failure: failure,
      );

      final preserved = state.copyWith(filter: LibraryFilter());
      final cleared = preserved.copyWith(
        snapshot: null,
        selectedEntryId: null,
        failure: null,
      );

      expect(preserved.snapshot, state.snapshot);
      expect(preserved.selectedEntryId, entry.id);
      expect(preserved.failure, failure);
      expect(cleared.snapshot, isNull);
      expect(cleared.selectedEntryId, isNull);
      expect(cleared.failure, isNull);
    });
  });

  // === Transition tests ===
  group('LibraryState transitions', () {
    final failure = LibraryFailure.databaseFailure(
      code: LibraryDatabaseFailureCode.transactionFailed,
    );
    const updateKey = LibraryMutationKey(
      LibraryMutationKind.updateEntry,
      entityId: 'entry-1',
    );
    const deleteKey = LibraryMutationKey(
      LibraryMutationKind.deleteEntry,
      entityId: 'entry-2',
    );

    test('adds deduplicates and removes exact mutation keys', () {
      final started = LibraryState.loading()
          .startMutation(updateKey)
          .startMutation(updateKey)
          .startMutation(deleteKey);
      final completed = started.finishMutation(updateKey);

      expect(started.activeMutations, [updateKey, deleteKey]);
      expect(completed.activeMutations, [deleteKey]);
      expect(completed.isMutationActive(updateKey), isFalse);
      expect(completed.isMutationActive(deleteKey), isTrue);
    });

    test('retains usable state when recording a failure', () {
      final entry = _entry('entry-1');
      final snapshot = LibrarySnapshot(entries: [entry]);
      final state = LibraryState(
        loadStatus: LibraryLoadStatus.ready,
        snapshot: snapshot,
        filter: LibraryFilter(searchQuery: 'query'),
        visibleEntries: [entry],
        selectedEntryId: entry.id,
      );

      final failed = state.withFailure(failure);

      expect(failed.loadStatus, LibraryLoadStatus.ready);
      expect(failed.snapshot, snapshot);
      expect(failed.filter, state.filter);
      expect(failed.visibleEntries, [entry]);
      expect(failed.selectedEntryId, entry.id);
      expect(failed.failure, failure);
    });

    test('marks failure before the first usable snapshot', () {
      final failed = LibraryState.loading().withFailure(failure);

      expect(failed.loadStatus, LibraryLoadStatus.failure);
      expect(failed.snapshot, isNull);
      expect(failed.failure, failure);
    });

    test('dismisses only the current failure', () {
      final entry = _entry('entry-1');
      final state = LibraryState(
        loadStatus: LibraryLoadStatus.ready,
        snapshot: LibrarySnapshot(entries: [entry]),
        visibleEntries: [entry],
        selectedEntryId: entry.id,
        failure: failure,
      );

      final dismissed = state.dismissFailure();

      expect(dismissed.failure, isNull);
      expect(dismissed.snapshot, state.snapshot);
      expect(dismissed.visibleEntries, state.visibleEntries);
      expect(dismissed.selectedEntryId, state.selectedEntryId);
    });
  });
}

/// Creates deterministic entry.
Entry _entry(String id) {
  return Entry(
    id: id,
    title: 'Entry $id',
    body: 'Body $id',
    createdAt: DateTime.utc(2026, 8, 25),
    updatedAt: DateTime.utc(2026, 8, 25),
  );
}

/// Library controller tests.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/library/data/library_repository.dart';
import 'package:prompt_library/src/library/models/category.dart';
import 'package:prompt_library/src/library/models/entry.dart';
import 'package:prompt_library/src/library/models/entry_input.dart';
import 'package:prompt_library/src/library/models/entry_update.dart';
import 'package:prompt_library/src/library/models/library_failure.dart';
import 'package:prompt_library/src/library/models/library_snapshot.dart';
import 'package:prompt_library/src/library/models/tag.dart';
import 'package:prompt_library/src/library/presentation/library_controller.dart';
import 'package:prompt_library/src/library/presentation/library_clipboard.dart';
import 'package:prompt_library/src/library/presentation/library_filter.dart';
import 'package:prompt_library/src/library/presentation/library_state.dart';

void main() {
  late _FakeLibraryRepository repository;
  late _FakeClipboard clipboard;
  late LibraryController controller;

  setUp(() {
    repository = _FakeLibraryRepository();
    controller = LibraryController(repository: repository);
    clipboard = _FakeClipboard();
  });
  tearDown(() async {
    await controller.dispose();
    await repository.close();
  });

  // === Snapshot lifecycle tests ===
  group('LibraryController snapshots', () {
    test('loads snapshot and publishes matching current state', () async {
      final entry = _entry('entry-1');
      final states = <LibraryState>[];
      final subscription = controller.states.listen(states.add);

      repository.emit(LibrarySnapshot(entries: [entry]));
      await pumpEventQueue();

      expect(controller.state.loadStatus, LibraryLoadStatus.ready);
      expect(controller.state.snapshot, isNotNull);
      expect(controller.state.visibleEntries, [entry]);
      expect(controller.state.selectedEntryId, entry.id);
      expect(states, [controller.state]);

      await subscription.cancel();
    });

    test(
      'requires synchronous state read because stream does not replay',
      () async {
        repository.emit(LibrarySnapshot(entries: [_entry('entry-1')]));
        await pumpEventQueue();

        final current = controller.state;
        final laterStates = <LibraryState>[];
        final subscription = controller.states.listen(laterStates.add);
        await pumpEventQueue();

        expect(current.loadStatus, LibraryLoadStatus.ready);
        expect(laterStates, isEmpty);

        repository.emit(LibrarySnapshot(entries: [_entry('entry-2')]));
        await pumpEventQueue();

        expect(laterStates, [controller.state]);
        await subscription.cancel();
      },
    );

    test('distinguishes initial failure and later retained failure', () async {
      final initialFailure = LibraryFailure.databaseFailure(
        code: LibraryDatabaseFailureCode.readFailed,
      );
      repository.emitError(initialFailure);
      await pumpEventQueue();

      expect(controller.state.loadStatus, LibraryLoadStatus.failure);
      expect(controller.state.snapshot, isNull);
      expect(controller.state.failure, initialFailure);

      final entry = _entry('entry-1');
      repository.emit(LibrarySnapshot(entries: [entry]));
      await pumpEventQueue();

      expect(controller.state.loadStatus, LibraryLoadStatus.ready);
      expect(controller.state.failure, isNull);

      final laterFailure = LibraryFailure.databaseFailure(
        code: LibraryDatabaseFailureCode.readFailed,
      );
      repository.emitError(laterFailure);
      await pumpEventQueue();

      expect(controller.state.loadStatus, LibraryLoadStatus.ready);
      expect(controller.state.snapshot?.entries, [entry]);
      expect(controller.state.visibleEntries, [entry]);
      expect(controller.state.failure, laterFailure);
    });

    test('forwards unexpected stream errors without changing state', () async {
      final error = StateError('unexpected');
      final errorExpectation = expectLater(
        controller.states,
        emitsError(same(error)),
      );

      repository.emitError(error);
      await errorExpectation;

      expect(controller.state.loadStatus, LibraryLoadStatus.loading);
      expect(controller.state.failure, isNull);
    });
  });

  // === Intent tests ===
  group('LibraryController intents', () {
    test('updates filters and selection synchronously', () async {
      final first = _entry('first', title: 'Alpha');
      final second = _entry('second', title: 'Beta');
      repository.emit(LibrarySnapshot(entries: [first, second]));
      await pumpEventQueue();

      controller.selectEntry('second');
      controller.updateSearchQuery('Alpha');

      expect(controller.state.filter.searchQuery, 'Alpha');
      expect(controller.state.visibleEntries, [first]);
      expect(controller.state.selectedEntryId, 'first');

      controller.setFilterScope(LibraryFilterScope.archived);
      expect(controller.state.visibleEntries, isEmpty);
      expect(controller.state.selectedEntryId, isNull);
    });

    test('rejects selection outside visible entries', () async {
      repository.emit(LibrarySnapshot(entries: [_entry('entry-1')]));
      await pumpEventQueue();

      expect(() => controller.selectEntry('missing'), throwsArgumentError);
    });
  });

  // === Mutation tests ===
  group('LibraryController mutations', () {
    test('routes every repository mutation', () async {
      final input = _input();

      await controller.createEntry(input);
      await controller.updateEntry('entry-1', input);
      await controller.deleteEntry('entry-1');
      await controller.markCopied('entry-1');
      await controller.setFavorite('entry-1', isFavorite: true);
      await controller.setArchived('entry-1', isArchived: true);
      await controller.createCategory('Category');
      await controller.renameCategory('category-1', 'Renamed');
      await controller.deleteCategory('category-1');
      await controller.reorderCategories(const ['category-1']);
      await controller.createTag('Tag');
      await controller.renameTag('tag-1', 'Renamed');
      await controller.deleteTag('tag-1');

      expect(repository.calls, [
        'createEntry',
        'updateEntry:entry-1',
        'deleteEntry:entry-1',
        'markCopied:entry-1',
        'setFavorite:entry-1:true',
        'setArchived:entry-1:true',
        'createCategory',
        'renameCategory:category-1',
        'deleteCategory:category-1',
        'reorderCategories',
        'createTag',
        'renameTag:tag-1',
        'deleteTag:tag-1',
      ]);
      expect(controller.state.activeMutations, isEmpty);
    });

    test('deduplicates the same in-flight mutation key', () async {
      final gate = repository.block('updateEntry:entry-1');

      final first = controller.updateEntry('entry-1', _input());
      final duplicate = controller.updateEntry('entry-1', _input());

      expect(identical(first, duplicate), isTrue);
      expect(repository.calls, ['updateEntry:entry-1']);
      expect(
        controller.state.isMutationActive(
          const LibraryMutationKey(
            LibraryMutationKind.updateEntry,
            entityId: 'entry-1',
          ),
        ),
        isTrue,
      );

      gate.complete();
      await Future.wait([first, duplicate]);
      expect(controller.state.activeMutations, isEmpty);
    });

    test('allows independent mutation keys concurrently', () async {
      final updateGate = repository.block('updateEntry:entry-1');
      final deleteGate = repository.block('deleteEntry:entry-2');

      final update = controller.updateEntry('entry-1', _input());
      final delete = controller.deleteEntry('entry-2');

      expect(repository.calls, ['updateEntry:entry-1', 'deleteEntry:entry-2']);
      expect(controller.state.activeMutations, hasLength(2));

      updateGate.complete();
      deleteGate.complete();
      await Future.wait([update, delete]);
      expect(controller.state.activeMutations, isEmpty);
    });

    test('retains usable state for typed mutation failure', () async {
      final entry = _entry('entry-1');
      repository.emit(LibrarySnapshot(entries: [entry]));
      await pumpEventQueue();
      final failure = LibraryFailure.databaseFailure(
        code: LibraryDatabaseFailureCode.transactionFailed,
      );
      repository.failNext('deleteEntry:entry-1', failure);

      await expectLater(
        controller.deleteEntry('entry-1'),
        throwsA(same(failure)),
      );

      expect(controller.state.snapshot?.entries, [entry]);
      expect(controller.state.visibleEntries, [entry]);
      expect(controller.state.failure, failure);
      expect(controller.state.activeMutations, isEmpty);

      controller.dismissFailure();
      expect(controller.state.failure, isNull);
    });

    test('propagates unexpected mutation errors and releases key', () async {
      final error = StateError('programming error');
      repository.failNext('deleteEntry:entry-1', error);

      await expectLater(
        controller.deleteEntry('entry-1'),
        throwsA(same(error)),
      );

      expect(controller.state.failure, isNull);
      expect(controller.state.activeMutations, isEmpty);
    });
  });
  // === Maintenance tests ===
  group('LibraryController maintenance', () {
    test('rejects new mutations while maintenance is active', () async {
      repository.emit(LibrarySnapshot(entries: [_entry('entry-1')]));
      await pumpEventQueue();

      await controller.beginMaintenance();
      expect(controller.state.isUnderMaintenance, isTrue);
      expect(() => controller.deleteEntry('entry-1'), throwsStateError);
      expect(repository.calls, isNot(contains('deleteEntry:entry-1')));

      controller.endMaintenance();
      expect(controller.state.isUnderMaintenance, isFalse);
      await controller.deleteEntry('entry-1');
      expect(repository.calls, contains('deleteEntry:entry-1'));
    });

    test(
      'waits for the in-flight mutation before resolving the barrier',
      () async {
        repository.emit(LibrarySnapshot(entries: [_entry('entry-1')]));
        await pumpEventQueue();
        final gate = repository.block('markCopied:entry-1');

        final copy = controller.markCopied('entry-1');
        final barrier = controller.beginMaintenance();
        await pumpEventQueue();
        expect(controller.state.isUnderMaintenance, isTrue);

        var resolved = false;
        unawaited(barrier.then((_) => resolved = true));
        await pumpEventQueue();
        expect(
          resolved,
          isFalse,
          reason: 'barrier waits for the in-flight copy',
        );

        gate.complete();
        await copy;
        await barrier;
        expect(controller.state.isUnderMaintenance, isTrue);
        expect(controller.state.activeMutations, isEmpty);

        controller.endMaintenance();
        expect(controller.state.isUnderMaintenance, isFalse);
      },
    );

    test(
      'releases the barrier when the in-flight mutation fails typed',
      () async {
        repository.emit(LibrarySnapshot(entries: [_entry('entry-1')]));
        await pumpEventQueue();
        final failure = LibraryFailure.databaseFailure(
          code: LibraryDatabaseFailureCode.transactionFailed,
        );
        repository.failNext('markCopied:entry-1', failure);

        final copy = controller.markCopied('entry-1');
        final barrier = controller.beginMaintenance();
        await expectLater(copy, throwsA(same(failure)));
        await barrier;

        expect(controller.state.isUnderMaintenance, isTrue);
        expect(controller.state.activeMutations, isEmpty);
        controller.endMaintenance();
      },
    );

    test(
      'releases the barrier when the in-flight mutation fails unexpectedly',
      () async {
        final error = StateError('programming error');
        repository.failNext('markCopied:entry-1', error);

        final copy = controller.markCopied('entry-1');
        final barrier = controller.beginMaintenance();
        await expectLater(copy, throwsA(same(error)));
        await barrier;

        expect(controller.state.isUnderMaintenance, isTrue);
        expect(controller.state.activeMutations, isEmpty);
        controller.endMaintenance();
      },
    );

    test('rejects repeated begin and unpaired end', () async {
      await controller.beginMaintenance();
      expect(() => controller.beginMaintenance(), throwsStateError);
      controller.endMaintenance();
      expect(() => controller.endMaintenance(), throwsStateError);
    });

    test('routes updateEntryDetails with the same update instance', () async {
      final update = EntryUpdate(
        title: 'New title',
        body: 'New body',
        keyword: const ReplaceKeyword(' alias '),
      );

      await controller.updateEntryDetails('entry-1', update);

      expect(repository.calls, ['updateEntryDetails:entry-1']);
      expect(repository.updates['entry-1'], same(update));
      expect(controller.state.activeMutations, isEmpty);
    });

    test('deduplicates in-flight updateEntryDetails by key', () async {
      final gate = repository.block('updateEntryDetails:entry-1');
      final update = EntryUpdate(title: 'T', body: 'B');

      final first = controller.updateEntryDetails('entry-1', update);
      final duplicate = controller.updateEntryDetails('entry-1', update);

      expect(identical(first, duplicate), isTrue);
      expect(repository.calls, ['updateEntryDetails:entry-1']);

      gate.complete();
      await Future.wait([first, duplicate]);
      expect(controller.state.activeMutations, isEmpty);
    });
  });

  // === Copy cycle admission tests ===
  group('LibraryController copy cycles', () {
    test(
      'barrier waits for an admitted cycle through buffer and metadata',
      () async {
        final entry = _entry('entry-1');
        repository.emit(LibrarySnapshot(entries: [entry]));
        await pumpEventQueue();
        final writeGate = clipboard.block();
        final metadataGate = repository.block('markCopied:entry-1');

        final copied = copyLibraryEntry(
          entry: entry,
          clipboard: clipboard,
          controller: controller,
        );
        await pumpEventQueue();
        expect(clipboard.writes, ['Body entry-1']);

        final barrier = controller.beginMaintenance();
        var resolved = false;
        unawaited(barrier.then((_) => resolved = true));
        await pumpEventQueue();
        expect(
          resolved,
          isFalse,
          reason: 'the admitted cycle still writes the buffer',
        );

        writeGate.complete();
        await pumpEventQueue();
        expect(repository.calls, ['markCopied:entry-1']);
        expect(
          resolved,
          isFalse,
          reason: 'the admitted cycle still records metadata',
        );

        metadataGate.complete();
        expect(await copied, LibraryCopyOutcome.copied);
        await barrier;
        expect(resolved, isTrue);
        controller.endMaintenance();
      },
    );

    test(
      'admitted cycle records metadata under the barrier without error',
      () async {
        final entry = _entry('entry-1');
        repository.emit(LibrarySnapshot(entries: [entry]));
        await pumpEventQueue();
        final writeGate = clipboard.block();

        final copied = copyLibraryEntry(
          entry: entry,
          clipboard: clipboard,
          controller: controller,
        );
        await pumpEventQueue();
        final barrier = controller.beginMaintenance();

        writeGate.complete();
        expect(await copied, LibraryCopyOutcome.copied);
        await barrier;
        expect(repository.calls, ['markCopied:entry-1']);

        expect(() => controller.markCopied('entry-1'), throwsStateError);
        controller.endMaintenance();
      },
    );

    test(
      'barrier outlives a descriptor released before its write completes',
      () async {
        repository.emit(LibrarySnapshot(entries: [_entry('entry-1')]));
        await pumpEventQueue();
        final cycle = controller.admitCopyCycle('entry-1')!;
        final metadataGate = repository.block('markCopied:entry-1');

        final write = cycle.markCopied();
        cycle.release();
        await pumpEventQueue();
        expect(repository.calls, ['markCopied:entry-1']);

        final barrier = controller.beginMaintenance();
        var resolved = false;
        unawaited(barrier.then((_) => resolved = true));
        await pumpEventQueue();
        expect(resolved, isFalse, reason: 'the descriptor write is still held');

        metadataGate.complete();
        await write;
        await barrier;
        expect(resolved, isTrue);
        controller.endMaintenance();
      },
    );

    test('refuses admission under maintenance and after teardown', () async {
      repository.emit(LibrarySnapshot(entries: [_entry('entry-1')]));
      await pumpEventQueue();

      await controller.beginMaintenance();
      expect(controller.admitCopyCycle('entry-1'), isNull);

      controller.endMaintenance();
      final cycle = controller.admitCopyCycle('entry-1');
      expect(cycle, isNotNull);
      cycle!.release();

      await controller.dispose();
      expect(controller.admitCopyCycle('entry-1'), isNull);
    });

    test(
      'dispose releases an admitted cycle and resolves the barrier',
      () async {
        final entry = _entry('entry-1');
        repository.emit(LibrarySnapshot(entries: [entry]));
        await pumpEventQueue();
        final writeGate = clipboard.block();

        final copied = copyLibraryEntry(
          entry: entry,
          clipboard: clipboard,
          controller: controller,
        );
        await pumpEventQueue();
        final barrier = controller.beginMaintenance();
        var resolved = false;
        unawaited(barrier.then((_) => resolved = true));

        await controller.dispose();
        await pumpEventQueue();
        expect(resolved, isTrue, reason: 'dispose releases admitted cycles');

        writeGate.complete();
        expect(await copied, LibraryCopyOutcome.copied);
        await pumpEventQueue();
        expect(repository.calls, isEmpty);
      },
    );

    test(
      'descriptor refuses writes after release and releases idempotently',
      () async {
        repository.emit(LibrarySnapshot(entries: [_entry('entry-1')]));
        await pumpEventQueue();
        final cycle = controller.admitCopyCycle('entry-1')!;

        cycle.release();
        expect(() => cycle.markCopied(), throwsStateError);
        cycle.release();

        await controller.beginMaintenance();
        controller.endMaintenance();
      },
    );

    test('releases the admission when metadata fails unexpectedly', () async {
      final entry = _entry('entry-1');
      repository.emit(LibrarySnapshot(entries: [entry]));
      await pumpEventQueue();
      final error = StateError('metadata adapter failed');
      repository.failNext('markCopied:entry-1', error);

      final copied = copyLibraryEntry(
        entry: entry,
        clipboard: clipboard,
        controller: controller,
      );
      final errorExpectation = expectLater(copied, throwsA(same(error)));
      final barrier = controller.beginMaintenance();
      var resolved = false;
      unawaited(barrier.then((_) => resolved = true));
      await pumpEventQueue();

      await errorExpectation;
      await barrier;
      expect(resolved, isTrue);
    });
  });

  // === Disposal tests ===
  group('LibraryController disposal', () {
    test('disposes idempotently and rejects later commands', () async {
      final states = <LibraryState>[];
      final subscription = controller.states.listen(states.add);

      final firstDispose = controller.dispose();
      final secondDispose = controller.dispose();

      expect(identical(firstDispose, secondDispose), isTrue);
      await Future.wait([firstDispose, secondDispose]);

      expect(() => controller.updateSearchQuery('query'), throwsStateError);
      expect(() => controller.deleteEntry('entry-1'), throwsStateError);

      repository.emit(LibrarySnapshot(entries: [_entry('late')]));
      await pumpEventQueue();
      expect(states, isEmpty);

      await subscription.cancel();
    });
  });
}

/// Fake clipboard with a hold gate for the write.
final class _FakeClipboard implements LibraryClipboard {
  /// Recorded clipboard writes.
  final List<String> writes = [];

  Completer<void>? _gate;

  /// Holds the next write until completed.
  Completer<void> block() {
    _gate = Completer<void>();
    return _gate!;
  }

  @override
  Future<void> writeText(String text) async {
    writes.add(text);
    final gate = _gate;
    if (gate != null) {
      await gate.future;
    }
  }
}

/// Fake repository implementation.
final class _FakeLibraryRepository implements LibraryRepository {
  final StreamController<LibrarySnapshot> _snapshots =
      StreamController<LibrarySnapshot>.broadcast();
  final Map<String, Completer<void>> _gates = {};
  final Map<String, Object> _errors = {};

  /// Captured update commands by entry identifier.
  final Map<String, EntryUpdate> updates = {};

  /// Recorded repository calls.
  final List<String> calls = [];

  /// Emits repository snapshot.
  void emit(LibrarySnapshot snapshot) {
    _snapshots.add(snapshot);
  }

  /// Emits repository error.
  void emitError(Object error) {
    _snapshots.addError(error);
  }

  /// Blocks matching call.
  Completer<void> block(String call) {
    final completer = Completer<void>();
    _gates[call] = completer;
    return completer;
  }

  /// Fails matching call.
  void failNext(String call, Object error) {
    _errors[call] = error;
  }

  /// Closes fake resources.
  Future<void> close() {
    return _snapshots.close();
  }

  @override
  Stream<LibrarySnapshot> watchSnapshot() => _snapshots.stream;

  @override
  Future<LibrarySnapshot> getSnapshot() async {
    return const LibrarySnapshot.empty();
  }

  @override
  Future<Entry> createEntry(EntryInput input) {
    return _result('createEntry', _entry('created'));
  }

  @override
  Future<Entry> updateEntry(String id, EntryInput input) {
    return _result('updateEntry:$id', _entry(id));
  }

  @override
  Future<LibrarySnapshot> restoreSnapshot({
    required LibrarySnapshot expectedCurrent,
    required LibrarySnapshot replacement,
  }) {
    return _result('restoreSnapshot', const LibrarySnapshot.empty());
  }

  @override
  Future<List<Entry>> addRaycastEntries({
    required LibrarySnapshot expectedCurrent,
    required List<RaycastEntryDraft> drafts,
  }) {
    return _result('addRaycastEntries', const <Entry>[]);
  }

  @override
  Future<Entry> updateEntryDetails(String id, EntryUpdate update) {
    updates[id] = update;
    return _result('updateEntryDetails:$id', _entry(id));
  }

  @override
  Future<void> deleteEntry(String id) {
    return _result('deleteEntry:$id', null);
  }

  @override
  Future<void> markCopied(String id) {
    return _result('markCopied:$id', null);
  }

  @override
  Future<void> setFavorite(String id, {required bool isFavorite}) {
    return _result('setFavorite:$id:$isFavorite', null);
  }

  @override
  Future<void> setArchived(String id, {required bool isArchived}) {
    return _result('setArchived:$id:$isArchived', null);
  }

  @override
  Future<Category> createCategory(String name) {
    return _result('createCategory', _category('created-category', name));
  }

  @override
  Future<Category> renameCategory(String id, String newName) {
    return _result('renameCategory:$id', _category(id, newName));
  }

  @override
  Future<void> deleteCategory(String id) {
    return _result('deleteCategory:$id', null);
  }

  @override
  Future<void> reorderCategories(List<String> orderedCategoryIds) {
    return _result('reorderCategories', null);
  }

  @override
  Future<Tag> createTag(String name) {
    return _result('createTag', _tag('created-tag', name));
  }

  @override
  Future<Tag> renameTag(String id, String newName) {
    return _result('renameTag:$id', _tag(id, newName));
  }

  @override
  Future<void> deleteTag(String id) {
    return _result('deleteTag:$id', null);
  }

  /// Resolves configured result.
  Future<T> _result<T>(String call, T value) async {
    calls.add(call);
    final gate = _gates.remove(call);
    if (gate != null) {
      await gate.future;
    }
    final error = _errors.remove(call);
    if (error != null) {
      throw error;
    }
    return value;
  }
}

/// Creates validated input.
EntryInput _input() {
  return EntryInput.validate(title: 'Title', body: 'Body');
}

/// Creates deterministic entry.
Entry _entry(String id, {String? title}) {
  return Entry(
    id: id,
    title: title ?? 'Title $id',
    body: 'Body $id',
    createdAt: DateTime.utc(2026, 8, 25),
    updatedAt: DateTime.utc(2026, 8, 25),
  );
}

/// Creates deterministic category.
Category _category(String id, String name) {
  return Category(
    id: id,
    name: name,
    normalizedName: name.toLowerCase(),
    sortOrder: 0,
    createdAt: DateTime.utc(2026, 8, 25),
  );
}

/// Creates deterministic tag.
Tag _tag(String id, String name) {
  return Tag(
    id: id,
    name: name,
    normalizedName: name.toLowerCase(),
    createdAt: DateTime.utc(2026, 8, 25),
  );
}

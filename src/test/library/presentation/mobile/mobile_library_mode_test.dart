/// Mobile mode projection tests.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/library/models/entry.dart';
import 'package:prompt_library/src/library/presentation/library_filter.dart';
import 'package:prompt_library/src/library/presentation/mobile/mobile_library_mode.dart';

void main() {
  // === Mode to scope mapping ===

  test('scopeForMobileMode maps every mobile mode onto a shared scope', () {
    expect(
      scopeForMobileMode(MobileLibraryMode.all),
      LibraryFilterScope.active,
    );
    expect(
      scopeForMobileMode(MobileLibraryMode.favorites),
      LibraryFilterScope.favorites,
    );
    expect(
      scopeForMobileMode(MobileLibraryMode.recent),
      LibraryFilterScope.active,
    );
    expect(
      scopeForMobileMode(MobileLibraryMode.archived),
      LibraryFilterScope.archived,
    );
  });

  // === Recent selection and ordering ===

  test('projectMobileEntries keeps only copied non-archived entries', () {
    final entries = [
      _entry(
        'archived',
        lastCopiedAt: DateTime.utc(2026, 5, 9),
        archived: true,
      ),
      _entry('never-copied'),
      _entry('oldest', lastCopiedAt: DateTime.utc(2026, 5, 1)),
      _entry('newest', lastCopiedAt: DateTime.utc(2026, 5, 8)),
      _entry('middle', lastCopiedAt: DateTime.utc(2026, 5, 4)),
    ];

    final projected = projectMobileEntries(entries, MobileLibraryMode.recent);

    expect(projected.map((entry) => entry.id), ['newest', 'middle', 'oldest']);
  });

  test('projectMobileEntries resolves recent ties by updated, title, id', () {
    final copied = DateTime.utc(2026, 5, 5);
    final entries = [
      _entry(
        'stale',
        lastCopiedAt: copied,
        updatedAt: DateTime.utc(2026, 4, 1),
        title: 'Alpha',
      ),
      _entry(
        'fresh',
        lastCopiedAt: copied,
        updatedAt: DateTime.utc(2026, 4, 9),
        title: 'Zulu',
      ),
    ];

    expect(
      projectMobileEntries(entries, MobileLibraryMode.recent).map((e) => e.id),
      ['fresh', 'stale'],
    );

    final sameUpdate = DateTime.utc(2026, 4, 9);
    final byTitle = [
      _entry(
        'zulu',
        lastCopiedAt: copied,
        updatedAt: sameUpdate,
        title: 'Zulu prompt',
      ),
      _entry(
        'alpha',
        lastCopiedAt: copied,
        updatedAt: sameUpdate,
        title: 'alpha prompt',
      ),
    ];

    expect(
      projectMobileEntries(byTitle, MobileLibraryMode.recent).map((e) => e.id),
      ['alpha', 'zulu'],
    );

    final byId = [
      _entry(
        'entry-b',
        lastCopiedAt: copied,
        updatedAt: sameUpdate,
        title: 'Same title',
      ),
      _entry(
        'entry-a',
        lastCopiedAt: copied,
        updatedAt: sameUpdate,
        title: 'Same title',
      ),
    ];

    expect(
      projectMobileEntries(byId, MobileLibraryMode.recent).map((e) => e.id),
      ['entry-a', 'entry-b'],
    );
  });

  test('projectMobileEntries ignores favorite rank inside recent', () {
    final entries = [
      _entry(
        'favorite-stale',
        lastCopiedAt: DateTime.utc(2026, 5, 1),
        favorite: true,
      ),
      _entry('plain-fresh', lastCopiedAt: DateTime.utc(2026, 5, 7)),
    ];

    expect(
      projectMobileEntries(entries, MobileLibraryMode.recent).map((e) => e.id),
      ['plain-fresh', 'favorite-stale'],
    );
  });

  test('projectMobileEntries returns an unmodifiable recent projection', () {
    final projected = projectMobileEntries([
      _entry('one', lastCopiedAt: DateTime.utc(2026, 5, 1)),
    ], MobileLibraryMode.recent);

    expect(() => projected.add(_entry('two')), throwsUnsupportedError);
  });

  // === Pass-through modes ===

  test('projectMobileEntries preserves controller order outside recent', () {
    final entries = [
      _entry('second', lastCopiedAt: DateTime.utc(2026, 5, 1)),
      _entry('first'),
      _entry('third', archived: true),
    ];

    for (final mode in [
      MobileLibraryMode.all,
      MobileLibraryMode.favorites,
      MobileLibraryMode.archived,
    ]) {
      expect(projectMobileEntries(entries, mode).map((entry) => entry.id), [
        'second',
        'first',
        'third',
      ], reason: 'mode ${mode.name} must not reorder controller output');
    }
  });
}

/// Creates a deterministic projection entry.
Entry _entry(
  String id, {
  String title = 'Prompt title',
  DateTime? lastCopiedAt,
  DateTime? updatedAt,
  bool favorite = false,
  bool archived = false,
}) {
  return Entry(
    id: id,
    title: title,
    body: 'Prompt body',
    isFavorite: favorite,
    isArchived: archived,
    createdAt: DateTime.utc(2026),
    updatedAt: updatedAt ?? DateTime.utc(2026),
    lastCopiedAt: lastCopiedAt,
  );
}

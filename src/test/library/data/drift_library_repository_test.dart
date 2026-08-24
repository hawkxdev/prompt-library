/// Repository persistence tests.
library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/library/data/drift_library_repository.dart';
import 'package:prompt_library/src/library/data/library_database.dart'
    hide Entry, Category, Tag;
import 'package:prompt_library/src/library/models/entry_input.dart';
import 'package:prompt_library/src/library/models/library_failure.dart';
import 'package:prompt_library/src/library/models/library_snapshot.dart';
import 'package:prompt_library/src/library/data/library_repository.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  // === Snapshot and Reactive Stream ===
  group('DriftLibraryRepository (Stage 2E.1 Snapshot & Reactive Stream)', () {
    late LibraryDatabase db;
    late DriftLibraryRepository repository;

    setUp(() {
      db = LibraryDatabase.forTesting(NativeDatabase.memory());
      repository = DriftLibraryRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('getSnapshot returns empty snapshot for empty database', () async {
      final snapshot = await repository.getSnapshot();

      expect(snapshot.entries, isEmpty);
      expect(snapshot.categories, isEmpty);
      expect(snapshot.tags, isEmpty);
      expect(snapshot.categoryById, isEmpty);
      expect(snapshot.tagById, isEmpty);
      expect(snapshot.tagsForEntry, isEmpty);
    });

    test(
      'getSnapshot returns complete snapshot including unused category and tag',
      () async {
        final t0 = DateTime.utc(2026, 8, 24, 10, 0, 0);

        await db
            .into(db.categories)
            .insert(
              CategoriesCompanion.insert(
                id: 'cat-used',
                name: 'Writing',
                normalizedName: 'writing',
                sortOrder: 0,
                createdAt: t0,
              ),
            );
        await db
            .into(db.categories)
            .insert(
              CategoriesCompanion.insert(
                id: 'cat-unused',
                name: 'Archived Idea',
                normalizedName: 'archived idea',
                sortOrder: 1,
                createdAt: t0,
              ),
            );

        await db
            .into(db.tags)
            .insert(
              TagsCompanion.insert(
                id: 'tag-used-1',
                name: 'Flutter',
                normalizedName: 'flutter',
                createdAt: t0,
              ),
            );
        await db
            .into(db.tags)
            .insert(
              TagsCompanion.insert(
                id: 'tag-used-2',
                name: 'Dart',
                normalizedName: 'dart',
                createdAt: t0,
              ),
            );
        await db
            .into(db.tags)
            .insert(
              TagsCompanion.insert(
                id: 'tag-unused',
                name: 'Rust',
                normalizedName: 'rust',
                createdAt: t0,
              ),
            );

        await db
            .into(db.entries)
            .insert(
              EntriesCompanion.insert(
                id: 'entry-1',
                title: 'State Management',
                body: 'Explain Riverpod state management in Flutter.',
                keyword: const Value('riverpod'),
                categoryId: const Value('cat-used'),
                isFavorite: const Value(true),
                createdAt: t0,
                updatedAt: t0,
                lastCopiedAt: Value(t0),
              ),
            );

        await db
            .into(db.entryTags)
            .insert(
              EntryTagsCompanion.insert(
                entryId: 'entry-1',
                tagId: 'tag-used-1',
              ),
            );
        await db
            .into(db.entryTags)
            .insert(
              EntryTagsCompanion.insert(
                entryId: 'entry-1',
                tagId: 'tag-used-2',
              ),
            );

        final snapshot = await repository.getSnapshot();

        expect(snapshot.entries.length, 1);
        expect(snapshot.categories.length, 2);
        expect(snapshot.tags.length, 3);

        expect(
          snapshot.categories.map((c) => c.id),
          containsAll(['cat-used', 'cat-unused']),
        );
        expect(
          snapshot.tags.map((t) => t.id),
          containsAll(['tag-used-1', 'tag-used-2', 'tag-unused']),
        );
        expect(snapshot.categoryById.containsKey('cat-unused'), isTrue);
        expect(snapshot.tagById.containsKey('tag-unused'), isTrue);

        final entry = snapshot.entries.single;
        expect(entry.id, 'entry-1');
        expect(entry.title, 'State Management');
        expect(entry.body, 'Explain Riverpod state management in Flutter.');
        expect(entry.keyword, 'riverpod');
        expect(entry.categoryId, 'cat-used');
        expect(entry.isFavorite, isTrue);
        expect(entry.isArchived, isFalse);
        expect(entry.createdAt, t0);
        expect(entry.updatedAt, t0);
        expect(entry.lastCopiedAt, t0);

        final tagsForEntry = snapshot.tagsForEntry['entry-1'];
        expect(tagsForEntry, isNotNull);
        expect(tagsForEntry!.map((t) => t.id), ['tag-used-1', 'tag-used-2']);
      },
    );

    test('getSnapshot resolves tagIds as sorted unmodifiable list', () async {
      final t0 = DateTime.utc(2026, 8, 24, 12, 0, 0);

      await db
          .into(db.tags)
          .insert(
            TagsCompanion.insert(
              id: 'tag-z',
              name: 'Zeta',
              normalizedName: 'zeta',
              createdAt: t0,
            ),
          );
      await db
          .into(db.tags)
          .insert(
            TagsCompanion.insert(
              id: 'tag-a',
              name: 'Alpha',
              normalizedName: 'alpha',
              createdAt: t0,
            ),
          );
      await db
          .into(db.tags)
          .insert(
            TagsCompanion.insert(
              id: 'tag-m',
              name: 'Mu',
              normalizedName: 'mu',
              createdAt: t0,
            ),
          );

      await db
          .into(db.entries)
          .insert(
            EntriesCompanion.insert(
              id: 'entry-tags-test',
              title: 'Tags Order Test',
              body: 'Testing tag sorting resolution.',
              createdAt: t0,
              updatedAt: t0,
            ),
          );

      await db
          .into(db.entryTags)
          .insert(
            EntryTagsCompanion.insert(
              entryId: 'entry-tags-test',
              tagId: 'tag-z',
            ),
          );
      await db
          .into(db.entryTags)
          .insert(
            EntryTagsCompanion.insert(
              entryId: 'entry-tags-test',
              tagId: 'tag-a',
            ),
          );
      await db
          .into(db.entryTags)
          .insert(
            EntryTagsCompanion.insert(
              entryId: 'entry-tags-test',
              tagId: 'tag-m',
            ),
          );

      final snapshot = await repository.getSnapshot();
      final entry = snapshot.entries.single;

      expect(entry.tagIds, ['tag-a', 'tag-m', 'tag-z']);
      expect(() => entry.tagIds.add('tag-other'), throwsUnsupportedError);
    });

    test(
      'getSnapshot guarantees UTC DateTime across all domain models',
      () async {
        final localDateTime = DateTime(2026, 8, 24, 15, 30, 45);

        await db
            .into(db.categories)
            .insert(
              CategoriesCompanion.insert(
                id: 'cat-utc',
                name: 'Timezone Category',
                normalizedName: 'timezone category',
                sortOrder: 0,
                createdAt: localDateTime,
              ),
            );

        await db
            .into(db.tags)
            .insert(
              TagsCompanion.insert(
                id: 'tag-utc',
                name: 'Timezone Tag',
                normalizedName: 'timezone tag',
                createdAt: localDateTime,
              ),
            );

        await db
            .into(db.entries)
            .insert(
              EntriesCompanion.insert(
                id: 'entry-utc',
                title: 'UTC Prompt',
                body: 'Testing UTC normalization in domain entities.',
                categoryId: const Value('cat-utc'),
                createdAt: localDateTime,
                updatedAt: localDateTime,
                lastCopiedAt: Value(localDateTime),
              ),
            );

        final snapshot = await repository.getSnapshot();

        final category = snapshot.categories.single;
        expect(category.createdAt.isUtc, isTrue);

        final tag = snapshot.tags.single;
        expect(tag.createdAt.isUtc, isTrue);

        final entry = snapshot.entries.single;
        expect(entry.createdAt.isUtc, isTrue);
        expect(entry.updatedAt.isUtc, isTrue);
        expect(entry.lastCopiedAt?.isUtc, isTrue);
      },
    );

    test('getSnapshot produces deterministic sorting for entries, categories, and tags', () async {
      final t1 = DateTime.utc(2026, 8, 24, 10, 0, 0);
      final t2 = DateTime.utc(2026, 8, 24, 11, 0, 0);
      final t3 = DateTime.utc(2026, 8, 24, 12, 0, 0);

      await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(
              id: 'cat-3',
              name: 'Delta',
              normalizedName: 'delta',
              sortOrder: 2,
              createdAt: t1,
            ),
          );
      await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(
              id: 'cat-1',
              name: 'Beta',
              normalizedName: 'beta',
              sortOrder: 0,
              createdAt: t1,
            ),
          );
      await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(
              id: 'cat-2',
              name: 'Gamma',
              normalizedName: 'gamma',
              sortOrder: 1,
              createdAt: t1,
            ),
          );
      await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(
              id: 'cat-0',
              name: 'Alpha',
              normalizedName: 'alpha',
              sortOrder: 0,
              createdAt: t1,
            ),
          );

      await db
          .into(db.tags)
          .insert(
            TagsCompanion.insert(
              id: 'tag-3',
              name: 'Zulu',
              normalizedName: 'zulu',
              createdAt: t1,
            ),
          );
      await db
          .into(db.tags)
          .insert(
            TagsCompanion.insert(
              id: 'tag-1',
              name: 'Banana',
              normalizedName: 'banana',
              createdAt: t1,
            ),
          );
      await db
          .into(db.tags)
          .insert(
            TagsCompanion.insert(
              id: 'tag-2',
              name: 'Cherry',
              normalizedName: 'cherry',
              createdAt: t1,
            ),
          );
      await db
          .into(db.tags)
          .insert(
            TagsCompanion.insert(
              id: 'tag-0',
              name: 'Apple',
              normalizedName: 'apple',
              createdAt: t1,
            ),
          );

      await db
          .into(db.entries)
          .insert(
            EntriesCompanion.insert(
              id: 'entry-old',
              title: 'Old Entry',
              body: 'Created earlier.',
              createdAt: t1,
              updatedAt: t1,
            ),
          );
      await db
          .into(db.entries)
          .insert(
            EntriesCompanion.insert(
              id: 'entry-new',
              title: 'New Entry',
              body: 'Created latest.',
              createdAt: t1,
              updatedAt: t3,
            ),
          );
      await db
          .into(db.entries)
          .insert(
            EntriesCompanion.insert(
              id: 'entry-mid-b',
              title: 'Mid Entry B',
              body: 'Created in middle.',
              createdAt: t1,
              updatedAt: t2,
            ),
          );
      await db
          .into(db.entries)
          .insert(
            EntriesCompanion.insert(
              id: 'entry-mid-a',
              title: 'Mid Entry A',
              body: 'Created in middle with lower ID.',
              createdAt: t1,
              updatedAt: t2,
            ),
          );

      final snapshot = await repository.getSnapshot();

      expect(snapshot.categories.map((c) => c.id).toList(), [
        'cat-0',
        'cat-1',
        'cat-2',
        'cat-3',
      ]);

      expect(snapshot.tags.map((t) => t.id).toList(), [
        'tag-0',
        'tag-1',
        'tag-2',
        'tag-3',
      ]);

      expect(snapshot.entries.map((e) => e.id).toList(), [
        'entry-new',
        'entry-mid-b',
        'entry-mid-a',
        'entry-old',
      ]);
    });

    test('watchSnapshot delivers initial emission and exactly one coherent update per transaction', () async {
      final t0 = DateTime.utc(2026, 8, 24, 14, 0, 0);

      final stream = repository.watchSnapshot();
      final emissions = <LibrarySnapshot>[];
      final completer = Completer<void>();

      final subscription = stream.listen((snapshot) {
        emissions.add(snapshot);
        if (emissions.length == 2) {
          completer.complete();
        }
      });

      await pumpEventQueue();
      expect(emissions.length, 1);
      expect(emissions.first.entries, isEmpty);
      expect(emissions.first.categories, isEmpty);
      expect(emissions.first.tags, isEmpty);

      await db.transaction(() async {
        await db
            .into(db.categories)
            .insert(
              CategoriesCompanion.insert(
                id: 'cat-tx',
                name: 'Tx Category',
                normalizedName: 'tx category',
                sortOrder: 0,
                createdAt: t0,
              ),
            );

        await db
            .into(db.tags)
            .insert(
              TagsCompanion.insert(
                id: 'tag-tx',
                name: 'Tx Tag',
                normalizedName: 'tx tag',
                createdAt: t0,
              ),
            );

        await db
            .into(db.entries)
            .insert(
              EntriesCompanion.insert(
                id: 'entry-tx',
                title: 'Tx Entry',
                body: 'Created inside transaction.',
                categoryId: const Value('cat-tx'),
                createdAt: t0,
                updatedAt: t0,
              ),
            );

        await db
            .into(db.entryTags)
            .insert(
              EntryTagsCompanion.insert(entryId: 'entry-tx', tagId: 'tag-tx'),
            );
      });

      await completer.future.timeout(const Duration(seconds: 2));

      expect(emissions.length, 2);

      final updatedSnapshot = emissions[1];
      expect(updatedSnapshot.categories.length, 1);
      expect(updatedSnapshot.categories.single.id, 'cat-tx');
      expect(updatedSnapshot.tags.length, 1);
      expect(updatedSnapshot.tags.single.id, 'tag-tx');
      expect(updatedSnapshot.entries.length, 1);
      expect(updatedSnapshot.entries.single.id, 'entry-tx');
      expect(updatedSnapshot.entries.single.tagIds, ['tag-tx']);
      expect(updatedSnapshot.tagsForEntry['entry-tx']?.single.id, 'tag-tx');

      await subscription.cancel();
    });
    test('getSnapshot maps database open failure to read failure', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'prompt_library_unopenable_',
      );
      final failingDb = LibraryDatabase.forTesting(
        NativeDatabase(File(tempDir.path)),
      );
      final failingRepository = DriftLibraryRepository(failingDb);

      try {
        expect(
          () => failingRepository.getSnapshot(),
          throwsA(
            const LibraryFailure.databaseFailure(
              code: LibraryDatabaseFailureCode.readFailed,
            ),
          ),
        );
      } finally {
        await failingDb.close();
        await tempDir.delete(recursive: true);
      }
    });

    test('watchSnapshot maps corrupt database to stable failure', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'prompt_library_corrupt_stream_',
      );
      final dbFile = File(p.join(tempDir.path, 'corrupt.sqlite'));
      await dbFile.writeAsString('not a sqlite database');
      final corruptDb = LibraryDatabase.forTesting(NativeDatabase(dbFile));
      final corruptRepository = DriftLibraryRepository(corruptDb);

      try {
        expect(
          () => corruptRepository.watchSnapshot().first,
          throwsA(
            const LibraryFailure.databaseFailure(
              code: LibraryDatabaseFailureCode.corrupt,
            ),
          ),
        );
      } finally {
        await corruptDb.close();
        await tempDir.delete(recursive: true);
      }
    });

    test('getSnapshot maps corrupt database to stable failure', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'prompt_library_corrupt_',
      );
      final dbFile = File(p.join(tempDir.path, 'corrupt.sqlite'));
      await dbFile.writeAsString('not a sqlite database');
      final corruptDb = LibraryDatabase.forTesting(NativeDatabase(dbFile));
      final corruptRepository = DriftLibraryRepository(corruptDb);

      try {
        expect(
          () => corruptRepository.getSnapshot(),
          throwsA(
            const LibraryFailure.databaseFailure(
              code: LibraryDatabaseFailureCode.corrupt,
            ),
          ),
        );
      } finally {
        await corruptDb.close();
        await tempDir.delete(recursive: true);
      }
    });
  });

  // === Entry Mutations and Invariants ===
  group('DriftLibraryRepository (Stage 2E.2 Entry Mutations & Invariants)', () {
    late LibraryDatabase db;
    late DriftLibraryRepository repository;
    late String currentUuid;
    late DateTime currentTime;

    setUp(() async {
      db = LibraryDatabase.forTesting(NativeDatabase.memory());
      currentUuid = 'entry-default-uuid';
      currentTime = DateTime.utc(2026, 8, 24, 10, 0, 0);
      repository = DriftLibraryRepository(
        db,
        uuidGenerator: () => currentUuid,
        clock: () => currentTime,
      );
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> seedCategory(String id, String name, int sortOrder) async {
      await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(
              id: id,
              name: name,
              normalizedName: name.toLowerCase(),
              sortOrder: sortOrder,
              createdAt: DateTime.utc(2026, 8, 24, 9, 0, 0),
            ),
          );
    }

    Future<void> seedTag(String id, String name) async {
      await db
          .into(db.tags)
          .insert(
            TagsCompanion.insert(
              id: id,
              name: name,
              normalizedName: name.toLowerCase(),
              createdAt: DateTime.utc(2026, 8, 24, 9, 0, 0),
            ),
          );
    }

    test('createEntry preserves unexpected clock exception', () async {
      final clockFailure = Exception('clock failure');
      repository = DriftLibraryRepository(
        db,
        uuidGenerator: () => 'clock-entry',
        clock: () => throw clockFailure,
      );

      final input = EntryInput.validate(title: 'Clock', body: 'Body');

      expect(() => repository.createEntry(input), throwsA(same(clockFailure)));
    });

    test('createEntry preserves unexpected UUID exception', () async {
      final uuidFailure = Exception('uuid failure');
      repository = DriftLibraryRepository(
        db,
        uuidGenerator: () => throw uuidFailure,
        clock: () => DateTime.utc(2026, 8, 24, 10, 0),
      );

      final input = EntryInput.validate(title: 'UUID', body: 'Body');

      expect(() => repository.createEntry(input), throwsA(same(uuidFailure)));
    });

    test('createEntry inserts entry and entry_tags atomically with UTC timestamps and trimmed fields', () async {
      await seedCategory('cat-dev', 'Development', 0);
      await seedTag('tag-flutter', 'Flutter');
      await seedTag('tag-dart', 'Dart');

      currentUuid = 'entry-uuid-101';
      currentTime = DateTime.utc(2026, 8, 24, 10, 30, 0);

      const exactBody =
          '  Analyze Flutter widget tree for unnecessary rebuilds.\n'
          '    Indent line 2\n'
          '  Trailing line  ';

      final input = EntryInput(
        title: '  Flutter Performance Optimizer  ',
        body: exactBody,
        keyword: '  perf  ',
        categoryId: 'cat-dev',
        tagIds: const ['tag-flutter', 'tag-dart'],
        isFavorite: true,
        isArchived: false,
      );

      final entry = await repository.createEntry(input);

      expect(entry.id, 'entry-uuid-101');
      expect(entry.title, 'Flutter Performance Optimizer');
      expect(entry.body, exactBody);
      expect(entry.keyword, 'perf');
      expect(entry.categoryId, 'cat-dev');
      expect(entry.tagIds, ['tag-dart', 'tag-flutter']);
      expect(entry.isFavorite, isTrue);
      expect(entry.isArchived, isFalse);
      expect(entry.createdAt, DateTime.utc(2026, 8, 24, 10, 30, 0));
      expect(entry.updatedAt, DateTime.utc(2026, 8, 24, 10, 30, 0));
      expect(entry.lastCopiedAt, isNull);

      final rawEntry = await (db.select(
        db.entries,
      )..where((t) => t.id.equals('entry-uuid-101'))).getSingle();
      expect(rawEntry.title, 'Flutter Performance Optimizer');
      expect(rawEntry.body, exactBody);
      expect(rawEntry.keyword, 'perf');
      expect(rawEntry.categoryId, 'cat-dev');
      expect(rawEntry.isFavorite, isTrue);
      expect(rawEntry.isArchived, isFalse);
      expect(rawEntry.createdAt.toUtc(), DateTime.utc(2026, 8, 24, 10, 30, 0));
      expect(rawEntry.updatedAt.toUtc(), DateTime.utc(2026, 8, 24, 10, 30, 0));
      expect(rawEntry.lastCopiedAt, isNull);

      final rawJoins = await (db.select(
        db.entryTags,
      )..where((t) => t.entryId.equals('entry-uuid-101'))).get();
      final linkedTagIds = rawJoins.map((j) => j.tagId).toList()..sort();
      expect(linkedTagIds, ['tag-dart', 'tag-flutter']);
    });

    test('createEntry rejects empty or whitespace title/body with invalidInput failure', () async {
      expect(
        () => repository.createEntry(
          EntryInput(title: '   \n\t  ', body: 'Valid body'),
        ),
        throwsA(
          const LibraryFailure.invalidInput(
            LibraryInputFailureReason.emptyTitle,
          ),
        ),
      );

      expect(
        () => repository.createEntry(
          EntryInput(title: 'Valid title', body: '   \n\t  '),
        ),
        throwsA(
          const LibraryFailure.invalidInput(
            LibraryInputFailureReason.emptyBody,
          ),
        ),
      );

      final allEntries = await db.select(db.entries).get();
      expect(allEntries, isEmpty);
    });

    test('createEntry rejects unknown category or tag without partial entries or join rows', () async {
      await seedCategory('cat-existing', 'General', 0);
      await seedTag('tag-existing', 'GeneralTag');

      currentUuid = 'entry-fail-1';

      expect(
        () => repository.createEntry(
          EntryInput(
            title: 'Test Title',
            body: 'Test Body',
            categoryId: 'non-existent-category',
            tagIds: const ['tag-existing'],
          ),
        ),
        throwsA(
          const LibraryFailure.invalidInput(
            LibraryInputFailureReason.unknownCategory,
          ),
        ),
      );

      final entriesAfterCategoryFail = await db.select(db.entries).get();
      final joinsAfterCategoryFail = await db.select(db.entryTags).get();
      expect(entriesAfterCategoryFail, isEmpty);
      expect(joinsAfterCategoryFail, isEmpty);

      currentUuid = 'entry-fail-2';

      expect(
        () => repository.createEntry(
          EntryInput(
            title: 'Test Title',
            body: 'Test Body',
            categoryId: 'cat-existing',
            tagIds: const ['tag-existing', 'non-existent-tag'],
          ),
        ),
        throwsA(
          const LibraryFailure.invalidInput(
            LibraryInputFailureReason.unknownTag,
          ),
        ),
      );

      final entriesAfterTagFail = await db.select(db.entries).get();
      final joinsAfterTagFail = await db.select(db.entryTags).get();
      expect(entriesAfterTagFail, isEmpty);
      expect(joinsAfterTagFail, isEmpty);
    });

    test(
      'updateEntry changes all observable fields and tag links atomically',
      () async {
        await seedCategory('cat-initial', 'Initial Category', 0);
        await seedCategory('cat-updated', 'Updated Category', 1);
        await seedTag('tag-1', 'Tag 1');
        await seedTag('tag-2', 'Tag 2');
        await seedTag('tag-3', 'Tag 3');

        currentUuid = 'entry-update-1';
        currentTime = DateTime.utc(2026, 8, 24, 10, 0, 0);

        final created = await repository.createEntry(
          EntryInput(
            title: 'Initial Title',
            body: 'Initial Body',
            keyword: 'initial-kw',
            categoryId: 'cat-initial',
            tagIds: const ['tag-1', 'tag-2'],
            isFavorite: false,
            isArchived: false,
          ),
        );
        expect(created.createdAt, DateTime.utc(2026, 8, 24, 10, 0, 0));
        expect(created.updatedAt, DateTime.utc(2026, 8, 24, 10, 0, 0));

        currentTime = DateTime.utc(2026, 8, 24, 11, 45, 0);
        const newBody =
            '  Updated Prompt Body with preserved formatting.\n'
            '    line 2 indented\n';

        final updated = await repository.updateEntry(
          'entry-update-1',
          EntryInput(
            title: '  Updated Title Trimmed  ',
            body: newBody,
            keyword: '  new-kw  ',
            categoryId: 'cat-updated',
            tagIds: const ['tag-2', 'tag-3'],
            isFavorite: true,
            isArchived: true,
          ),
        );

        expect(updated.id, 'entry-update-1');
        expect(updated.title, 'Updated Title Trimmed');
        expect(updated.body, newBody);
        expect(updated.keyword, 'new-kw');
        expect(updated.categoryId, 'cat-updated');
        expect(updated.tagIds, ['tag-2', 'tag-3']);
        expect(updated.isFavorite, isTrue);
        expect(updated.isArchived, isTrue);
        expect(updated.createdAt, DateTime.utc(2026, 8, 24, 10, 0, 0));
        expect(updated.updatedAt, DateTime.utc(2026, 8, 24, 11, 45, 0));

        final rawEntry = await (db.select(
          db.entries,
        )..where((t) => t.id.equals('entry-update-1'))).getSingle();
        expect(rawEntry.title, 'Updated Title Trimmed');
        expect(rawEntry.body, newBody);
        expect(rawEntry.keyword, 'new-kw');
        expect(rawEntry.categoryId, 'cat-updated');
        expect(rawEntry.isFavorite, isTrue);
        expect(rawEntry.isArchived, isTrue);
        expect(rawEntry.createdAt.toUtc(), DateTime.utc(2026, 8, 24, 10, 0, 0));
        expect(
          rawEntry.updatedAt.toUtc(),
          DateTime.utc(2026, 8, 24, 11, 45, 0),
        );

        final rawJoins = await (db.select(
          db.entryTags,
        )..where((t) => t.entryId.equals('entry-update-1'))).get();
        final linkedTagIds = rawJoins.map((j) => j.tagId).toList()..sort();
        expect(linkedTagIds, ['tag-2', 'tag-3']);
      },
    );

    test('updateEntry rejects unknown category or tag without mutating existing entry or joins', () async {
      await seedCategory('cat-1', 'Cat 1', 0);
      await seedTag('tag-1', 'Tag 1');

      currentUuid = 'entry-safe-1';
      currentTime = DateTime.utc(2026, 8, 24, 10, 0, 0);

      await repository.createEntry(
        EntryInput(
          title: 'Stable Title',
          body: 'Stable Body',
          categoryId: 'cat-1',
          tagIds: const ['tag-1'],
        ),
      );

      expect(
        () => repository.updateEntry(
          'entry-safe-1',
          EntryInput(
            title: 'Attempted Title',
            body: 'Attempted Body',
            categoryId: 'non-existent-cat',
          ),
        ),
        throwsA(
          const LibraryFailure.invalidInput(
            LibraryInputFailureReason.unknownCategory,
          ),
        ),
      );

      expect(
        () => repository.updateEntry(
          'entry-safe-1',
          EntryInput(
            title: 'Attempted Title',
            body: 'Attempted Body',
            categoryId: 'cat-1',
            tagIds: const ['tag-1', 'non-existent-tag'],
          ),
        ),
        throwsA(
          const LibraryFailure.invalidInput(
            LibraryInputFailureReason.unknownTag,
          ),
        ),
      );

      final rawEntry = await (db.select(
        db.entries,
      )..where((t) => t.id.equals('entry-safe-1'))).getSingle();
      expect(rawEntry.title, 'Stable Title');
      expect(rawEntry.body, 'Stable Body');
      expect(rawEntry.categoryId, 'cat-1');
      expect(rawEntry.updatedAt.toUtc(), DateTime.utc(2026, 8, 24, 10, 0, 0));

      final rawJoins = await (db.select(
        db.entryTags,
      )..where((t) => t.entryId.equals('entry-safe-1'))).get();
      expect(rawJoins.map((j) => j.tagId).toList(), ['tag-1']);
    });

    test('exact no-op update preserves updatedAt and emits no database write-visible state change', () async {
      await seedCategory('cat-1', 'Cat 1', 0);
      await seedTag('tag-1', 'Tag 1');
      await seedTag('tag-2', 'Tag 2');

      currentUuid = 'entry-noop-1';
      final t0 = DateTime.utc(2026, 8, 24, 10, 0, 0);
      currentTime = t0;

      await repository.createEntry(
        EntryInput(
          title: 'Exact Title',
          body: 'Exact Body\nMulti Line',
          keyword: 'kw',
          categoryId: 'cat-1',
          tagIds: const ['tag-1', 'tag-2'],
          isFavorite: true,
          isArchived: false,
        ),
      );

      final emissions = <LibrarySnapshot>[];
      final subscription = repository.watchSnapshot().listen(emissions.add);
      await pumpEventQueue();
      expect(emissions.length, 1);

      final t1 = DateTime.utc(2026, 8, 24, 14, 0, 0);
      currentTime = t1;

      final noOpResult = await repository.updateEntry(
        'entry-noop-1',
        EntryInput(
          title: '  Exact Title  ',
          body: 'Exact Body\nMulti Line',
          keyword: '  kw  ',
          categoryId: 'cat-1',
          tagIds: const ['tag-2', 'tag-1'],
          isFavorite: true,
          isArchived: false,
        ),
      );

      expect(noOpResult.updatedAt, t0);
      expect(noOpResult.createdAt, t0);

      final rawEntry = await (db.select(
        db.entries,
      )..where((t) => t.id.equals('entry-noop-1'))).getSingle();
      expect(rawEntry.updatedAt.toUtc(), t0);

      await pumpEventQueue();
      expect(emissions.length, 1);

      await subscription.cancel();
    });

    test('deleteEntry removes existing entry and cascaded join rows, fails on missing entry', () async {
      await seedTag('tag-del', 'Delete Tag');

      currentUuid = 'entry-to-del';
      currentTime = DateTime.utc(2026, 8, 24, 10, 0, 0);

      await repository.createEntry(
        EntryInput(
          title: 'Title to delete',
          body: 'Body to delete',
          tagIds: const ['tag-del'],
        ),
      );

      expect(
        () => repository.deleteEntry('missing-entry-id'),
        throwsA(const LibraryFailure.entryNotFound(id: 'missing-entry-id')),
      );

      await repository.deleteEntry('entry-to-del');

      final entries = await db.select(db.entries).get();
      final joins = await db.select(db.entryTags).get();
      expect(entries, isEmpty);
      expect(joins, isEmpty);

      final tags = await db.select(db.tags).get();
      expect(tags.length, 1);

      expect(
        () => repository.deleteEntry('entry-to-del'),
        throwsA(const LibraryFailure.entryNotFound(id: 'entry-to-del')),
      );
    });

    test(
      'markCopied changes only lastCopiedAt without changing updatedAt',
      () async {
        currentUuid = 'entry-copy-1';
        final t0 = DateTime.utc(2026, 8, 24, 10, 0, 0);
        currentTime = t0;

        await repository.createEntry(
          EntryInput(title: 'Prompt Title', body: 'Prompt Body'),
        );

        final t1 = DateTime.utc(2026, 8, 24, 11, 30, 0);
        currentTime = t1;

        await repository.markCopied('entry-copy-1');

        var raw = await (db.select(
          db.entries,
        )..where((t) => t.id.equals('entry-copy-1'))).getSingle();
        expect(raw.lastCopiedAt?.toUtc(), t1);
        expect(raw.updatedAt.toUtc(), t0);
        expect(raw.createdAt.toUtc(), t0);

        final t2 = DateTime.utc(2026, 8, 24, 15, 0, 0);
        currentTime = t2;

        await repository.markCopied('entry-copy-1');

        raw = await (db.select(
          db.entries,
        )..where((t) => t.id.equals('entry-copy-1'))).getSingle();
        expect(raw.lastCopiedAt?.toUtc(), t2);
        expect(raw.updatedAt.toUtc(), t0);
      },
    );

    test('setFavorite and setArchived update updatedAt only when value changes and no-op otherwise', () async {
      currentUuid = 'entry-flags-1';
      final t0 = DateTime.utc(2026, 8, 24, 10, 0, 0);
      currentTime = t0;

      await repository.createEntry(
        EntryInput(
          title: 'Flags Title',
          body: 'Flags Body',
          isFavorite: false,
          isArchived: false,
        ),
      );

      currentTime = DateTime.utc(2026, 8, 24, 11, 0, 0);
      await repository.setFavorite('entry-flags-1', isFavorite: false);
      var raw = await (db.select(
        db.entries,
      )..where((t) => t.id.equals('entry-flags-1'))).getSingle();
      expect(raw.isFavorite, isFalse);
      expect(raw.updatedAt.toUtc(), t0);

      final t2 = DateTime.utc(2026, 8, 24, 12, 0, 0);
      currentTime = t2;
      await repository.setFavorite('entry-flags-1', isFavorite: true);
      raw = await (db.select(
        db.entries,
      )..where((t) => t.id.equals('entry-flags-1'))).getSingle();
      expect(raw.isFavorite, isTrue);
      expect(raw.updatedAt.toUtc(), t2);

      currentTime = DateTime.utc(2026, 8, 24, 13, 0, 0);
      await repository.setFavorite('entry-flags-1', isFavorite: true);
      raw = await (db.select(
        db.entries,
      )..where((t) => t.id.equals('entry-flags-1'))).getSingle();
      expect(raw.isFavorite, isTrue);
      expect(raw.updatedAt.toUtc(), t2);

      currentTime = DateTime.utc(2026, 8, 24, 14, 0, 0);
      await repository.setArchived('entry-flags-1', isArchived: false);
      raw = await (db.select(
        db.entries,
      )..where((t) => t.id.equals('entry-flags-1'))).getSingle();
      expect(raw.isArchived, isFalse);
      expect(raw.updatedAt.toUtc(), t2);

      final t5 = DateTime.utc(2026, 8, 24, 15, 0, 0);
      currentTime = t5;
      await repository.setArchived('entry-flags-1', isArchived: true);
      raw = await (db.select(
        db.entries,
      )..where((t) => t.id.equals('entry-flags-1'))).getSingle();
      expect(raw.isArchived, isTrue);
      expect(raw.updatedAt.toUtc(), t5);

      currentTime = DateTime.utc(2026, 8, 24, 16, 0, 0);
      await repository.setArchived('entry-flags-1', isArchived: true);
      raw = await (db.select(
        db.entries,
      )..where((t) => t.id.equals('entry-flags-1'))).getSingle();
      expect(raw.isArchived, isTrue);
      expect(raw.updatedAt.toUtc(), t5);
    });

    test('all entry mutation methods throw entryNotFound failure for non-existent ID', () async {
      const missingId = 'non-existent-entry-id';
      final dummyInput = EntryInput(title: 'Title', body: 'Body');

      expect(
        () => repository.updateEntry(missingId, dummyInput),
        throwsA(const LibraryFailure.entryNotFound(id: missingId)),
      );

      expect(
        () => repository.deleteEntry(missingId),
        throwsA(const LibraryFailure.entryNotFound(id: missingId)),
      );

      expect(
        () => repository.markCopied(missingId),
        throwsA(const LibraryFailure.entryNotFound(id: missingId)),
      );

      expect(
        () => repository.setFavorite(missingId, isFavorite: true),
        throwsA(const LibraryFailure.entryNotFound(id: missingId)),
      );

      expect(
        () => repository.setArchived(missingId, isArchived: true),
        throwsA(const LibraryFailure.entryNotFound(id: missingId)),
      );
    });

    test('duplicate generated entry ID maps to constraintViolation database failure and preserves prior data', () async {
      currentUuid = 'existing-entry-id';
      currentTime = DateTime.utc(2026, 8, 24, 10, 0, 0);

      await repository.createEntry(
        EntryInput(title: 'Original Title', body: 'Original Body'),
      );

      currentUuid = 'existing-entry-id';

      expect(
        () => repository.createEntry(
          EntryInput(
            title: 'Attempted Duplicate Title',
            body: 'Attempted Duplicate Body',
          ),
        ),
        throwsA(
          isA<DatabaseFailureLibraryFailure>().having(
            (f) => f.code,
            'code',
            LibraryDatabaseFailureCode.constraintViolation,
          ),
        ),
      );

      final allEntries = await db.select(db.entries).get();
      expect(allEntries.length, 1);
      expect(allEntries.single.id, 'existing-entry-id');
      expect(allEntries.single.title, 'Original Title');
      expect(allEntries.single.body, 'Original Body');
    });
  });

  // === Category Mutations and Invariants ===
  group('DriftLibraryRepository (Stage 2E.3 Category Mutations & Invariants)', () {
    late LibraryDatabase db;
    late DriftLibraryRepository repository;
    late String currentUuid;
    late DateTime currentTime;

    setUp(() async {
      db = LibraryDatabase.forTesting(NativeDatabase.memory());
      currentUuid = 'cat-default-uuid';
      currentTime = DateTime.utc(2026, 8, 24, 10, 0, 0);
      repository = DriftLibraryRepository(
        db,
        uuidGenerator: () => currentUuid,
        clock: () => currentTime,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('createCategory trims display name and normalizes Latin and Cyrillic names', () async {
      currentUuid = 'cat-latin-1';
      currentTime = DateTime.utc(2026, 8, 24, 10, 0, 0);

      final latinCategory = await repository.createCategory(
        '  Prompt Engineering  ',
      );

      expect(latinCategory.id, 'cat-latin-1');
      expect(latinCategory.name, 'Prompt Engineering');
      expect(latinCategory.normalizedName, 'prompt engineering');
      expect(latinCategory.sortOrder, 0);
      expect(latinCategory.createdAt, DateTime.utc(2026, 8, 24, 10, 0, 0));
      expect(latinCategory.createdAt.isUtc, isTrue);

      final rawLatin = await (db.select(
        db.categories,
      )..where((t) => t.id.equals('cat-latin-1'))).getSingle();
      expect(rawLatin.name, 'Prompt Engineering');
      expect(rawLatin.normalizedName, 'prompt engineering');
      expect(rawLatin.sortOrder, 0);
      expect(rawLatin.createdAt.toUtc(), DateTime.utc(2026, 8, 24, 10, 0, 0));

      currentUuid = 'cat-cyrillic-1';
      currentTime = DateTime.utc(2026, 8, 24, 11, 0, 0);

      final cyrillicCategory = await repository.createCategory(
        '  Категория Промптов  ',
      );

      expect(cyrillicCategory.id, 'cat-cyrillic-1');
      expect(cyrillicCategory.name, 'Категория Промптов');
      expect(cyrillicCategory.normalizedName, 'категория промптов');
      expect(cyrillicCategory.sortOrder, 1);
      expect(cyrillicCategory.createdAt, DateTime.utc(2026, 8, 24, 11, 0, 0));
      expect(cyrillicCategory.createdAt.isUtc, isTrue);

      final rawCyrillic = await (db.select(
        db.categories,
      )..where((t) => t.id.equals('cat-cyrillic-1'))).getSingle();
      expect(rawCyrillic.name, 'Категория Промптов');
      expect(rawCyrillic.normalizedName, 'категория промптов');
      expect(rawCyrillic.sortOrder, 1);
    });

    test('createCategory rejects blank or whitespace-only names with emptyCategoryName failure', () async {
      expect(
        () => repository.createCategory(''),
        throwsA(
          const LibraryFailure.invalidInput(
            LibraryInputFailureReason.emptyCategoryName,
          ),
        ),
      );

      expect(
        () => repository.createCategory('   '),
        throwsA(
          const LibraryFailure.invalidInput(
            LibraryInputFailureReason.emptyCategoryName,
          ),
        ),
      );

      expect(
        () => repository.createCategory('\t \n  \r\n '),
        throwsA(
          const LibraryFailure.invalidInput(
            LibraryInputFailureReason.emptyCategoryName,
          ),
        ),
      );

      final allCategories = await db.select(db.categories).get();
      expect(allCategories, isEmpty);
    });

    test('createCategory assigns initial sortOrder 0 then max(sortOrder)+1 even with reordered gaps', () async {
      currentUuid = 'cat-seq-0';
      final cat0 = await repository.createCategory('Category A');
      expect(cat0.sortOrder, 0);

      currentUuid = 'cat-seq-1';
      final cat1 = await repository.createCategory('Category B');
      expect(cat1.sortOrder, 1);

      await (db.update(db.categories)..where((t) => t.id.equals('cat-seq-1')))
          .write(const CategoriesCompanion(sortOrder: Value(10)));

      currentUuid = 'cat-seq-2';
      final cat2 = await repository.createCategory('Category C');
      expect(cat2.sortOrder, 11);

      final all = await (db.select(
        db.categories,
      )..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();
      expect(all.map((c) => c.sortOrder), [0, 10, 11]);
    });

    test('createCategory rejects normalized duplicate names for Latin and Cyrillic', () async {
      currentUuid = 'cat-backend';
      await repository.createCategory('Backend');

      expect(
        () => repository.createCategory('backend'),
        throwsA(const LibraryFailure.duplicateCategoryName()),
      );

      expect(
        () => repository.createCategory('  BACKEND  '),
        throwsA(const LibraryFailure.duplicateCategoryName()),
      );

      currentUuid = 'cat-ru';
      await repository.createCategory('Промпты');

      expect(
        () => repository.createCategory('промпты'),
        throwsA(const LibraryFailure.duplicateCategoryName()),
      );

      expect(
        () => repository.createCategory('  ПРОМПТЫ \n'),
        throwsA(const LibraryFailure.duplicateCategoryName()),
      );

      final all = await db.select(db.categories).get();
      expect(all.length, 2);
    });

    test('createCategory maps unique constraint race to duplicateCategoryName failure', () async {
      await db.customStatement('''
        CREATE TRIGGER category_normalized_name_race
        BEFORE INSERT ON categories
        WHEN NEW.id = 'cat-race-2'
        BEGIN
          INSERT INTO categories (
            id,
            name,
            normalized_name,
            sort_order,
            created_at
          ) VALUES (
            'cat-race-direct',
            'Directly Inserted',
            NEW.normalized_name,
            5,
            NEW.created_at
          );
        END;
      ''');

      currentUuid = 'cat-race-2';
      expect(
        () => repository.createCategory('  Raced Normalized Name  '),
        throwsA(const LibraryFailure.duplicateCategoryName()),
      );
      expect(await db.select(db.categories).get(), isEmpty);
    });

    test(
      'createCategory maps primary key collision to constraint failure',
      () async {
        currentUuid = 'shared-category-id';
        await repository.createCategory('First Category');

        currentUuid = 'shared-category-id';
        expect(
          () => repository.createCategory('Second Category'),
          throwsA(
            const LibraryFailure.databaseFailure(
              code: LibraryDatabaseFailureCode.constraintViolation,
            ),
          ),
        );
      },
    );

    test(
      'renameCategory throws categoryNotFound failure for missing category ID',
      () async {
        const missingId = 'non-existent-category';

        expect(
          () => repository.renameCategory(missingId, 'New Name'),
          throwsA(const LibraryFailure.categoryNotFound(id: missingId)),
        );
      },
    );

    test('renameCategory rejects blank or whitespace-only new name with emptyCategoryName failure', () async {
      currentUuid = 'cat-rename-blank';
      await repository.createCategory('Original Name');

      expect(
        () => repository.renameCategory('cat-rename-blank', ''),
        throwsA(
          const LibraryFailure.invalidInput(
            LibraryInputFailureReason.emptyCategoryName,
          ),
        ),
      );

      expect(
        () => repository.renameCategory('cat-rename-blank', '   \t\n  '),
        throwsA(
          const LibraryFailure.invalidInput(
            LibraryInputFailureReason.emptyCategoryName,
          ),
        ),
      );

      final raw = await (db.select(
        db.categories,
      )..where((t) => t.id.equals('cat-rename-blank'))).getSingle();
      expect(raw.name, 'Original Name');
      expect(raw.normalizedName, 'original name');
    });

    test('renameCategory rejects duplicate normalized name of another existing category', () async {
      currentUuid = 'cat-rename-1';
      await repository.createCategory('Personal');
      currentUuid = 'cat-rename-2';
      await repository.createCategory('Work');

      expect(
        () => repository.renameCategory('cat-rename-2', 'personal'),
        throwsA(const LibraryFailure.duplicateCategoryName()),
      );

      expect(
        () => repository.renameCategory('cat-rename-2', '  PERSONAL  '),
        throwsA(const LibraryFailure.duplicateCategoryName()),
      );

      final raw2 = await (db.select(
        db.categories,
      )..where((t) => t.id.equals('cat-rename-2'))).getSingle();
      expect(raw2.name, 'Work');
      expect(raw2.normalizedName, 'work');
    });

    test('renameCategory permits observable case and display changes for same category', () async {
      currentUuid = 'cat-case-change';
      final t0 = DateTime.utc(2026, 8, 24, 10, 0, 0);
      currentTime = t0;
      final created = await repository.createCategory('work');

      currentTime = DateTime.utc(2026, 8, 24, 12, 0, 0);
      final renamed = await repository.renameCategory(
        'cat-case-change',
        '  Work  ',
      );

      expect(renamed.id, 'cat-case-change');
      expect(renamed.name, 'Work');
      expect(renamed.normalizedName, 'work');
      expect(renamed.sortOrder, created.sortOrder);
      expect(renamed.createdAt, t0);

      final raw = await (db.select(
        db.categories,
      )..where((t) => t.id.equals('cat-case-change'))).getSingle();
      expect(raw.name, 'Work');
      expect(raw.normalizedName, 'work');
      expect(raw.createdAt.toUtc(), t0);

      final renamedUppercase = await repository.renameCategory(
        'cat-case-change',
        'WORK',
      );
      expect(renamedUppercase.name, 'WORK');
      expect(renamedUppercase.normalizedName, 'work');
    });

    test(
      'deleteCategory throws categoryNotFound failure for missing category ID',
      () async {
        const missingId = 'non-existent-category';

        expect(
          () => repository.deleteCategory(missingId),
          throwsA(const LibraryFailure.categoryNotFound(id: missingId)),
        );
      },
    );

    test('deleteCategory deletes existing category and SET NULL on associated entries in SQLite', () async {
      currentUuid = 'cat-to-delete';
      await repository.createCategory('Delete Me');
      currentUuid = 'cat-keep';
      await repository.createCategory('Keep Me');

      currentUuid = 'entry-with-cat';
      await repository.createEntry(
        EntryInput(
          title: 'Entry 1',
          body: 'Body 1',
          categoryId: 'cat-to-delete',
        ),
      );

      currentUuid = 'entry-with-other-cat';
      await repository.createEntry(
        EntryInput(title: 'Entry 2', body: 'Body 2', categoryId: 'cat-keep'),
      );

      await repository.deleteCategory('cat-to-delete');

      final allCats = await db.select(db.categories).get();
      expect(allCats.map((c) => c.id), ['cat-keep']);

      final rawEntry1 = await (db.select(
        db.entries,
      )..where((t) => t.id.equals('entry-with-cat'))).getSingle();
      expect(rawEntry1.categoryId, isNull);

      final rawEntry2 = await (db.select(
        db.entries,
      )..where((t) => t.id.equals('entry-with-other-cat'))).getSingle();
      expect(rawEntry2.categoryId, 'cat-keep');

      final snapshot = await repository.getSnapshot();
      expect(snapshot.categories.map((c) => c.id), ['cat-keep']);
      final entry1FromSnapshot = snapshot.entries.firstWhere(
        (e) => e.id == 'entry-with-cat',
      );
      expect(entry1FromSnapshot.categoryId, isNull);
    });

    test('reorderCategories applies contiguous 0-based order atomically across all categories', () async {
      currentUuid = 'cat-1';
      final c1 = await repository.createCategory('Cat 1');
      currentUuid = 'cat-2';
      final c2 = await repository.createCategory('Cat 2');
      currentUuid = 'cat-3';
      final c3 = await repository.createCategory('Cat 3');

      expect(c1.sortOrder, 0);
      expect(c2.sortOrder, 1);
      expect(c3.sortOrder, 2);

      await repository.reorderCategories([c3.id, c1.id, c2.id]);

      final rawC3 = await (db.select(
        db.categories,
      )..where((t) => t.id.equals('cat-3'))).getSingle();
      final rawC1 = await (db.select(
        db.categories,
      )..where((t) => t.id.equals('cat-1'))).getSingle();
      final rawC2 = await (db.select(
        db.categories,
      )..where((t) => t.id.equals('cat-2'))).getSingle();

      expect(rawC3.sortOrder, 0);
      expect(rawC1.sortOrder, 1);
      expect(rawC2.sortOrder, 2);

      final snapshot = await repository.getSnapshot();
      expect(snapshot.categories.map((c) => c.id), [c3.id, c1.id, c2.id]);
    });

    test('reorderCategories rejects duplicate IDs with invalidCategoryReorder failure', () async {
      currentUuid = 'cat-1';
      final c1 = await repository.createCategory('Cat 1');
      currentUuid = 'cat-2';
      final c2 = await repository.createCategory('Cat 2');
      currentUuid = 'cat-3';
      await repository.createCategory('Cat 3');

      expect(
        () => repository.reorderCategories([c1.id, c2.id, c1.id]),
        throwsA(
          const LibraryFailure.invalidCategoryReorder(
            expectedCount: 3,
            actualCount: 3,
          ),
        ),
      );

      final raw = await (db.select(
        db.categories,
      )..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();
      expect(raw.map((c) => c.id), ['cat-1', 'cat-2', 'cat-3']);
      expect(raw.map((c) => c.sortOrder), [0, 1, 2]);
    });

    test('reorderCategories rejects unknown category IDs with invalidCategoryReorder failure', () async {
      currentUuid = 'cat-1';
      final c1 = await repository.createCategory('Cat 1');
      currentUuid = 'cat-2';
      await repository.createCategory('Cat 2');

      expect(
        () => repository.reorderCategories([c1.id, 'unknown-cat-id']),
        throwsA(
          const LibraryFailure.invalidCategoryReorder(
            expectedCount: 2,
            actualCount: 2,
          ),
        ),
      );

      final raw = await (db.select(
        db.categories,
      )..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();
      expect(raw.map((c) => c.id), ['cat-1', 'cat-2']);
      expect(raw.map((c) => c.sortOrder), [0, 1]);
    });

    test('reorderCategories rejects incomplete or extra category IDs with invalidCategoryReorder failure', () async {
      currentUuid = 'cat-1';
      final c1 = await repository.createCategory('Cat 1');
      currentUuid = 'cat-2';
      final c2 = await repository.createCategory('Cat 2');
      currentUuid = 'cat-3';
      final c3 = await repository.createCategory('Cat 3');

      expect(
        () => repository.reorderCategories([c1.id, c2.id]),
        throwsA(
          const LibraryFailure.invalidCategoryReorder(
            expectedCount: 3,
            actualCount: 2,
          ),
        ),
      );

      expect(
        () =>
            repository.reorderCategories([c1.id, c2.id, c3.id, 'extra-cat-id']),
        throwsA(
          const LibraryFailure.invalidCategoryReorder(
            expectedCount: 3,
            actualCount: 4,
          ),
        ),
      );

      final raw = await (db.select(
        db.categories,
      )..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();
      expect(raw.map((c) => c.id), ['cat-1', 'cat-2', 'cat-3']);
      expect(raw.map((c) => c.sortOrder), [0, 1, 2]);
    });

    test(
      'reorderCategories empty list works when no categories exist in database',
      () async {
        await repository.reorderCategories([]);

        final all = await db.select(db.categories).get();
        expect(all, isEmpty);
      },
    );

    test('reorderCategories non-empty list when no categories exist throws invalidCategoryReorder failure', () async {
      expect(
        () => repository.reorderCategories(['non-existent-cat']),
        throwsA(
          const LibraryFailure.invalidCategoryReorder(
            expectedCount: 0,
            actualCount: 1,
          ),
        ),
      );
    });
  });

  // === Tag Mutations and Invariants ===
  group('DriftLibraryRepository (Stage 2E.4 Tag Mutations & Invariants)', () {
    late LibraryDatabase db;
    late DriftLibraryRepository repository;
    late String currentUuid;
    late DateTime currentTime;

    setUp(() async {
      db = LibraryDatabase.forTesting(NativeDatabase.memory());
      currentUuid = 'tag-default-uuid';
      currentTime = DateTime.utc(2026, 8, 24, 10, 0, 0);
      repository = DriftLibraryRepository(
        db,
        uuidGenerator: () => currentUuid,
        clock: () => currentTime,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'createTag trims display name and normalizes Latin and Cyrillic names',
      () async {
        currentUuid = 'tag-latin-1';
        currentTime = DateTime.utc(2026, 8, 24, 10, 0, 0);

        final latinTag = await repository.createTag('  Prompt Engineering  ');

        expect(latinTag.id, 'tag-latin-1');
        expect(latinTag.name, 'Prompt Engineering');
        expect(latinTag.normalizedName, 'prompt engineering');
        expect(latinTag.createdAt, DateTime.utc(2026, 8, 24, 10, 0, 0));
        expect(latinTag.createdAt.isUtc, isTrue);

        final rawLatin = await (db.select(
          db.tags,
        )..where((t) => t.id.equals('tag-latin-1'))).getSingle();
        expect(rawLatin.name, 'Prompt Engineering');
        expect(rawLatin.normalizedName, 'prompt engineering');
        expect(rawLatin.createdAt.toUtc(), DateTime.utc(2026, 8, 24, 10, 0, 0));

        currentUuid = 'tag-cyrillic-1';
        currentTime = DateTime.utc(2026, 8, 24, 11, 0, 0);

        final cyrillicTag = await repository.createTag('  Тег Промптов  ');

        expect(cyrillicTag.id, 'tag-cyrillic-1');
        expect(cyrillicTag.name, 'Тег Промптов');
        expect(cyrillicTag.normalizedName, 'тег промптов');
        expect(cyrillicTag.createdAt, DateTime.utc(2026, 8, 24, 11, 0, 0));
        expect(cyrillicTag.createdAt.isUtc, isTrue);

        final rawCyrillic = await (db.select(
          db.tags,
        )..where((t) => t.id.equals('tag-cyrillic-1'))).getSingle();
        expect(rawCyrillic.name, 'Тег Промптов');
        expect(rawCyrillic.normalizedName, 'тег промптов');
      },
    );

    test('createTag rejects blank or whitespace-only names with emptyTagName failure', () async {
      expect(
        () => repository.createTag(''),
        throwsA(
          const LibraryFailure.invalidInput(
            LibraryInputFailureReason.emptyTagName,
          ),
        ),
      );

      expect(
        () => repository.createTag('   '),
        throwsA(
          const LibraryFailure.invalidInput(
            LibraryInputFailureReason.emptyTagName,
          ),
        ),
      );

      expect(
        () => repository.createTag('\t \n  \r\n '),
        throwsA(
          const LibraryFailure.invalidInput(
            LibraryInputFailureReason.emptyTagName,
          ),
        ),
      );

      final allTags = await db.select(db.tags).get();
      expect(allTags, isEmpty);
    });

    test('createTag uses injected UUID and UTC createdAt timestamp', () async {
      currentUuid = 'custom-injected-tag-uuid';
      currentTime = DateTime.utc(2026, 1, 15, 8, 30, 0);

      final tag = await repository.createTag('Architecture');

      expect(tag.id, 'custom-injected-tag-uuid');
      expect(tag.name, 'Architecture');
      expect(tag.normalizedName, 'architecture');
      expect(tag.createdAt, DateTime.utc(2026, 1, 15, 8, 30, 0));
      expect(tag.createdAt.isUtc, isTrue);

      final raw = await (db.select(
        db.tags,
      )..where((t) => t.id.equals('custom-injected-tag-uuid'))).getSingle();
      expect(raw.id, 'custom-injected-tag-uuid');
      expect(raw.createdAt.toUtc(), DateTime.utc(2026, 1, 15, 8, 30, 0));
    });

    test(
      'createTag rejects normalized duplicate names for Latin and Cyrillic',
      () async {
        currentUuid = 'tag-flutter';
        await repository.createTag('Flutter');

        expect(
          () => repository.createTag('flutter'),
          throwsA(const LibraryFailure.duplicateTagName()),
        );

        expect(
          () => repository.createTag('  FLUTTER  '),
          throwsA(const LibraryFailure.duplicateTagName()),
        );

        currentUuid = 'tag-ru';
        await repository.createTag('Разработка');

        expect(
          () => repository.createTag('разработка'),
          throwsA(const LibraryFailure.duplicateTagName()),
        );

        expect(
          () => repository.createTag('  РАЗРАБОТКА \n'),
          throwsA(const LibraryFailure.duplicateTagName()),
        );

        final all = await db.select(db.tags).get();
        expect(all.length, 2);
      },
    );

    test(
      'createTag maps unique constraint race to duplicateTagName failure',
      () async {
        await db.customStatement('''
          CREATE TRIGGER tag_normalized_name_race
          BEFORE INSERT ON tags
          WHEN NEW.id = 'tag-race-2'
          BEGIN
            INSERT INTO tags (
              id,
              name,
              normalized_name,
              created_at
            ) VALUES (
              'tag-race-direct',
              'Directly Inserted',
              NEW.normalized_name,
              NEW.created_at
            );
          END;
        ''');

        currentUuid = 'tag-race-2';
        expect(
          () => repository.createTag('  Raced Tag Normalized Name  '),
          throwsA(const LibraryFailure.duplicateTagName()),
        );
        expect(await db.select(db.tags).get(), isEmpty);
      },
    );

    test(
      'createTag maps primary key collision to constraint failure',
      () async {
        currentUuid = 'shared-tag-id';
        await repository.createTag('First Tag');

        currentUuid = 'shared-tag-id';
        expect(
          () => repository.createTag('Second Tag'),
          throwsA(
            const LibraryFailure.databaseFailure(
              code: LibraryDatabaseFailureCode.constraintViolation,
            ),
          ),
        );
      },
    );

    test('renameTag throws tagNotFound failure for missing tag ID', () async {
      const missingId = 'non-existent-tag';

      expect(
        () => repository.renameTag(missingId, 'New Name'),
        throwsA(const LibraryFailure.tagNotFound(id: missingId)),
      );
    });

    test('renameTag rejects blank or whitespace-only new name with emptyTagName failure', () async {
      currentUuid = 'tag-rename-blank';
      await repository.createTag('Original Tag Name');

      expect(
        () => repository.renameTag('tag-rename-blank', ''),
        throwsA(
          const LibraryFailure.invalidInput(
            LibraryInputFailureReason.emptyTagName,
          ),
        ),
      );

      expect(
        () => repository.renameTag('tag-rename-blank', '   \t\n  '),
        throwsA(
          const LibraryFailure.invalidInput(
            LibraryInputFailureReason.emptyTagName,
          ),
        ),
      );

      final raw = await (db.select(
        db.tags,
      )..where((t) => t.id.equals('tag-rename-blank'))).getSingle();
      expect(raw.name, 'Original Tag Name');
      expect(raw.normalizedName, 'original tag name');
    });

    test(
      'renameTag rejects duplicate normalized name of another existing tag',
      () async {
        currentUuid = 'tag-rename-1';
        await repository.createTag('Draft');
        currentUuid = 'tag-rename-2';
        await repository.createTag('Final');

        expect(
          () => repository.renameTag('tag-rename-2', 'draft'),
          throwsA(const LibraryFailure.duplicateTagName()),
        );

        expect(
          () => repository.renameTag('tag-rename-2', '  DRAFT  '),
          throwsA(const LibraryFailure.duplicateTagName()),
        );

        final raw2 = await (db.select(
          db.tags,
        )..where((t) => t.id.equals('tag-rename-2'))).getSingle();
        expect(raw2.name, 'Final');
        expect(raw2.normalizedName, 'final');
      },
    );

    test(
      'renameTag permits observable case and display changes for same tag',
      () async {
        currentUuid = 'tag-case-change';
        final t0 = DateTime.utc(2026, 8, 24, 10, 0, 0);
        currentTime = t0;
        await repository.createTag('flutter');

        currentTime = DateTime.utc(2026, 8, 24, 12, 0, 0);
        final renamed = await repository.renameTag(
          'tag-case-change',
          '  Flutter  ',
        );

        expect(renamed.id, 'tag-case-change');
        expect(renamed.name, 'Flutter');
        expect(renamed.normalizedName, 'flutter');
        expect(renamed.createdAt, t0);

        final raw = await (db.select(
          db.tags,
        )..where((t) => t.id.equals('tag-case-change'))).getSingle();
        expect(raw.name, 'Flutter');
        expect(raw.normalizedName, 'flutter');
        expect(raw.createdAt.toUtc(), t0);

        final renamedUppercase = await repository.renameTag(
          'tag-case-change',
          'FLUTTER',
        );
        expect(renamedUppercase.name, 'FLUTTER');
        expect(renamedUppercase.normalizedName, 'flutter');
      },
    );

    test('deleteTag throws tagNotFound failure for missing tag ID', () async {
      const missingId = 'non-existent-tag';

      expect(
        () => repository.deleteTag(missingId),
        throwsA(const LibraryFailure.tagNotFound(id: missingId)),
      );
    });

    test('deleteTag deletes existing tag and CASCADE removes entry_tags while entry remains', () async {
      currentUuid = 'tag-to-delete';
      await repository.createTag('Delete Tag');
      currentUuid = 'tag-keep';
      await repository.createTag('Keep Tag');

      currentUuid = 'entry-with-tags';
      await repository.createEntry(
        EntryInput(
          title: 'Entry 1',
          body: 'Body 1',
          tagIds: ['tag-to-delete', 'tag-keep'],
        ),
      );

      currentUuid = 'entry-with-other-tag';
      await repository.createEntry(
        EntryInput(title: 'Entry 2', body: 'Body 2', tagIds: ['tag-keep']),
      );

      await repository.deleteTag('tag-to-delete');

      final allTags = await db.select(db.tags).get();
      expect(allTags.map((t) => t.id), ['tag-keep']);

      final allEntryTags = await db.select(db.entryTags).get();
      expect(allEntryTags.where((et) => et.tagId == 'tag-to-delete'), isEmpty);
      expect(allEntryTags.length, 2);
      expect(
        allEntryTags.map((et) => '${et.entryId}:${et.tagId}'),
        unorderedEquals([
          'entry-with-tags:tag-keep',
          'entry-with-other-tag:tag-keep',
        ]),
      );

      final allEntries = await db.select(db.entries).get();
      expect(
        allEntries.map((e) => e.id),
        unorderedEquals(['entry-with-tags', 'entry-with-other-tag']),
      );

      final snapshot = await repository.getSnapshot();
      expect(snapshot.tags.map((t) => t.id), ['tag-keep']);
      final entry1FromSnapshot = snapshot.entries.firstWhere(
        (e) => e.id == 'entry-with-tags',
      );
      expect(entry1FromSnapshot.tagIds, ['tag-keep']);
    });

    test(
      'DriftLibraryRepository satisfies LibraryRepository compile contract',
      () {
        final LibraryRepository repo = repository;
        expect(repo, isA<LibraryRepository>());
        expect(repo, isA<DriftLibraryRepository>());
      },
    );
  });

  // === Contract Verification Ledger ===
  group('DriftLibraryRepository (Stage 2E.5 Comprehensive Contract Verification Ledger)', () {
    late LibraryDatabase db;
    late DriftLibraryRepository repository;
    late String currentUuid;
    late DateTime currentTime;

    setUp(() async {
      db = LibraryDatabase.forTesting(NativeDatabase.memory());
      currentUuid = 'e5-default-uuid';
      currentTime = DateTime.utc(2026, 8, 24, 10, 0, 0);
      repository = DriftLibraryRepository(
        db,
        uuidGenerator: () => currentUuid,
        clock: () => currentTime,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('updateEntry transitions entry from populated category/tags/keyword to null and empty', () async {
      currentUuid = 'cat-e5-orig';
      final cat = await repository.createCategory('Original Category');
      currentUuid = 'tag-e5-1';
      final tag1 = await repository.createTag('Tag Alpha');
      currentUuid = 'tag-e5-2';
      final tag2 = await repository.createTag('Tag Beta');

      currentUuid = 'entry-e5-trans';
      final t0 = DateTime.utc(2026, 8, 24, 10, 0, 0);
      currentTime = t0;

      final created = await repository.createEntry(
        EntryInput(
          title: 'Fully Populated Title',
          body: 'Fully populated body text.',
          keyword: 'search-keyword',
          categoryId: cat.id,
          tagIds: [tag1.id, tag2.id],
          isFavorite: true,
          isArchived: false,
        ),
      );
      expect(created.categoryId, cat.id);
      expect(created.tagIds, [tag1.id, tag2.id]);
      expect(created.keyword, 'search-keyword');

      final t1 = DateTime.utc(2026, 8, 24, 11, 30, 0);
      currentTime = t1;

      final updated = await repository.updateEntry(
        'entry-e5-trans',
        EntryInput(
          title: 'Updated To Minimal Title',
          body: 'Updated body text without category or tags.',
          keyword: '   ',
          categoryId: null,
          tagIds: const [],
          isFavorite: false,
          isArchived: true,
        ),
      );

      expect(updated.id, 'entry-e5-trans');
      expect(updated.title, 'Updated To Minimal Title');
      expect(updated.body, 'Updated body text without category or tags.');
      expect(updated.keyword, isNull);
      expect(updated.categoryId, isNull);
      expect(updated.tagIds, isEmpty);
      expect(updated.isFavorite, isFalse);
      expect(updated.isArchived, isTrue);
      expect(updated.createdAt, t0);
      expect(updated.updatedAt, t1);

      final rawEntry = await (db.select(
        db.entries,
      )..where((t) => t.id.equals('entry-e5-trans'))).getSingle();
      expect(rawEntry.title, 'Updated To Minimal Title');
      expect(rawEntry.keyword, isNull);
      expect(rawEntry.categoryId, isNull);
      expect(rawEntry.isFavorite, isFalse);
      expect(rawEntry.isArchived, isTrue);
      expect(rawEntry.updatedAt.toUtc(), t1);

      final rawJoins = await (db.select(
        db.entryTags,
      )..where((t) => t.entryId.equals('entry-e5-trans'))).get();
      expect(rawJoins, isEmpty);

      final snapshot = await repository.getSnapshot();
      final entryInSnapshot = snapshot.entries.single;
      expect(entryInSnapshot.categoryId, isNull);
      expect(entryInSnapshot.tagIds, isEmpty);
      expect(snapshot.tagsForEntry['entry-e5-trans'], isEmpty);
    });

    test('createEntry with minimal inputs persists null category and empty tags without error', () async {
      currentUuid = 'entry-e5-min';
      currentTime = DateTime.utc(2026, 8, 24, 10, 0, 0);

      final entry = await repository.createEntry(
        EntryInput(
          title: '  Minimal Entry  ',
          body: 'Minimal body with no taxonomy.',
          keyword: '   ',
          categoryId: null,
          tagIds: const [],
        ),
      );

      expect(entry.id, 'entry-e5-min');
      expect(entry.title, 'Minimal Entry');
      expect(entry.body, 'Minimal body with no taxonomy.');
      expect(entry.keyword, isNull);
      expect(entry.categoryId, isNull);
      expect(entry.tagIds, isEmpty);
      expect(entry.isFavorite, isFalse);
      expect(entry.isArchived, isFalse);
      expect(entry.createdAt, DateTime.utc(2026, 8, 24, 10, 0, 0));
      expect(entry.updatedAt, DateTime.utc(2026, 8, 24, 10, 0, 0));
      expect(entry.lastCopiedAt, isNull);

      final rawEntry = await (db.select(
        db.entries,
      )..where((t) => t.id.equals('entry-e5-min'))).getSingle();
      expect(rawEntry.categoryId, isNull);
      expect(rawEntry.keyword, isNull);

      final rawJoins = await (db.select(
        db.entryTags,
      )..where((t) => t.entryId.equals('entry-e5-min'))).get();
      expect(rawJoins, isEmpty);
    });

    test(
      'exact body preservation across exotic formatting and code blocks',
      () async {
        const exoticBody1 =
            '# System Architecture Prompt\n'
            '```yaml\n'
            'version: "2.0"\n'
            'settings:\n'
            '  strict: true\n'
            '```\n'
            '\t- Bullet 1 with \t tabs\n'
            '\t- Bullet 2 with trailing spaces:   \n'
            '\n'
            'Emoji: 🚀 ⚡ 🎯 & Cyrillic: Привет Мир\n'
            'Final line with trailing tab\t';

        currentUuid = 'entry-e5-exotic';
        currentTime = DateTime.utc(2026, 8, 24, 10, 0, 0);

        final created = await repository.createEntry(
          EntryInput(title: 'Exotic Formatting Entry', body: exoticBody1),
        );
        expect(created.body, exoticBody1);

        final snapshot1 = await repository.getSnapshot();
        expect(snapshot1.entries.single.body, exoticBody1);

        const exoticBody2 =
            '  Leading 2 spaces on line 1\n'
            '    Leading 4 spaces on line 2\n'
            '\n\n'
            '${"\$"}VARS and "quotes" and \'single quotes\'\n'
            'No trailing newline';

        currentTime = DateTime.utc(2026, 8, 24, 12, 0, 0);
        final updated = await repository.updateEntry(
          'entry-e5-exotic',
          EntryInput(title: 'Exotic Formatting Entry', body: exoticBody2),
        );
        expect(updated.body, exoticBody2);

        final snapshot2 = await repository.getSnapshot();
        expect(snapshot2.entries.single.body, exoticBody2);

        final raw = await (db.select(
          db.entries,
        )..where((t) => t.id.equals('entry-e5-exotic'))).getSingle();
        expect(raw.body, exoticBody2);
      },
    );

    test('createCategory recalculates max sortOrder after highest category is deleted', () async {
      currentUuid = 'cat-e5-a';
      final cA = await repository.createCategory('Category Alpha');
      currentUuid = 'cat-e5-b';
      final cB = await repository.createCategory('Category Beta');
      currentUuid = 'cat-e5-c';
      final cC = await repository.createCategory('Category Gamma');

      expect(cA.sortOrder, 0);
      expect(cB.sortOrder, 1);
      expect(cC.sortOrder, 2);

      await repository.deleteCategory(cC.id);

      currentUuid = 'cat-e5-d';
      final cD = await repository.createCategory('Category Delta');
      expect(cD.sortOrder, 2);

      final snapshot = await repository.getSnapshot();
      expect(snapshot.categories.map((c) => c.name).toList(), [
        'Category Alpha',
        'Category Beta',
        'Category Delta',
      ]);
      expect(snapshot.categories.map((c) => c.sortOrder).toList(), [0, 1, 2]);
    });

    test('watchSnapshot emits updated coherent snapshot when category deletion cascades SET NULL', () async {
      currentUuid = 'cat-e5-watch';
      final cat = await repository.createCategory('Watch Category');

      currentUuid = 'entry-e5-watch';
      await repository.createEntry(
        EntryInput(
          title: 'Watch Entry',
          body: 'Body text.',
          categoryId: cat.id,
        ),
      );

      final stream = repository.watchSnapshot();
      final emissions = <LibrarySnapshot>[];
      final completer = Completer<void>();

      final subscription = stream.listen((snapshot) {
        emissions.add(snapshot);
        if (emissions.length == 2) {
          completer.complete();
        }
      });

      await pumpEventQueue();
      expect(emissions.length, 1);
      expect(emissions.first.categories.length, 1);
      expect(emissions.first.entries.single.categoryId, cat.id);

      await repository.deleteCategory(cat.id);
      await completer.future.timeout(const Duration(seconds: 2));

      expect(emissions.length, 2);
      expect(emissions[1].categories, isEmpty);
      expect(emissions[1].entries.single.categoryId, isNull);

      await subscription.cancel();
    });

    test('watchSnapshot emits updated coherent snapshot when tag deletion cascades entry_tags removal', () async {
      currentUuid = 'tag-e5-watch-1';
      final tag1 = await repository.createTag('Watch Tag 1');
      currentUuid = 'tag-e5-watch-2';
      final tag2 = await repository.createTag('Watch Tag 2');

      currentUuid = 'entry-e5-watch-tags';
      await repository.createEntry(
        EntryInput(
          title: 'Watch Entry Tags',
          body: 'Body text.',
          tagIds: [tag1.id, tag2.id],
        ),
      );

      final stream = repository.watchSnapshot();
      final emissions = <LibrarySnapshot>[];
      final completer = Completer<void>();

      final subscription = stream.listen((snapshot) {
        emissions.add(snapshot);
        if (emissions.length == 2) {
          completer.complete();
        }
      });

      await pumpEventQueue();
      expect(emissions.length, 1);
      expect(emissions.first.tags.length, 2);
      expect(emissions.first.entries.single.tagIds, [tag1.id, tag2.id]);

      await repository.deleteTag(tag1.id);
      await completer.future.timeout(const Duration(seconds: 2));

      expect(emissions.length, 2);
      expect(emissions[1].tags.map((t) => t.id).toList(), [tag2.id]);
      expect(emissions[1].entries.single.tagIds, [tag2.id]);
      expect(
        emissions[1].tagsForEntry['entry-e5-watch-tags']
            ?.map((t) => t.id)
            .toList(),
        [tag2.id],
      );

      await subscription.cancel();
    });

    test('reorderCategories with exactly one category succeeds and sets sortOrder 0', () async {
      currentUuid = 'cat-single';
      final singleCat = await repository.createCategory('Single Category');
      expect(singleCat.sortOrder, 0);

      await repository.reorderCategories([singleCat.id]);

      final snapshot = await repository.getSnapshot();
      expect(snapshot.categories.length, 1);
      expect(snapshot.categories.single.id, singleCat.id);
      expect(snapshot.categories.single.sortOrder, 0);
    });

    test(
      'no-op update with trimmed-equivalent keyword preserves updatedAt',
      () async {
        currentUuid = 'entry-noop-kw';
        final t0 = DateTime.utc(2026, 8, 24, 10, 0, 0);
        currentTime = t0;

        await repository.createEntry(
          EntryInput(
            title: 'Keyword Title',
            body: 'Keyword Body',
            keyword: 'exact-keyword',
          ),
        );

        currentTime = DateTime.utc(2026, 8, 24, 14, 0, 0);
        final noOpResult = await repository.updateEntry(
          'entry-noop-kw',
          EntryInput(
            title: 'Keyword Title',
            body: 'Keyword Body',
            keyword: '  exact-keyword  ',
          ),
        );

        expect(noOpResult.updatedAt, t0);

        final raw = await (db.select(
          db.entries,
        )..where((t) => t.id.equals('entry-noop-kw'))).getSingle();
        expect(raw.updatedAt.toUtc(), t0);
        expect(raw.keyword, 'exact-keyword');
      },
    );

    test('cross-entity complete round-trip verifies all snapshot lookup maps and unused taxonomy', () async {
      currentUuid = 'cat-used-1';
      final cat1 = await repository.createCategory('Category In Use');
      currentUuid = 'cat-unused-1';
      final catUnused = await repository.createCategory('Category Unused');

      currentUuid = 'tag-used-1';
      final tag1 = await repository.createTag('Tag In Use 1');
      currentUuid = 'tag-used-2';
      final tag2 = await repository.createTag('Tag In Use 2');
      currentUuid = 'tag-unused-1';
      final tagUnused = await repository.createTag('Tag Unused');

      currentUuid = 'entry-full-1';
      currentTime = DateTime.utc(2026, 8, 24, 10, 0, 0);
      final entry1 = await repository.createEntry(
        EntryInput(
          title: 'Entry Full 1',
          body: 'Prompt body 1',
          keyword: 'p1',
          categoryId: cat1.id,
          tagIds: [tag1.id, tag2.id],
          isFavorite: true,
          isArchived: false,
        ),
      );

      currentUuid = 'entry-full-2';
      currentTime = DateTime.utc(2026, 8, 24, 11, 0, 0);
      final entry2 = await repository.createEntry(
        EntryInput(
          title: 'Entry Full 2',
          body: 'Prompt body 2',
          keyword: null,
          categoryId: null,
          tagIds: [tag2.id],
          isFavorite: false,
          isArchived: true,
        ),
      );

      final snapshot = await repository.getSnapshot();

      expect(snapshot.entries.length, 2);
      expect(snapshot.categories.length, 2);
      expect(snapshot.tags.length, 3);

      expect(snapshot.categories.map((c) => c.id), contains(catUnused.id));
      expect(snapshot.tags.map((t) => t.id), contains(tagUnused.id));

      expect(snapshot.categoryById[cat1.id]?.name, 'Category In Use');
      expect(snapshot.categoryById[catUnused.id]?.name, 'Category Unused');
      expect(snapshot.tagById[tag1.id]?.name, 'Tag In Use 1');
      expect(snapshot.tagById[tagUnused.id]?.name, 'Tag Unused');

      expect(snapshot.tagsForEntry[entry1.id]?.map((t) => t.id).toList(), [
        tag1.id,
        tag2.id,
      ]);
      expect(snapshot.tagsForEntry[entry2.id]?.map((t) => t.id).toList(), [
        tag2.id,
      ]);
      expect(snapshot.tagsForEntry['non-existent-entry'], isNull);

      expect(snapshot.entries.first.id, entry2.id);
      expect(snapshot.entries.last.id, entry1.id);
    });
  });

  // === Persistence Across Reopen ===
  group('DriftLibraryRepository (Stage 2F.1 Persistence Across Reopen)', () {
    test('persists all entities, metadata, exact multiline body, timestamps, links, and unused taxonomy across database reopen', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'drift_reopen_test_',
      );
      final dbFile = File(p.join(tempDir.path, 'prompt_library_reopen.sqlite'));

      LibraryDatabase? db1;
      LibraryDatabase? db2;

      try {
        final t0 = DateTime.utc(2026, 8, 24, 10, 0, 0);
        final t1 = DateTime.utc(2026, 8, 24, 10, 15, 0);
        final t2 = DateTime.utc(2026, 8, 24, 10, 30, 0);
        final tCopy = DateTime.utc(2026, 8, 24, 11, 0, 0);

        var currentUuid = 'id-init';
        var currentTime = t0;

        db1 = LibraryDatabase.forTesting(NativeDatabase(dbFile));
        final repo1 = DriftLibraryRepository(
          db1,
          uuidGenerator: () => currentUuid,
          clock: () => currentTime,
        );

        final emissions1 = <LibrarySnapshot>[];
        final subscription1 = repo1.watchSnapshot().listen(emissions1.add);
        await pumpEventQueue();

        currentUuid = 'cat-used-persisted';
        currentTime = t0;
        final catUsed = await repo1.createCategory(
          '  Architecture & Systems  ',
        );

        currentUuid = 'cat-unused-persisted';
        currentTime = t0;
        final catUnused = await repo1.createCategory('Draft / Staging Area');

        currentUuid = 'tag-flutter-persisted';
        currentTime = t0;
        final tagFlutter = await repo1.createTag('  Flutter Framework  ');

        currentUuid = 'tag-dart-persisted';
        currentTime = t0;
        final tagDart = await repo1.createTag('Dart Language');

        currentUuid = 'tag-unused-persisted';
        currentTime = t0;
        final tagUnused = await repo1.createTag('Zero Link Tag');

        const multilineBody =
            '# System Prompt Blueprint\n\n'
            '  - Level 1 Bullet (2 leading spaces)\n'
            '    - Level 2 Bullet (4 leading spaces)\n'
            '      - Level 3 Bullet (6 leading spaces)\n\n'
            '```dart\n'
            'void main() {\n'
            '  // Exact whitespace trailing string:\n'
            '  final message = "Hello Drift!   ";\n'
            '  print(message);\n'
            '}\n'
            '```\n\n'
            'Unicode symbols: 🚀 🎯 🔒 ⚙️ \n'
            'Special characters: \t (tab), \r\n (CRLF style text embedded), `backticks`, \\"escapes\\".\n'
            'Trailing line without newline.';

        currentUuid = 'entry-active-persisted';
        currentTime = t0;
        final entry1 = await repo1.createEntry(
          EntryInput(
            title: '  Production Blueprint Prompt  ',
            body: multilineBody,
            keyword: '  blueprint-kw  ',
            categoryId: catUsed.id,
            tagIds: [tagFlutter.id, tagDart.id],
            isFavorite: true,
            isArchived: false,
          ),
        );

        currentUuid = 'entry-archived-persisted';
        currentTime = t1;
        final entry2 = await repo1.createEntry(
          EntryInput(
            title: 'Legacy Archived Prompt',
            body: 'Simple legacy body content with whitespace   ',
            keyword: null,
            categoryId: null,
            tagIds: [tagDart.id],
            isFavorite: false,
            isArchived: false,
          ),
        );

        currentTime = t2;
        await repo1.setArchived(entry2.id, isArchived: true);

        currentTime = tCopy;
        await repo1.markCopied(entry1.id);

        await pumpEventQueue();

        await subscription1.cancel();
        await db1.close();
        db1 = null;

        db2 = LibraryDatabase.forTesting(NativeDatabase(dbFile));
        final repo2 = DriftLibraryRepository(db2);

        final snapshot = await repo2.getSnapshot();

        expect(snapshot.entries.length, 2);
        expect(snapshot.categories.length, 2);
        expect(snapshot.tags.length, 3);

        expect(snapshot.categoryById.containsKey(catUsed.id), isTrue);
        expect(snapshot.categoryById.containsKey(catUnused.id), isTrue);

        final reloadedCatUsed = snapshot.categoryById[catUsed.id]!;
        expect(reloadedCatUsed.id, 'cat-used-persisted');
        expect(reloadedCatUsed.name, 'Architecture & Systems');
        expect(reloadedCatUsed.normalizedName, 'architecture & systems');
        expect(reloadedCatUsed.sortOrder, 0);
        expect(reloadedCatUsed.createdAt, t0);
        expect(reloadedCatUsed.createdAt.isUtc, isTrue);

        final reloadedCatUnused = snapshot.categoryById[catUnused.id]!;
        expect(reloadedCatUnused.id, 'cat-unused-persisted');
        expect(reloadedCatUnused.name, 'Draft / Staging Area');
        expect(reloadedCatUnused.normalizedName, 'draft / staging area');
        expect(reloadedCatUnused.sortOrder, 1);
        expect(reloadedCatUnused.createdAt, t0);
        expect(reloadedCatUnused.createdAt.isUtc, isTrue);

        expect(snapshot.categories.map((c) => c.id).toList(), [
          catUsed.id,
          catUnused.id,
        ]);

        expect(snapshot.tagById.containsKey(tagFlutter.id), isTrue);
        expect(snapshot.tagById.containsKey(tagDart.id), isTrue);
        expect(snapshot.tagById.containsKey(tagUnused.id), isTrue);

        final reloadedTagFlutter = snapshot.tagById[tagFlutter.id]!;
        expect(reloadedTagFlutter.id, 'tag-flutter-persisted');
        expect(reloadedTagFlutter.name, 'Flutter Framework');
        expect(reloadedTagFlutter.normalizedName, 'flutter framework');
        expect(reloadedTagFlutter.createdAt, t0);
        expect(reloadedTagFlutter.createdAt.isUtc, isTrue);

        final reloadedTagDart = snapshot.tagById[tagDart.id]!;
        expect(reloadedTagDart.id, 'tag-dart-persisted');
        expect(reloadedTagDart.name, 'Dart Language');
        expect(reloadedTagDart.normalizedName, 'dart language');
        expect(reloadedTagDart.createdAt, t0);
        expect(reloadedTagDart.createdAt.isUtc, isTrue);

        final reloadedTagUnused = snapshot.tagById[tagUnused.id]!;
        expect(reloadedTagUnused.id, 'tag-unused-persisted');
        expect(reloadedTagUnused.name, 'Zero Link Tag');
        expect(reloadedTagUnused.normalizedName, 'zero link tag');
        expect(reloadedTagUnused.createdAt, t0);
        expect(reloadedTagUnused.createdAt.isUtc, isTrue);

        expect(snapshot.tags.map((t) => t.id).toList(), [
          tagDart.id,
          tagFlutter.id,
          tagUnused.id,
        ]);

        final reloadedEntry1 = snapshot.entries.firstWhere(
          (e) => e.id == 'entry-active-persisted',
        );
        expect(reloadedEntry1.id, 'entry-active-persisted');
        expect(reloadedEntry1.title, 'Production Blueprint Prompt');
        expect(reloadedEntry1.body, multilineBody);
        expect(reloadedEntry1.keyword, 'blueprint-kw');
        expect(reloadedEntry1.categoryId, catUsed.id);
        expect(reloadedEntry1.tagIds, [tagDart.id, tagFlutter.id]);
        expect(reloadedEntry1.isFavorite, isTrue);
        expect(reloadedEntry1.isArchived, isFalse);
        expect(reloadedEntry1.createdAt, t0);
        expect(reloadedEntry1.createdAt.isUtc, isTrue);
        expect(reloadedEntry1.updatedAt, t0);
        expect(reloadedEntry1.updatedAt.isUtc, isTrue);
        expect(reloadedEntry1.lastCopiedAt, tCopy);
        expect(reloadedEntry1.lastCopiedAt?.isUtc, isTrue);

        final reloadedEntry2 = snapshot.entries.firstWhere(
          (e) => e.id == 'entry-archived-persisted',
        );
        expect(reloadedEntry2.id, 'entry-archived-persisted');
        expect(reloadedEntry2.title, 'Legacy Archived Prompt');
        expect(
          reloadedEntry2.body,
          'Simple legacy body content with whitespace   ',
        );
        expect(reloadedEntry2.keyword, isNull);
        expect(reloadedEntry2.categoryId, isNull);
        expect(reloadedEntry2.tagIds, [tagDart.id]);
        expect(reloadedEntry2.isFavorite, isFalse);
        expect(reloadedEntry2.isArchived, isTrue);
        expect(reloadedEntry2.createdAt, t1);
        expect(reloadedEntry2.createdAt.isUtc, isTrue);
        expect(reloadedEntry2.updatedAt, t2);
        expect(reloadedEntry2.updatedAt.isUtc, isTrue);
        expect(reloadedEntry2.lastCopiedAt, isNull);

        expect(snapshot.entries.first.id, entry2.id);
        expect(snapshot.entries.last.id, entry1.id);

        expect(snapshot.tagsForEntry[entry1.id]?.map((t) => t.id).toList(), [
          tagDart.id,
          tagFlutter.id,
        ]);
        expect(snapshot.tagsForEntry[entry2.id]?.map((t) => t.id).toList(), [
          tagDart.id,
        ]);
        expect(snapshot.tagsForEntry['unknown-entry-id'], isNull);

        await db2.close();
        db2 = null;
      } finally {
        if (db1 != null) {
          await db1.close();
        }
        if (db2 != null) {
          await db2.close();
        }
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });
}

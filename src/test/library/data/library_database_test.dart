/// Library database tests.
library;

import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:prompt_library/src/library/data/library_database.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('LibraryDatabase', () {
    late LibraryDatabase db;

    setUp(() {
      db = LibraryDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('has schemaVersion 1', () {
      expect(db.schemaVersion, 1);
    });

    test('enables foreign_keys pragma after open', () async {
      final result = await db.customSelect('PRAGMA foreign_keys;').getSingle();
      expect(result.read<int>('foreign_keys'), 1);
    });

    test(
      'sets category_id to NULL when referenced category is deleted',
      () async {
        final now = DateTime.utc(2026, 8, 24, 12, 0, 0);

        await db
            .into(db.categories)
            .insert(
              CategoriesCompanion.insert(
                id: 'cat-1',
                name: 'Writing',
                normalizedName: 'writing',
                sortOrder: 0,
                createdAt: now,
              ),
            );

        await db
            .into(db.entries)
            .insert(
              EntriesCompanion.insert(
                id: 'entry-1',
                title: 'Grammar Checker',
                body: 'Check grammar and style in the given text.',
                categoryId: const Value('cat-1'),
                createdAt: now,
                updatedAt: now,
              ),
            );

        final entryBefore = await (db.select(
          db.entries,
        )..where((t) => t.id.equals('entry-1'))).getSingle();
        expect(entryBefore.categoryId, 'cat-1');

        await (db.delete(
          db.categories,
        )..where((t) => t.id.equals('cat-1'))).go();

        final entryAfter = await (db.select(
          db.entries,
        )..where((t) => t.id.equals('entry-1'))).getSingle();
        expect(entryAfter.categoryId, isNull);
      },
    );

    test(
      'cascades entry deletion to remove associated entry_tags rows',
      () async {
        final now = DateTime.utc(2026, 8, 24, 12, 0, 0);

        await db
            .into(db.entries)
            .insert(
              EntriesCompanion.insert(
                id: 'entry-1',
                title: 'Translator',
                body: 'Translate English to German.',
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db
            .into(db.tags)
            .insert(
              TagsCompanion.insert(
                id: 'tag-1',
                name: 'Language',
                normalizedName: 'language',
                createdAt: now,
              ),
            );

        await db
            .into(db.entryTags)
            .insert(
              EntryTagsCompanion.insert(entryId: 'entry-1', tagId: 'tag-1'),
            );

        final joinBefore = await (db.select(
          db.entryTags,
        )..where((t) => t.entryId.equals('entry-1'))).get();
        expect(joinBefore.length, 1);
        expect(joinBefore.first.entryId, 'entry-1');
        expect(joinBefore.first.tagId, 'tag-1');

        await (db.delete(
          db.entries,
        )..where((t) => t.id.equals('entry-1'))).go();

        final joinAfter = await (db.select(
          db.entryTags,
        )..where((t) => t.entryId.equals('entry-1'))).get();
        expect(joinAfter, isEmpty);

        final remainingTag = await (db.select(
          db.tags,
        )..where((t) => t.id.equals('tag-1'))).getSingleOrNull();
        expect(remainingTag, isNotNull);
        expect(remainingTag!.id, 'tag-1');
      },
    );

    test(
      'cascades tag deletion to remove associated entry_tags rows',
      () async {
        final now = DateTime.utc(2026, 8, 24, 12, 0, 0);

        await db
            .into(db.entries)
            .insert(
              EntriesCompanion.insert(
                id: 'entry-1',
                title: 'Code Refactor',
                body: 'Refactor dart code for performance.',
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db
            .into(db.tags)
            .insert(
              TagsCompanion.insert(
                id: 'tag-1',
                name: 'Flutter',
                normalizedName: 'flutter',
                createdAt: now,
              ),
            );

        await db
            .into(db.entryTags)
            .insert(
              EntryTagsCompanion.insert(entryId: 'entry-1', tagId: 'tag-1'),
            );

        final joinBefore = await (db.select(
          db.entryTags,
        )..where((t) => t.tagId.equals('tag-1'))).get();
        expect(joinBefore.length, 1);

        await (db.delete(db.tags)..where((t) => t.id.equals('tag-1'))).go();

        final joinAfter = await (db.select(
          db.entryTags,
        )..where((t) => t.tagId.equals('tag-1'))).get();
        expect(joinAfter, isEmpty);

        final remainingEntry = await (db.select(
          db.entries,
        )..where((t) => t.id.equals('entry-1'))).getSingleOrNull();
        expect(remainingEntry, isNotNull);
        expect(remainingEntry!.id, 'entry-1');
      },
    );

    test('enforces composite primary key uniqueness on entry_tags', () async {
      final now = DateTime.utc(2026, 8, 24, 12, 0, 0);

      await db
          .into(db.entries)
          .insert(
            EntriesCompanion.insert(
              id: 'entry-1',
              title: 'Prompt Title',
              body: 'Prompt Body Content',
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db
          .into(db.tags)
          .insert(
            TagsCompanion.insert(
              id: 'tag-1',
              name: 'Dart',
              normalizedName: 'dart',
              createdAt: now,
            ),
          );

      await db
          .into(db.entryTags)
          .insert(
            EntryTagsCompanion.insert(entryId: 'entry-1', tagId: 'tag-1'),
          );

      expect(
        () => db
            .into(db.entryTags)
            .insert(
              EntryTagsCompanion.insert(entryId: 'entry-1', tagId: 'tag-1'),
            ),
        throwsA(isA<SqliteException>()),
      );
    });

    test(
      'persists to temporary on-disk file and closes before directory deletion',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'prompt_library_db_test_',
        );
        final dbFile = File(p.join(tempDir.path, 'on_disk_test.sqlite'));
        final diskDb = LibraryDatabase.forTesting(NativeDatabase(dbFile));

        try {
          final now = DateTime.utc(2026, 8, 24, 12, 0, 0);
          await diskDb
              .into(diskDb.categories)
              .insert(
                CategoriesCompanion.insert(
                  id: 'disk-cat-1',
                  name: 'Disk Category',
                  normalizedName: 'disk category',
                  sortOrder: 0,
                  createdAt: now,
                ),
              );

          final inserted = await (diskDb.select(
            diskDb.categories,
          )..where((t) => t.id.equals('disk-cat-1'))).getSingle();
          expect(inserted.name, 'Disk Category');
        } finally {
          await diskDb.close();
        }

        expect(dbFile.existsSync(), isTrue);
        await tempDir.delete(recursive: true);
        expect(tempDir.existsSync(), isFalse);
      },
    );
  });
}

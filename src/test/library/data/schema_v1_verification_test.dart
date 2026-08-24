/// Schema v1 verification tests.
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/library/data/library_database.dart';

import '../../generated_migrations/schema.dart';
import '../../generated_migrations/schema_v1.dart' as v1;

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Schema V1 Verification', () {
    test(
      'verifies schema v1 against LibraryDatabase using SchemaVerifier',
      () async {
        final verifier = SchemaVerifier(GeneratedHelper());
        final connection = await verifier.startAt(1);
        final db = LibraryDatabase.forTesting(connection);

        await verifier.migrateAndValidate(db, 1);
        await db.close();
      },
    );

    test(
      'validates database schema structure self-consistency via VerifySelf',
      () async {
        final db = LibraryDatabase.forTesting(NativeDatabase.memory());

        await db.validateDatabaseSchema();
        await db.close();
      },
    );

    test('opens schema v1 snapshot and interacts with all tables using literal data', () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final schema = await verifier.schemaAt(1);
      final db = LibraryDatabase.forTesting(schema.newConnection());

      final now = DateTime.utc(2026, 8, 24, 12, 0, 0);

      await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(
              id: 'v1-cat-1',
              name: 'Productivity',
              normalizedName: 'productivity',
              sortOrder: 0,
              createdAt: now,
            ),
          );

      await db
          .into(db.tags)
          .insert(
            TagsCompanion.insert(
              id: 'v1-tag-1',
              name: 'Work',
              normalizedName: 'work',
              createdAt: now,
            ),
          );

      await db
          .into(db.entries)
          .insert(
            EntriesCompanion.insert(
              id: 'v1-entry-1',
              title: 'Daily Standup',
              body: 'Format for daily asynchronous standup message.',
              categoryId: const Value('v1-cat-1'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db
          .into(db.entryTags)
          .insert(
            EntryTagsCompanion.insert(entryId: 'v1-entry-1', tagId: 'v1-tag-1'),
          );

      final categories = await db.select(db.categories).get();
      final entries = await db.select(db.entries).get();
      final tags = await db.select(db.tags).get();
      final entryTags = await db.select(db.entryTags).get();

      expect(categories.length, 1);
      expect(categories.first.id, 'v1-cat-1');
      expect(categories.first.name, 'Productivity');
      expect(categories.first.normalizedName, 'productivity');
      expect(categories.first.sortOrder, 0);
      expect(categories.first.createdAt.toUtc(), now);

      expect(tags.length, 1);
      expect(tags.first.id, 'v1-tag-1');
      expect(tags.first.name, 'Work');
      expect(tags.first.normalizedName, 'work');
      expect(tags.first.createdAt.toUtc(), now);

      expect(entries.length, 1);
      expect(entries.first.id, 'v1-entry-1');
      expect(entries.first.title, 'Daily Standup');
      expect(
        entries.first.body,
        'Format for daily asynchronous standup message.',
      );
      expect(entries.first.categoryId, 'v1-cat-1');
      expect(entries.first.isFavorite, isFalse);
      expect(entries.first.isArchived, isFalse);
      expect(entries.first.createdAt.toUtc(), now);
      expect(entries.first.updatedAt.toUtc(), now);
      expect(entries.first.lastCopiedAt, isNull);

      expect(entryTags.length, 1);
      expect(entryTags.first.entryId, 'v1-entry-1');
      expect(entryTags.first.tagId, 'v1-tag-1');

      await db.close();
    });

    test(
      'instantiates generated DatabaseAtV1 and validates entity metadata',
      () async {
        final verifier = SchemaVerifier(GeneratedHelper());
        final schema = await verifier.schemaAt(1);
        final v1Db = v1.DatabaseAtV1(schema.newConnection());

        expect(v1Db.schemaVersion, 1);
        expect(v1Db.allTables.map((t) => t.actualTableName).toSet(), {
          'categories',
          'entries',
          'tags',
          'entry_tags',
        });

        await v1Db.close();
      },
    );
  });
}

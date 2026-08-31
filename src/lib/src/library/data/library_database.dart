/// Local database schema.
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'library_database.g.dart';

/// Entries database table.
class Entries extends Table {
  /// Primary key column.
  TextColumn get id => text()();

  /// Title column.
  TextColumn get title => text()();

  /// Body column.
  TextColumn get body => text()();

  /// Keyword column.
  TextColumn get keyword => text().nullable()();

  /// Category foreign key column.
  TextColumn get categoryId => text().nullable().references(
    Categories,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// Favorite flag column.
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();

  /// Archived flag column.
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  /// Creation timestamp column.
  DateTimeColumn get createdAt => dateTime()();

  /// Update timestamp column.
  DateTimeColumn get updatedAt => dateTime()();

  /// Copied timestamp column.
  DateTimeColumn get lastCopiedAt => dateTime().nullable()();

  /// Primary key constraint.
  @override
  Set<Column> get primaryKey => {id};
}

/// Categories database table.
class Categories extends Table {
  /// Primary key column.
  TextColumn get id => text()();

  /// Category name column.
  TextColumn get name => text()();

  /// Normalized name column.
  TextColumn get normalizedName => text().unique()();

  /// Sort order column.
  IntColumn get sortOrder => integer()();

  /// Creation timestamp column.
  DateTimeColumn get createdAt => dateTime()();

  /// Primary key constraint.
  @override
  Set<Column> get primaryKey => {id};
}

/// Tags database table.
class Tags extends Table {
  /// Primary key column.
  TextColumn get id => text()();

  /// Tag name column.
  TextColumn get name => text()();

  /// Normalized name column.
  TextColumn get normalizedName => text().unique()();

  /// Creation timestamp column.
  DateTimeColumn get createdAt => dateTime()();

  /// Primary key constraint.
  @override
  Set<Column> get primaryKey => {id};
}

/// Entry tag join table.
class EntryTags extends Table {
  /// Entry foreign key column.
  TextColumn get entryId =>
      text().references(Entries, #id, onDelete: KeyAction.cascade)();

  /// Tag foreign key column.
  TextColumn get tagId =>
      text().references(Tags, #id, onDelete: KeyAction.cascade)();

  /// Primary key constraint.
  @override
  Set<Column> get primaryKey => {entryId, tagId};
}

/// Drift library database.
@DriftDatabase(tables: [Entries, Categories, Tags, EntryTags])
class LibraryDatabase extends _$LibraryDatabase {
  /// Creates database instance.
  LibraryDatabase() : super(_openConnection());

  /// Creates testing database.
  LibraryDatabase.forTesting(super.executor);

  /// Database schema version.
  @override
  int get schemaVersion => 1;

  /// Database migration strategy.
  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON;');
      },
    );
  }
}

/// Opens database connection.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationSupportDirectory();
    await dbFolder.create(recursive: true);
    final file = File(p.join(dbFolder.path, 'prompt_library.sqlite'));
    return NativeDatabase(file);
  });
}

/// MCP diagnostic composition tests.
library;

import 'dart:convert' show utf8;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/app/application_surface.dart';
import 'package:prompt_library/src/app/mcp_diagnostic_composition.dart';
import 'package:prompt_library/src/library/data/library_database.dart';
import 'package:prompt_library/src/library/models/library_failure.dart';
import 'package:prompt_library/src/library/presentation/library_document_files.dart';
import 'package:prompt_library/src/library/presentation/transfer/library_transfer_state.dart';

void main() {
  test('uses isolated synthetic data for MCP diagnostics', () async {
    final composition = await createMcpDiagnosticComposition();
    addTearDown(composition.dispose);
    expect(composition.applicationSurface, ApplicationSurface.desktop);
    final databaseInfo = await composition.database
        .customSelect('PRAGMA database_list')
        .getSingle();
    expect(databaseInfo.read<String>('file'), isEmpty);

    await pumpEventQueue();

    final snapshot = composition.controller.state.snapshot!;
    final category = snapshot.categories.single;
    final tag = snapshot.tags.single;
    final entries = {for (final entry in snapshot.entries) entry.title: entry};
    expect(snapshot.entries, hasLength(3));
    expect(entries.keys, {
      'Compact Dialog Prompt',
      'Long Diagnostic Prompt',
      'Short Diagnostic Prompt',
    });

    final longEntry = entries['Long Diagnostic Prompt']!;
    final longLines = longEntry.body.split('\n');
    expect(longLines, hasLength(48));
    expect(longLines.first, 'Synthetic diagnostic line 1.');
    expect(longLines[23], 'Synthetic diagnostic line 24.');
    expect(longLines.last, 'Synthetic diagnostic line 48.');
    expect(longEntry.keyword, 'long-diagnostic');
    expect(longEntry.categoryId, category.id);
    expect(longEntry.tagIds, [tag.id]);
    expect(longEntry.isFavorite, isTrue);
    expect(longEntry.isArchived, isFalse);

    final shortEntry = entries['Short Diagnostic Prompt']!;
    expect(shortEntry.body, 'Synthetic short body.');
    expect(shortEntry.keyword, 'short-diagnostic');
    expect(shortEntry.categoryId, category.id);
    expect(shortEntry.tagIds, [tag.id]);
    expect(shortEntry.isFavorite, isFalse);
    expect(shortEntry.isArchived, isFalse);

    final compactEntry = entries['Compact Dialog Prompt']!;
    expect(compactEntry.body, '  Synthetic body with preserved spacing.  ');
    expect(compactEntry.keyword, 'compact-diagnostic');
    expect(compactEntry.categoryId, category.id);
    expect(compactEntry.tagIds, [tag.id]);
    expect(compactEntry.isFavorite, isFalse);
    expect(compactEntry.isArchived, isFalse);
    expect(category.name, 'MCP Category');
    expect(tag.name, 'MCP Tag');
  });

  test('diagnostic graph owns the transfer over the same database', () async {
    final composition = await createMcpDiagnosticComposition();
    addTearDown(composition.dispose);
    final transfer = composition.transferController;

    await transfer.prepareExport(DocumentExportKind.json);

    expect(transfer.state, isA<LibraryTransferExportReady>());
    final exported = utf8.decode(transfer.preparedBytes!);
    expect(
      exported,
      contains('Long Diagnostic Prompt'),
      reason: 'the diagnostic transfer owner reads the synthetic library',
    );
  });

  test('closing the diagnostic composition runs the transfer step', () async {
    final composition = await createMcpDiagnosticComposition();

    await composition.dispose();

    expect(
      () => composition.transferController.cancel(),
      throwsStateError,
      reason: 'the composition teardown closed the transfer owner',
    );
  });

  test('closes the database when synthetic seeding fails', () async {
    final database = LibraryDatabase.forTesting(NativeDatabase.memory());
    await _installSeedFailure(database);

    await expectLater(
      createMcpDiagnosticComposition(database: database),
      throwsA(
        predicate<Object>(
          (error) =>
              error is DatabaseFailureLibraryFailure &&
              error.code == LibraryDatabaseFailureCode.constraintViolation,
        ),
      ),
    );
    await expectLater(
      database.customSelect('SELECT 1').get(),
      throwsStateError,
    );
  });

  test('preserves the seed error when database close also fails', () async {
    final database = _CloseFailingDatabase();
    await _installSeedFailure(database);

    await expectLater(
      createMcpDiagnosticComposition(database: database),
      throwsA(
        predicate<Object>(
          (error) =>
              error is DatabaseFailureLibraryFailure &&
              error.code == LibraryDatabaseFailureCode.constraintViolation,
        ),
      ),
    );
    expect(database.closeCalls, 1);
  });
}

Future<void> _installSeedFailure(LibraryDatabase database) async {
  await database.customSelect('SELECT 1').get();
  await database.customStatement('''
    CREATE TRIGGER fail_synthetic_seed
    BEFORE INSERT ON entries
    WHEN NEW.title = 'Short Diagnostic Prompt'
    BEGIN
      SELECT RAISE(FAIL, 'synthetic seed failure');
    END;
  ''');
}

final class _CloseFailingDatabase extends LibraryDatabase {
  _CloseFailingDatabase() : super.forTesting(NativeDatabase.memory());

  int closeCalls = 0;

  @override
  Future<void> close() async {
    closeCalls++;
    await super.close();
    throw StateError('database close failure');
  }
}

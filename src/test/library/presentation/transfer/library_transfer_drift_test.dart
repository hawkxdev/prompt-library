/// Transfer controller tests over the real Drift repository.
library;

import 'dart:async';
import 'dart:convert';

import 'package:prompt_library/src/library/presentation/library_clipboard.dart';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/library/data/drift_library_repository.dart';
import 'package:prompt_library/src/library/data/library_database.dart';
import 'package:prompt_library/src/library/models/entry_input.dart';
import 'package:prompt_library/src/library/models/library_snapshot.dart';
import 'package:prompt_library/src/library/presentation/library_controller.dart';
import 'package:prompt_library/src/library/presentation/library_document_files.dart';
import 'package:prompt_library/src/library/presentation/transfer/library_transfer_controller.dart';
import 'package:prompt_library/src/library/presentation/transfer/library_transfer_state.dart';
import 'package:prompt_library/src/library/transfer/library_document.dart';
import 'package:prompt_library/src/library/transfer/library_json_codec.dart';
import 'package:prompt_library/src/library/transfer/library_transfer_plan.dart';

import '../../../support/library_test_support.dart';

void main() {
  late LibraryDatabase database;
  late DriftLibraryRepository repository;
  late LibraryController library;
  late TestDocumentFiles files;
  late LibraryTransferController transfer;

  setUp(() async {
    database = LibraryDatabase.forTesting(NativeDatabase.memory());
    repository = DriftLibraryRepository(
      database,
      clock: () => DateTime.utc(2026, 9, 13, 12),
    );
    library = LibraryController(repository: repository);
    files = TestDocumentFiles();
    transfer = LibraryTransferController(
      repository: repository,
      library: library,
      files: files,
      now: () => DateTime.utc(2026, 9, 13, 12),
    );
    await repository.createEntry(
      EntryInput.validate(title: 'Kept', body: 'Kept body'),
    );
    await pumpEventQueue();
  });

  tearDown(() async {
    await transfer.dispose();
    await library.dispose();
    await database.close();
  });

  /// Saves and re-reads the backup of the current Drift snapshot.
  Future<void> verifyBackup() async {
    await transfer.continueFromReview();
    expect(transfer.state, isA<LibraryTransferBackupRequired>());
    files.exportResult = const DocumentSaved(path: '/tmp/backup.json');
    await transfer.createBackupCopy();
    files.pickResult = DocumentPicked(
      fileName: 'backup.json',
      bytes: LibraryJsonCodec().encode(
        LibraryDocument(
          snapshot: await repository.getSnapshot(),
          exportedAt: DateTime.utc(2026),
        ),
      ),
    );
    await transfer.verifyBackupCopy();
    expect(transfer.state, isA<LibraryTransferBackupVerified>());
  }

  test('restores a document through review, verified copy and apply', () async {
    final current = await repository.getSnapshot();
    final incoming = LibrarySnapshot(
      entries: [
        ...current.entries,
        testEntry('incoming-1', title: 'Incoming', body: 'Incoming body'),
      ],
    );
    files.pickResult = DocumentPicked(
      fileName: 'library.json',
      bytes: LibraryJsonCodec().encode(
        LibraryDocument(snapshot: incoming, exportedAt: DateTime.utc(2026, 9)),
      ),
    );

    // Every Drift read builds a new snapshot object, so the review is
    // confirmed only through the full snapshot comparison.
    await transfer.startImport();
    await transfer.settled;
    expect(transfer.state, isA<LibraryTransferRestoreReview>());

    await verifyBackup();
    await transfer.apply();

    expect(transfer.state, isA<LibraryTransferRestoreDone>());
    expect(await repository.getSnapshot(), incoming);
    expect(library.state.isUnderMaintenance, isFalse);
  });

  test('imports a selected Raycast row with its verbatim keyword', () async {
    files.pickResult = DocumentPicked(
      fileName: 'snippets.json',
      bytes: utf8.encode(
        '[{"name":"Alpha","text":"Body A","keyword":"  al  "},'
        '{"name":"Beta","text":"Body B"}]',
      ),
    );

    await transfer.startImport();
    await transfer.settled;
    expect(transfer.state, isA<LibraryTransferRaycastReview>());
    await transfer.updateSelection(RaycastSelection(excludedIndices: {1}));
    await transfer.settled;

    await verifyBackup();
    await transfer.apply();

    final done = transfer.state as LibraryTransferImportDone;
    expect(done.outcomeCounts[ImportRowOutcome.selected], 1);
    expect(done.outcomeCounts[ImportRowOutcome.userSkipped], 1);
    final entries = (await repository.getSnapshot()).entries;
    expect(entries.map((entry) => entry.title).toSet(), {'Kept', 'Alpha'});
    expect(
      entries.singleWhere((entry) => entry.title == 'Alpha').keyword,
      '  al  ',
    );
  });

  test(
    'a held copy cycle goes stale on Drift and applies after a new review',
    () async {
      final current = await repository.getSnapshot();
      final incoming = LibrarySnapshot(
        entries: [
          ...current.entries,
          testEntry('incoming-1', title: 'Incoming', body: 'Incoming body'),
        ],
      );
      files.pickResult = DocumentPicked(
        fileName: 'library.json',
        bytes: LibraryJsonCodec().encode(
          LibraryDocument(
            snapshot: incoming,
            exportedAt: DateTime.utc(2026, 9),
          ),
        ),
      );
      await transfer.startImport();
      await transfer.settled;
      expect(transfer.state, isA<LibraryTransferRestoreReview>());
      await verifyBackup();

      final gate = Completer<void>();
      final cycleClipboard = _HoldClipboard(gate);
      final entry = (await repository.getSnapshot()).entries.single;
      final copied = copyLibraryEntry(
        entry: entry,
        clipboard: cycleClipboard,
        controller: library,
      );
      await pumpEventQueue();
      expect(cycleClipboard.writes, isNotEmpty);

      final applied = transfer.apply();
      await pumpEventQueue();
      expect(library.state.isUnderMaintenance, isTrue);
      expect(transfer.state, isA<LibraryTransferApplying>());

      gate.complete();
      expect(await copied, LibraryCopyOutcome.copied);
      await applied;

      expect(transfer.state, isA<LibraryTransferStale>());
      expect(library.state.isUnderMaintenance, isFalse);
      final after = await repository.getSnapshot();
      expect(after.entries.single.id, entry.id);
      expect(after.entries.single.lastCopiedAt, isNotNull);

      transfer.cancel();
      files.pickResult = DocumentPicked(
        fileName: 'library.json',
        bytes: LibraryJsonCodec().encode(
          LibraryDocument(
            snapshot: incoming,
            exportedAt: DateTime.utc(2026, 9),
          ),
        ),
      );
      await transfer.startImport();
      await transfer.settled;
      expect(transfer.state, isA<LibraryTransferRestoreReview>());
      await verifyBackup();
      await transfer.apply();
      expect(transfer.state, isA<LibraryTransferRestoreDone>());
      expect(await repository.getSnapshot(), incoming);
    },
  );
}

/// Clipboard fake holding the cycle write until released.
final class _HoldClipboard implements LibraryClipboard {
  _HoldClipboard(this._gate);

  final Completer<void> _gate;

  /// Recorded clipboard writes.
  final List<String> writes = [];

  @override
  Future<void> writeText(String text) async {
    writes.add(text);
    await _gate.future;
  }
}

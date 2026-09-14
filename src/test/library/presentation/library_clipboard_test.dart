/// Shared copy cycle tests.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/library/models/library_failure.dart';
import 'package:prompt_library/src/library/models/library_snapshot.dart';
import 'package:prompt_library/src/library/presentation/library_clipboard.dart';
import 'package:prompt_library/src/library/presentation/library_controller.dart';

import '../../support/library_test_support.dart';

void main() {
  late TestLibraryRepository repository;
  late LibraryController controller;
  late _GateClipboard clipboard;

  setUp(() {
    repository = TestLibraryRepository();
    controller = LibraryController(repository: repository);
    clipboard = _GateClipboard();
  });

  tearDown(() async {
    await controller.dispose();
    await repository.close();
  });

  test('copies the exact body, records metadata and reports copied', () async {
    final entry = testEntry('entry-1', body: 'exact body');
    repository.emit(LibrarySnapshot(entries: [entry]));

    final outcome = await copyLibraryEntry(
      entry: entry,
      clipboard: clipboard,
      controller: controller,
    );

    expect(outcome, LibraryCopyOutcome.copied);
    expect(clipboard.writes, ['exact body']);
    expect(repository.calls, ['markCopied:entry-1']);
    expect(
      controller.state.snapshot?.entries.single.lastCopiedAt,
      DateTime.utc(2026, 1, 2),
    );
  });

  test('reports not admitted and writes nothing under maintenance', () async {
    final entry = testEntry('entry-1', body: 'exact body');
    repository.emit(LibrarySnapshot(entries: [entry]));
    await controller.beginMaintenance();

    final outcome = await copyLibraryEntry(
      entry: entry,
      clipboard: clipboard,
      controller: controller,
    );

    expect(outcome, LibraryCopyOutcome.notAdmitted);
    expect(clipboard.writes, isEmpty);
    expect(repository.calls, isEmpty);

    controller.endMaintenance();
    expect(
      await copyLibraryEntry(
        entry: entry,
        clipboard: clipboard,
        controller: controller,
      ),
      LibraryCopyOutcome.copied,
    );
    expect(clipboard.writes, ['exact body']);
    expect(repository.calls, ['markCopied:entry-1']);
  });

  test('reports clipboard failure and skips metadata', () async {
    final entry = testEntry('entry-1');
    repository.emit(LibrarySnapshot(entries: [entry]));
    final writeGate = clipboard.blockAfterWrite(
      const LibraryClipboardFailure(),
    );

    final copied = copyLibraryEntry(
      entry: entry,
      clipboard: clipboard,
      controller: controller,
    );
    await pumpEventQueue();
    writeGate.complete();

    expect(await copied, LibraryCopyOutcome.clipboardFailure);
    expect(repository.calls, isEmpty);
  });

  test('releases the admission when the buffer fails typed', () async {
    final entry = testEntry('entry-1');
    repository.emit(LibrarySnapshot(entries: [entry]));
    final writeGate = clipboard.blockAfterWrite(
      const LibraryClipboardFailure(),
    );

    final copied = copyLibraryEntry(
      entry: entry,
      clipboard: clipboard,
      controller: controller,
    );
    await pumpEventQueue();
    final barrier = controller.beginMaintenance();
    var resolved = false;
    unawaited(barrier.then((_) => resolved = true));

    writeGate.complete();
    expect(await copied, LibraryCopyOutcome.clipboardFailure);
    await barrier;
    expect(resolved, isTrue);
  });

  test('releases the admission when the buffer fails unexpectedly', () async {
    final entry = testEntry('entry-1');
    repository.emit(LibrarySnapshot(entries: [entry]));
    final error = StateError('clipboard adapter failed');
    final writeGate = clipboard.blockAfterWrite(error);

    final copied = copyLibraryEntry(
      entry: entry,
      clipboard: clipboard,
      controller: controller,
    );
    await pumpEventQueue();
    final barrier = controller.beginMaintenance();
    var resolved = false;
    unawaited(barrier.then((_) => resolved = true));

    writeGate.complete();
    await expectLater(copied, throwsA(same(error)));
    await barrier;
    expect(resolved, isTrue);
    expect(repository.calls, isEmpty);
  });

  test('releases the admission when metadata fails typed', () async {
    final entry = testEntry('entry-1');
    repository.emit(LibrarySnapshot(entries: [entry]));
    repository.nextFailure = LibraryFailure.databaseFailure(
      code: LibraryDatabaseFailureCode.transactionFailed,
    );
    final metadataGate = Completer<void>();
    repository.nextMarkCopiedGate = metadataGate;

    final copied = copyLibraryEntry(
      entry: entry,
      clipboard: clipboard,
      controller: controller,
    );
    await pumpEventQueue();
    final barrier = controller.beginMaintenance();
    var resolved = false;
    unawaited(barrier.then((_) => resolved = true));

    metadataGate.complete();
    expect(await copied, LibraryCopyOutcome.copied);
    await barrier;
    expect(resolved, isTrue);
    expect(repository.calls, ['markCopied:entry-1']);
  });
}

/// Fake clipboard holding the write and raising a failure on release.
final class _GateClipboard implements LibraryClipboard {
  /// Recorded clipboard writes.
  final List<String> writes = [];

  Completer<void>? _gate;
  Object? _errorOnRelease;

  /// Holds the next write and raises [error] after the gate completes.
  Completer<void> blockAfterWrite(Object error) {
    _gate = Completer<void>();
    _errorOnRelease = error;
    return _gate!;
  }

  @override
  Future<void> writeText(String text) async {
    writes.add(text);
    final gate = _gate;
    final error = _errorOnRelease;
    if (gate != null) {
      _gate = null;
      _errorOnRelease = null;
      await gate.future;
    }
    if (error != null) {
      throw error;
    }
  }
}

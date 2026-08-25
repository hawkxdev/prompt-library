/// Composition root tests.
library;

import 'dart:ui' show AppExitResponse;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/app/composition_root.dart';
import 'package:prompt_library/src/library/data/drift_library_repository.dart';
import 'package:prompt_library/src/library/data/library_database.dart';
import 'package:prompt_library/src/library/models/entry_input.dart';
import 'package:prompt_library/src/library/presentation/library_clipboard.dart';
import 'package:prompt_library/src/library/presentation/library_controller.dart';

void main() {
  test('wires real Drift and disposes controller before database', () async {
    final database = LibraryDatabase.forTesting(NativeDatabase.memory());
    final repository = DriftLibraryRepository(database);
    final controller = LibraryController(repository: repository);
    final composition = PromptLibraryComposition(
      database: database,
      repository: repository,
      controller: controller,
      clipboard: const _NoopClipboard(),
    );

    await controller.createEntry(
      EntryInput.validate(title: 'Title', body: 'Body'),
    );
    await pumpEventQueue();
    expect(controller.state.snapshot?.entries.single.title, 'Title');

    final first = composition.dispose();
    final second = composition.dispose();
    expect(identical(first, second), isTrue);
    await first;

    expect(() => controller.updateSearchQuery('query'), throwsStateError);
    await expectLater(
      database.customSelect('SELECT 1').get(),
      throwsStateError,
    );
  });

  test('does not dispose while voting on an exit request', () async {
    var disposeCalls = 0;
    final lifecycle = PromptLibraryLifecycle(() async {
      disposeCalls++;
    });

    expect(await lifecycle.requestExit(), AppExitResponse.exit);
    expect(disposeCalls, 0);

    lifecycle.release();
    await pumpEventQueue();
    expect(disposeCalls, 1);
  });
}

final class _NoopClipboard implements LibraryClipboard {
  const _NoopClipboard();

  @override
  Future<void> writeText(String text) async {}
}

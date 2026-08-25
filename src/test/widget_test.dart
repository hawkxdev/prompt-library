/// Application surface contract.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/app/prompt_library_app.dart';
import 'package:prompt_library/src/library/models/library_snapshot.dart';
import 'package:prompt_library/src/library/presentation/library_clipboard.dart';
import 'package:prompt_library/src/library/presentation/library_controller.dart';

import 'support/library_test_support.dart';

void main() {
  late TestLibraryRepository repository;
  late LibraryController controller;

  setUp(() {
    repository = TestLibraryRepository();
    controller = LibraryController(repository: repository);
  });

  tearDown(() async {
    await controller.dispose();
    await repository.close();
  });

  testWidgets('application shows actionable empty library', (tester) async {
    await tester.pumpWidget(
      PromptLibraryApp(
        controller: controller,
        clipboard: const _NoopClipboard(),
      ),
    );
    repository.emit(const LibrarySnapshot.empty());
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();

    expect(find.text('Your library is empty'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'New prompt'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  });
}

final class _NoopClipboard implements LibraryClipboard {
  const _NoopClipboard();

  @override
  Future<void> writeText(String text) async {}
}

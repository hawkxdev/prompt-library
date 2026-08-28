/// MCP diagnostic composition.
library;

import 'package:drift/native.dart';

import '../library/data/drift_library_repository.dart';
import '../library/data/library_database.dart';
import '../library/models/entry_input.dart';
import '../library/presentation/library_clipboard.dart';
import '../library/presentation/library_controller.dart';
import 'composition_root.dart';

/// Creates isolated diagnostic composition.
Future<PromptLibraryComposition> createMcpDiagnosticComposition({
  LibraryDatabase? database,
}) async {
  final diagnosticDatabase =
      database ?? LibraryDatabase.forTesting(NativeDatabase.memory());
  final repository = DriftLibraryRepository(diagnosticDatabase);

  try {
    final category = await repository.createCategory('MCP Category');
    final tag = await repository.createTag('MCP Tag');
    final longBody = List.generate(
      48,
      (index) => 'Synthetic diagnostic line ${index + 1}.',
    ).join('\n');

    await repository.createEntry(
      EntryInput.validate(
        title: 'Long Diagnostic Prompt',
        body: longBody,
        keyword: 'long-diagnostic',
        categoryId: category.id,
        tagIds: [tag.id],
        isFavorite: true,
      ),
    );
    await repository.createEntry(
      EntryInput.validate(
        title: 'Short Diagnostic Prompt',
        body: 'Synthetic short body.',
        keyword: 'short-diagnostic',
        categoryId: category.id,
        tagIds: [tag.id],
      ),
    );
    await repository.createEntry(
      EntryInput.validate(
        title: 'Compact Dialog Prompt',
        body: '  Synthetic body with preserved spacing.  ',
        keyword: 'compact-diagnostic',
        categoryId: category.id,
        tagIds: [tag.id],
      ),
    );

    return PromptLibraryComposition(
      database: diagnosticDatabase,
      repository: repository,
      controller: LibraryController(repository: repository),
      clipboard: FlutterLibraryClipboard(),
    );
  } catch (error, stackTrace) {
    try {
      await diagnosticDatabase.close();
    } catch (_) {
      // Preserve the seed failure as the primary diagnostic.
    }
    Error.throwWithStackTrace(error, stackTrace);
  }
}

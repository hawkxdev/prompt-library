/// MCP diagnostic composition.
library;

import 'package:drift/native.dart';

import '../library/data/drift_library_repository.dart';
import '../library/data/library_database.dart';
import '../library/models/entry_input.dart';
import '../library/presentation/library_clipboard.dart';
import '../library/presentation/library_controller.dart';
import '../library/presentation/transfer/library_transfer_controller.dart';
import '../platform/documents/file_selector_document_files.dart';
import '../platform/documents/method_channel_document_export.dart';
import 'application_surface.dart';
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

    final controller = LibraryController(repository: repository);
    final documentFiles = FileSelectorDocumentFiles(
      exportClient: MethodChannelDocumentExport().export,
    );

    return PromptLibraryComposition(
      applicationSurface: ApplicationSurface.desktop,
      database: diagnosticDatabase,
      repository: repository,
      controller: controller,
      clipboard: FlutterLibraryClipboard(),
      documentFiles: documentFiles,
      transferController: LibraryTransferController(
        repository: repository,
        library: controller,
        files: documentFiles,
      ),
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

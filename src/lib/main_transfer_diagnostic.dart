/// Transfer stage diagnostic entry point.
///
/// Debug-only acceptance surface for Stage 5: it hosts the transfer screen
/// over an isolated in-memory library with the real document boundaries, so
/// the dialog scenarios can be exercised without touching the production
/// composition or the owner's library. The entry is removed in Stage 7 when
/// the permanent access points land.
library;

import 'package:flutter/material.dart';

import 'package:prompt_library/src/app/mcp_diagnostic_composition.dart';
import 'package:prompt_library/src/app/mcp_diagnostic_mode.dart';
import 'package:prompt_library/src/library/presentation/transfer/library_transfer_controller.dart';
import 'package:prompt_library/src/library/presentation/transfer/library_transfer_screen.dart';
import 'package:prompt_library/src/platform/documents/file_selector_document_files.dart';
import 'package:prompt_library/src/platform/documents/method_channel_document_export.dart';

/// Starts the transfer acceptance surface.
void main() {
  ensureMcpDiagnosticDebugMode();
  mainTransferDiagnostic();
}

/// Boots the diagnostic composition and the transfer screen.
Future<void> mainTransferDiagnostic() async {
  WidgetsFlutterBinding.ensureInitialized();
  final composition = await createMcpDiagnosticComposition();
  final transfer = LibraryTransferController(
    repository: composition.repository,
    library: composition.controller,
    files: FileSelectorDocumentFiles(
      exportClient: MethodChannelDocumentExport().export,
    ),
  );
  runApp(
    MaterialApp(
      title: 'Transfer diagnostic',
      home: Scaffold(
        appBar: AppBar(title: const Text('Stage 5 transfer acceptance')),
        body: LibraryTransferScreen(transfer: transfer),
      ),
    ),
  );
}

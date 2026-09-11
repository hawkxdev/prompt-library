/// File-selector backed document boundary.
library;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';

import '../../library/presentation/library_document_files.dart';
import '../../library/transfer/library_document.dart';

/// Picks one input file through the system file selector.
typedef DocumentFilePicker = Future<XFile?> Function();

/// Exports prepared bytes through the native client.
typedef NativeDocumentExporter = Future<DocumentExportResult> Function({
  required DocumentExportKind kind,
  required String suggestedName,
  required Uint8List bytes,
});

/// File-selector implementation of the document boundary.
final class FileSelectorDocumentFiles implements LibraryDocumentFiles {
  /// Native export client; null keeps the export unavailable.
  final NativeDocumentExporter? exportClient;

  /// Creates the boundary with optional seams for tests.
  FileSelectorDocumentFiles({
    DocumentLimits? limits,
    DocumentFilePicker? pickFile,
    this.exportClient,
  }) : _limits = limits ?? DocumentLimits(),
       _pickFile = pickFile ?? _openWithFileSelector;

  final DocumentLimits _limits;
  final DocumentFilePicker _pickFile;

  static Future<XFile?> _openWithFileSelector() {
    const group = XTypeGroup(
      label: 'JSON document',
      extensions: <String>['json'],
      mimeTypes: <String>['application/json'],
      uniformTypeIdentifiers: <String>['public.json'],
    );
    return openFile(acceptedTypeGroups: <XTypeGroup>[group]);
  }

  @override
  Future<DocumentPickResult> pickDocument() async {
    final XFile? file;
    try {
      file = await _pickFile();
    } on MissingPluginException {
      return const DocumentPickUnavailable();
    } on Object {
      return const DocumentPickFailure(
        code: DocumentFileFailureCode.readFailed,
      );
    }
    if (file == null) {
      return const DocumentPickCancelled();
    }
    return _readBounded(file);
  }

  Future<DocumentPickResult> _readBounded(XFile file) async {
    try {
      final length = await file.length();
      if (length > _limits.maxBytes) {
        return const DocumentPickFailure(
          code: DocumentFileFailureCode.limitExceeded,
        );
      }
      final sink = DocumentByteSink(_limits);
      await for (final chunk in file.openRead()) {
        sink.add(chunk);
      }
      return DocumentPicked(fileName: file.name, bytes: sink.takeBytes());
    } on DocumentFailure {
      return const DocumentPickFailure(
        code: DocumentFileFailureCode.limitExceeded,
      );
    } on Object {
      return const DocumentPickFailure(
        code: DocumentFileFailureCode.readFailed,
      );
    }
  }

  @override
  Future<DocumentExportResult> exportDocument({
    required DocumentExportKind kind,
    required String suggestedName,
    required Uint8List bytes,
  }) {
    final export = exportClient;
    if (export == null) {
      return Future.value(const DocumentExportUnavailable());
    }
    return export(kind: kind, suggestedName: suggestedName, bytes: bytes);
  }
}

/// Method-channel client for native document export.
library;

import 'dart:io';

import 'package:flutter/services.dart';

import '../../library/presentation/library_document_files.dart';

/// Outbound client of the native macOS export channel.
final class MethodChannelDocumentExport {
  /// Creates the client with optional seams for tests.
  MethodChannelDocumentExport({BinaryMessenger? messenger, bool? supported})
    : _supported = supported ?? Platform.isMacOS,
      _channel = MethodChannel(
        MethodChannelDocumentExport.channelName,
        const StandardMethodCodec(),
        messenger,
      );

  /// Wire channel name shared with the Swift host.
  static const String channelName = 'dev.hawkx.promptlibrary/document_export';

  final MethodChannel _channel;
  final bool _supported;

  /// Exports bytes through the native save flow.
  Future<DocumentExportResult> export({
    required DocumentExportKind kind,
    required String suggestedName,
    required Uint8List bytes,
  }) async {
    final name = suggestedName.trim();
    if (name.isEmpty || name.contains('/') || name.contains(':')) {
      return const DocumentExportFailure(
        code: DocumentFileFailureCode.invalidArguments,
      );
    }
    if (!_supported) {
      return const DocumentExportUnavailable();
    }
    final Object? reply;
    try {
      reply = await _channel.invokeMethod<Object>('exportDocument', {
        'name': name,
        'kind': kind.name,
        'bytes': bytes,
      });
    } on MissingPluginException {
      return const DocumentExportUnavailable();
    } on PlatformException {
      return const DocumentExportFailure(
        code: DocumentFileFailureCode.writeFailed,
      );
    }
    return _parse(reply);
  }

  DocumentExportResult _parse(Object? reply) {
    if (reply is! Map<Object?, Object?>) {
      return const DocumentExportFailure(
        code: DocumentFileFailureCode.unknownOutcome,
      );
    }
    final path = reply['path'];
    return switch (reply['outcome']) {
      'saved' when path is String => DocumentSaved(path: path),
      'cancelled' => const DocumentExportCancelled(),
      'existingFile' => const DocumentExportFailure(
        code: DocumentFileFailureCode.existingFile,
      ),
      'writeFailed' => const DocumentExportFailure(
        code: DocumentFileFailureCode.writeFailed,
      ),
      'verifyFailed' => const DocumentExportFailure(
        code: DocumentFileFailureCode.verifyFailed,
      ),
      'invalidArguments' => const DocumentExportFailure(
        code: DocumentFileFailureCode.invalidArguments,
      ),
      _ => const DocumentExportFailure(
        code: DocumentFileFailureCode.unknownOutcome,
      ),
    };
  }
}

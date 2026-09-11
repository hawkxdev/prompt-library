import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:prompt_library/src/library/presentation/library_document_files.dart';
import 'package:prompt_library/src/platform/documents/method_channel_document_export.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'iOS production channel validates export arguments without presenting',
    (tester) async {
      const channel = MethodChannel('dev.hawkx.promptlibrary/document_export');
      final reply = await channel.invokeMethod<Map<Object?, Object?>>(
        'exportDocument',
        {'name': 'library.json', 'kind': 'yaml', 'bytes': Uint8List(0)},
      );

      expect(reply?['outcome'], 'invalidArguments');
    },
    skip: !Platform.isIOS,
  );

  testWidgets(
    'iOS default export client reaches the native gate without a seam',
    (tester) async {
      // Mutation control for the default platform gate (plan decision D8):
      // the client is built through the default constructor, so losing the
      // `Platform.isIOS` term turns this probe red with an unavailable
      // outcome instead of the native invalidArguments reply.
      final client = MethodChannelDocumentExport();

      final result = await client.export(
        kind: DocumentExportKind.json,
        suggestedName: 'library.json',
        bytes: Uint8List(0),
      );

      // Empty bytes fail native validation before any presentation.
      expect(result, isA<DocumentExportFailure>());
      expect(
        (result as DocumentExportFailure).code,
        DocumentFileFailureCode.invalidArguments,
      );
    },
    skip: !Platform.isIOS,
  );
}

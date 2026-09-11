/// Method-channel export client tests.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/library/presentation/library_document_files.dart';
import 'package:prompt_library/src/platform/documents/method_channel_document_export.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(MethodChannelDocumentExport.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  Future<Object?>? Function(MethodCall call)? responder;

  setUp(() {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => responder?.call(call),
    );
  });

  tearDown(() {
    responder = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  Future<DocumentExportResult> send({
    bool supported = true,
    String name = 'library.json',
  }) {
    return MethodChannelDocumentExport(supported: supported).export(
      kind: DocumentExportKind.json,
      suggestedName: name,
      bytes: Uint8List.fromList([1, 2, 3]),
    );
  }

  test('parses saved outcome with the chosen path', () async {
    responder = (call) async => {'outcome': 'saved', 'path': '/tmp/l.json'};

    final result = await send();

    expect(result, const DocumentSaved(path: '/tmp/l.json'));
  });

  test('parses cancelled outcome', () async {
    responder = (call) async => {'outcome': 'cancelled'};

    expect(await send(), isA<DocumentExportCancelled>());
  });

  test('maps every typed channel outcome', () async {
    final outcomes = <String, DocumentFileFailureCode>{
      'existingFile': DocumentFileFailureCode.existingFile,
      'writeFailed': DocumentFileFailureCode.writeFailed,
      'verifyFailed': DocumentFileFailureCode.verifyFailed,
      'invalidArguments': DocumentFileFailureCode.invalidArguments,
    };
    for (final entry in outcomes.entries) {
      responder = (call) async => {'outcome': entry.key};
      expect(
        await send(),
        DocumentExportFailure(code: entry.value),
        reason: entry.key,
      );
    }
  });

  test('maps unknown and missing replies to unknownOutcome', () async {
    responder = (call) async => {'outcome': 'mystery'};

    expect(
      await send(),
      const DocumentExportFailure(code: DocumentFileFailureCode.unknownOutcome),
    );

    responder = null;
    expect(
      await send(),
      const DocumentExportFailure(code: DocumentFileFailureCode.unknownOutcome),
    );
  });

  test('maps platform errors to writeFailed', () async {
    responder = (call) => throw PlatformException(code: 'export_failed');

    expect(
      await send(),
      const DocumentExportFailure(code: DocumentFileFailureCode.writeFailed),
    );
  });

  test('maps missing plugin to unavailable', () async {
    messenger.setMockMethodCallHandler(channel, null);

    expect(await send(), isA<DocumentExportUnavailable>());
  });

  test('returns unavailable without touching the channel off macOS', () async {
    var calls = 0;
    responder = (call) async {
      calls += 1;
      return {'outcome': 'saved', 'path': '/tmp/l.json'};
    };

    final result = await send(supported: false);

    expect(calls, 0);
    expect(result, isA<DocumentExportUnavailable>());
  });

  test('rejects invalid names locally without touching the channel', () async {
    var calls = 0;
    responder = (call) async {
      calls += 1;
      return {'outcome': 'saved', 'path': '/tmp/l.json'};
    };

    for (final name in ['', '   ', 'bad/name', 'bad:name']) {
      final result = await send(name: name);
      expect(
        result,
        const DocumentExportFailure(
          code: DocumentFileFailureCode.invalidArguments,
        ),
        reason: name,
      );
    }
    expect(calls, 0);
  });
}

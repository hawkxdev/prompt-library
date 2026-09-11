/// iOS-facing contract of the method-channel export client.
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
  var calls = 0;

  setUp(() {
    calls = 0;
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => responder?.call(call),
    );
  });

  tearDown(() {
    responder = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  // Mutation control for the default platform gate (plan decision D8): the
  // host platform stays allowed through the default constructor, so a gate
  // that denies everything turns this test red. The `Platform.isIOS` term of
  // the default gate is differentiated by the iOS simulator handshake probe,
  // which builds the client through the same default constructor.
  test(
    'default constructor keeps the export gate open on the host platform',
    () async {
      responder = (call) async {
        calls += 1;
        return {'outcome': 'saved', 'path': '/tmp/l.json'};
      };

      final result = await MethodChannelDocumentExport().export(
        kind: DocumentExportKind.json,
        suggestedName: 'library.json',
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      expect(calls, 1);
      expect(result, const DocumentSaved(path: '/tmp/l.json'));
    },
  );

  test('supported client transmits trimmed name and document kind', () async {
    MethodCall? seen;
    responder = (call) async {
      seen = call;
      return {'outcome': 'saved', 'path': '/tmp/x.md'};
    };

    final result = await MethodChannelDocumentExport(supported: true).export(
      kind: DocumentExportKind.markdown,
      suggestedName: '  notes.md  ',
      bytes: Uint8List.fromList([4, 5]),
    );

    expect(result, const DocumentSaved(path: '/tmp/x.md'));
    expect(seen, isNotNull);
    expect(seen!.method, 'exportDocument');
    expect(seen!.arguments, {
      'name': 'notes.md',
      'kind': 'markdown',
      'bytes': Uint8List.fromList([4, 5]),
    });
  });
}

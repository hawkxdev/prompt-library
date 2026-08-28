import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/platform/macos/mac_quick_panel_port.dart';
import 'package:prompt_library/src/platform/macos/method_channel_mac_quick_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const name = 'dev.hawkx.promptlibrary/mac_quick_panel';
  late TestDefaultBinaryMessenger messenger;
  setUp(() {
    messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(const MethodChannel(name), null);
  });
  test('sends exact payloads and decodes full show result', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
      calls.add(call);
      if (call.method == 'showFullLibrary') {
        return {'kind': 'registered', 'diagnosticCode': 314};
      }
      return {'kind': 'registered'};
    });
    final port = MethodChannelMacQuickPanel(messenger: messenger);
    await port.registerHotKey(
      HotKeySpec(
        keyCode: 49,
        modifiers: {HotKeyModifier.option, HotKeyModifier.control},
      ),
    );
    await port.registrationState();
    await port.hideQuickMode(restoreFocus: true, generation: 7);
    final result = await port.showFullLibrary();
    expect(result.kind, MacQuickPanelResultKind.registered);
    expect(result.diagnosticCode, 314);
    expect(calls.map((c) => c.method), [
      'registerHotKey',
      'registrationState',
      'hideQuickMode',
      'showFullLibrary',
    ]);
    expect(calls[0].arguments, {
      'keyCode': 49,
      'modifiers': ['control', 'option'],
    });
    expect(calls[1].arguments, isNull);
    expect(calls[2].arguments, {'restoreFocus': true, 'generation': 7});
    expect(calls[3].arguments, isNull);
    await port.dispose();
  });
  test('decodes every literal result kind', () async {
    final channel = MethodChannel(name);
    final port = MethodChannelMacQuickPanel(messenger: messenger);
    const kinds = <String>[
      'registered',
      'collision',
      'invalidShortcut',
      'unavailable',
      'nativeFailure',
    ];
    for (var i = 0; i < kinds.length; i++) {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => {'kind': kinds[i], 'diagnosticCode': 9},
      );
      expect(
        (await port.registrationState()).kind,
        MacQuickPanelResultKind.values[i],
      );
    }
    await port.dispose();
  });
  test(
    'delivers request, closes stream, and rejects unknown callback',
    () async {
      final port = MethodChannelMacQuickPanel(messenger: messenger);
      var quickEvents = 0;
      var fullEvents = 0;
      var quickDone = false;
      var fullDone = false;
      port.quickModeRequests.listen(
        (_) => quickEvents++,
        onDone: () => quickDone = true,
      );
      port.fullLibraryRequests.listen(
        (_) => fullEvents++,
        onDone: () => fullDone = true,
      );
      await messenger.handlePlatformMessage(
        name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('quickModeRequested', {'generation': 1}),
        ),
        (_) {},
      );
      expect(quickEvents, 1);
      await messenger.handlePlatformMessage(
        name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('fullLibraryRequested', {'generation': 2}),
        ),
        (_) {},
      );
      expect(fullEvents, 1);
      await messenger.handlePlatformMessage(
        name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('unknown'),
        ),
        (data) => expect(data, isNull),
      );
      await port.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(quickDone, isTrue);
      expect(fullDone, isTrue);
      expect(quickEvents, 1);
      expect(fullEvents, 1);
    },
  );
  test('post-disposal callback has no installed handler response', () async {
    final port = MethodChannelMacQuickPanel(messenger: messenger);
    await port.dispose();
    var response = 'unset';
    await messenger.handlePlatformMessage(
      name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('quickModeRequested', {'generation': 3}),
      ),
      (data) => response = '$data',
    );
    expect(response, 'null');
  });
  test('missing native handler maps to unavailable', () async {
    messenger.setMockMethodCallHandler(const MethodChannel(name), null);
    final port = MethodChannelMacQuickPanel(messenger: messenger);

    expect(
      (await port.registrationState()).kind,
      MacQuickPanelResultKind.unavailable,
    );

    await port.dispose();
  });

  test('malformed results throw FormatException', () async {
    final port = MethodChannelMacQuickPanel(messenger: messenger);
    messenger.setMockMethodCallHandler(
      MethodChannel(name),
      (_) async => {'kind': 'bogus'},
    );
    expect(port.registrationState, throwsFormatException);
    messenger.setMockMethodCallHandler(
      MethodChannel(name),
      (_) async => {'kind': 'registered'},
    );
    await port.dispose();
  });
  test(
    'dispose is idempotent and post-disposal calls avoid messenger',
    () async {
      final methods = <String>[];
      messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
        methods.add(call.method);
        return {'kind': 'registered'};
      });
      final port = MethodChannelMacQuickPanel(messenger: messenger);
      await port.dispose();
      await port.dispose();
      expect(
        (await port.showFullLibrary()).kind,
        MacQuickPanelResultKind.unavailable,
      );
      expect(methods, ['unregisterHotKey']);
    },
  );
}

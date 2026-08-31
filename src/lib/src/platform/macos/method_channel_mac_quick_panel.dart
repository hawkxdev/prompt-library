import 'dart:async';

import 'package:flutter/services.dart';

import 'mac_quick_panel_port.dart';

/// BinaryMessenger adapter for the macOS quick-panel capability.
class MethodChannelMacQuickPanel implements MacQuickPanelPort {
  MethodChannelMacQuickPanel({BinaryMessenger? messenger})
    : _channel = MethodChannel(
        _channelName,
        const StandardMethodCodec(),
        messenger,
      ) {
    _channel.setMethodCallHandler(_handleCall);
  }
  static const _channelName = 'dev.hawkx.promptlibrary/mac_quick_panel';
  final MethodChannel _channel;
  final StreamController<int> _quickRequests =
      StreamController<int>.broadcast();
  final StreamController<int> _fullRequests = StreamController<int>.broadcast();
  bool _disposed = false;

  @override
  Stream<int> get quickModeRequests => _quickRequests.stream;

  @override
  Stream<int> get fullLibraryRequests => _fullRequests.stream;

  Future<void> _handleCall(MethodCall call) async {
    if (_disposed) {
      return;
    }
    switch (call.method) {
      case 'quickModeRequested':
        _quickRequests.add(_decodeGeneration(call.arguments));
      case 'fullLibraryRequested':
        _fullRequests.add(_decodeGeneration(call.arguments));
      default:
        throw MissingPluginException('Unknown method: ${call.method}');
    }
  }

  int _decodeGeneration(Object? value) {
    if (value case {'generation': final int generation}) {
      return generation;
    }
    throw const FormatException('Host event requires an integer generation');
  }

  Future<MacQuickPanelResult> _invoke(
    String method, [
    Object? arguments,
  ]) async {
    if (_disposed) {
      return const MacQuickPanelResult(MacQuickPanelResultKind.unavailable);
    }
    try {
      return MacQuickPanelResult.fromMap(
        await _channel.invokeMethod<Object?>(method, arguments),
      );
    } on MissingPluginException {
      return const MacQuickPanelResult(MacQuickPanelResultKind.unavailable);
    }
  }

  @override
  Future<MacQuickPanelResult> registerHotKey(HotKeySpec spec) =>
      _invoke('registerHotKey', spec.toMap());
  @override
  Future<MacQuickPanelResult> registrationState() =>
      _invoke('registrationState');

  @override
  Future<MacQuickPanelResult> unregisterHotKey() => _invoke('unregisterHotKey');
  @override
  Future<MacQuickPanelResult> hideQuickMode({
    required bool restoreFocus,
    required int generation,
  }) => _invoke('hideQuickMode', {
    'restoreFocus': restoreFocus,
    'generation': generation,
  });
  @override
  Future<MacQuickPanelResult> showFullLibrary() => _invoke('showFullLibrary');
  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    try {
      await unregisterHotKey();
    } on MissingPluginException {
      // The host may already be detached; local teardown still must complete.
    } finally {
      _disposed = true;
      _channel.setMethodCallHandler(null);
      await _quickRequests.close();
      await _fullRequests.close();
    }
  }
}

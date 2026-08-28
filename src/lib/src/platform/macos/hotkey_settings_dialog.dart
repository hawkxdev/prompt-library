import 'dart:async';

import 'package:flutter/material.dart';

import 'mac_quick_panel_port.dart';
import 'quick_panel_controller.dart';
import 'quick_panel_state.dart';

/// Opens global-hotkey settings for the macOS quick workflow.
Future<void> showHotKeySettingsDialog(
  BuildContext context, {
  required QuickPanelController controller,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => HotKeySettingsDialog(controller: controller),
  );
}

/// Edits one key plus Command, Shift, Option, and Control modifiers.
final class HotKeySettingsDialog extends StatefulWidget {
  /// Creates the settings dialog.
  const HotKeySettingsDialog({required this.controller, super.key});

  /// Quick-panel controller receiving transactional replacement requests.
  final QuickPanelController controller;

  @override
  State<HotKeySettingsDialog> createState() => _HotKeySettingsDialogState();
}

final class _HotKeySettingsDialogState extends State<HotKeySettingsDialog> {
  late QuickPanelState _state;
  late int _keyCode;
  late Set<HotKeyModifier> _modifiers;
  late final StreamSubscription<QuickPanelState> _subscription;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _state = widget.controller.state;
    _keyCode = _state.configuredHotKey.keyCode;
    _modifiers = {..._state.configuredHotKey.modifiers};
    _subscription = widget.controller.states.listen((state) {
      if (!mounted) {
        return;
      }
      setState(() {
        _state = state;
        if (state.pendingAction != QuickPanelPendingAction.replaceHotKey) {
          _keyCode = state.configuredHotKey.keyCode;
          _modifiers = {...state.configuredHotKey.modifiers};
        }
      });
    });
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pending =
        _state.pendingAction == QuickPanelPendingAction.replaceHotKey;
    return PopScope(
      canPop: !pending,
      child: AlertDialog(
        title: const Text('Global shortcut'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<int>(
                key: ValueKey(_keyCode),
                initialValue: _keyCode,
                decoration: const InputDecoration(labelText: 'Key'),
                items: [
                  for (final choice in _hotKeyChoices)
                    DropdownMenuItem(
                      value: choice.keyCode,
                      child: Text(choice.label),
                    ),
                ],
                onChanged: pending
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _keyCode = value);
                        }
                      },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final modifier in HotKeyModifier.values)
                    FilterChip(
                      key: ValueKey('hotkey-${modifier.name}'),
                      label: Text(_modifierLabel(modifier)),
                      selected: _modifiers.contains(modifier),
                      onSelected: pending
                          ? null
                          : (selected) {
                              setState(() {
                                if (selected) {
                                  _modifiers.add(modifier);
                                } else {
                                  _modifiers.remove(modifier);
                                }
                              });
                            },
                    ),
                ],
              ),
              if (_validationMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _validationMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                _registrationMessage(_state.registration),
                key: const Key('hotkey-status'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: pending ? null : () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            key: const Key('hotkey-save'),
            onPressed: pending ? null : _save,
            child: Text(pending ? 'Registering…' : 'Save'),
          ),
        ],
      ),
    );
  }

  void _save() {
    if (_modifiers.isEmpty) {
      setState(() => _validationMessage = 'Select at least one modifier.');
      return;
    }
    setState(() => _validationMessage = null);
    unawaited(
      widget.controller.replaceHotKey(
        HotKeySpec(keyCode: _keyCode, modifiers: _modifiers),
      ),
    );
  }
}

String _modifierLabel(HotKeyModifier modifier) {
  return switch (modifier) {
    HotKeyModifier.command => 'Command',
    HotKeyModifier.shift => 'Shift',
    HotKeyModifier.option => 'Option',
    HotKeyModifier.control => 'Control',
  };
}

String _registrationMessage(MacQuickPanelResult result) {
  final message = switch (result.kind) {
    MacQuickPanelResultKind.registered => 'Shortcut registered.',
    MacQuickPanelResultKind.collision => 'That shortcut is already registered. The previous shortcut remains active.',
    MacQuickPanelResultKind.invalidShortcut =>
      'Choose a valid key and modifier combination.',
    MacQuickPanelResultKind.unavailable =>
      'Global shortcuts are unavailable on this platform.',
    MacQuickPanelResultKind.nativeFailure =>
      'The shortcut could not be registered.',
  };
  final code = result.diagnosticCode;
  return code == null ? message : '$message (code $code)';
}

final class _HotKeyChoice {
  const _HotKeyChoice(this.label, this.keyCode);

  final String label;
  final int keyCode;
}

const _hotKeyChoices = [
  _HotKeyChoice('Space', 49),
  _HotKeyChoice('A', 0),
  _HotKeyChoice('B', 11),
  _HotKeyChoice('C', 8),
  _HotKeyChoice('D', 2),
  _HotKeyChoice('E', 14),
  _HotKeyChoice('F', 3),
  _HotKeyChoice('G', 5),
  _HotKeyChoice('H', 4),
  _HotKeyChoice('I', 34),
  _HotKeyChoice('J', 38),
  _HotKeyChoice('K', 40),
  _HotKeyChoice('L', 37),
  _HotKeyChoice('M', 46),
  _HotKeyChoice('N', 45),
  _HotKeyChoice('O', 31),
  _HotKeyChoice('P', 35),
  _HotKeyChoice('Q', 12),
  _HotKeyChoice('R', 15),
  _HotKeyChoice('S', 1),
  _HotKeyChoice('T', 17),
  _HotKeyChoice('U', 32),
  _HotKeyChoice('V', 9),
  _HotKeyChoice('W', 13),
  _HotKeyChoice('X', 7),
  _HotKeyChoice('Y', 16),
  _HotKeyChoice('Z', 6),
];

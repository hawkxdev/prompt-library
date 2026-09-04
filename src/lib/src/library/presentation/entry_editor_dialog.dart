/// Entry editor dialog.
library;

import 'package:flutter/material.dart';

import '../models/entry.dart';
import 'entry_editor_form.dart';
import 'library_controller.dart';

/// Opens create or edit dialog.
Future<void> showEntryEditorDialog(
  BuildContext context, {
  required LibraryController controller,
  Entry? entry,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _EntryEditorDialog(controller: controller, entry: entry),
  );
}

/// Create or edit surface.
final class _EntryEditorDialog extends StatefulWidget {
  const _EntryEditorDialog({required this.controller, this.entry});

  final LibraryController controller;
  final Entry? entry;

  @override
  State<_EntryEditorDialog> createState() => _EntryEditorDialogState();
}

/// Owns the local draft until persistence succeeds.
final class _EntryEditorDialogState extends State<_EntryEditorDialog> {
  late final EntryEditorFormController _formController;

  /// Initializes form coordination.
  @override
  void initState() {
    super.initState();
    _formController = EntryEditorFormController.forEditor(
      controller: widget.controller,
      entry: widget.entry,
    );
  }

  /// Releases form coordination.
  @override
  void dispose() {
    _formController.dispose();
    super.dispose();
  }

  /// Resolves desktop body sizing.
  EntryEditorBodySize _bodySize(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 720;
    return EntryEditorBodySize(
      minLines: compact ? 4 : 7,
      maxLines: compact ? 8 : 14,
    );
  }

  /// Builds desktop editor shell.
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _formController,
      builder: (context, _) {
        final isSaving = _formController.isSaving;
        return AlertDialog(
          title: Text(widget.entry == null ? 'New prompt' : 'Edit prompt'),
          content: SizedBox(
            width: 620,
            child: EntryEditorForm(
              controller: widget.controller,
              formController: _formController,
              bodySizePolicy: _bodySize,
              entry: widget.entry,
              onSaved: () => Navigator.pop(context),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isSaving ? null : _formController.save,
              child: Text(isSaving ? 'Saving…' : 'Save'),
            ),
          ],
        );
      },
    );
  }
}

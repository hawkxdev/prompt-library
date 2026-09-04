/// Mobile entry editor screen.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/entry.dart';
import '../entry_editor_form.dart';
import '../library_controller.dart';

/// Full-screen mobile editor route.
final class MobileEntryEditorScreen extends StatefulWidget {
  /// Creates mobile editor route.
  const MobileEntryEditorScreen({
    required this.controller,
    this.entry,
    super.key,
  });

  /// Shared library controller.
  final LibraryController controller;

  /// Existing entry when editing.
  final Entry? entry;

  @override
  State<MobileEntryEditorScreen> createState() =>
      _MobileEntryEditorScreenState();
}

/// Owns mobile editor navigation.
final class _MobileEntryEditorScreenState
    extends State<MobileEntryEditorScreen> {
  late final EntryEditorFormController _formController;
  bool _confirmationOpen = false;
  bool _popRequested = false;
  bool _allowPop = false;

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

  /// Resolves mobile body sizing.
  EntryEditorBodySize _bodySize(BuildContext context) {
    final media = MediaQuery.of(context);
    final availableHeight =
        media.size.height -
        media.padding.vertical -
        media.viewInsets.bottom -
        kToolbarHeight;
    if (availableHeight < 300) {
      return const EntryEditorBodySize(minLines: 2, maxLines: 5);
    }
    if (availableHeight < 500) {
      return const EntryEditorBodySize(minLines: 3, maxLines: 8);
    }
    return const EntryEditorBodySize(minLines: 5, maxLines: 14);
  }

  /// Handles a completed save.
  void _handleSaved() {
    _requestPopAfterRebuild();
  }

  /// Requests cancellation.
  Future<void> _requestCancel() async {
    if (_popRequested || _formController.isSaving) return;
    if (!_formController.isDirty) {
      _requestPopAfterRebuild();
      return;
    }
    if (_confirmationOpen) return;
    _confirmationOpen = true;
    final discard = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your unsaved changes will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    _confirmationOpen = false;
    if (!mounted || discard != true) return;
    _requestPopAfterRebuild();
  }

  /// Allows and schedules one route pop.
  void _requestPopAfterRebuild() {
    if (_popRequested || !mounted) return;
    _popRequested = true;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pop();
    });
  }

  /// Handles a blocked system pop.
  void _handlePop(bool didPop, void result) {
    if (didPop || _popRequested) return;
    unawaited(_requestCancel());
  }

  /// Builds mobile editor shell.
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _formController,
      builder: (context, _) {
        final isSaving = _formController.isSaving;
        return PopScope<void>(
          canPop: _allowPop || (!isSaving && !_formController.isDirty),
          onPopInvokedWithResult: _handlePop,
          child: Scaffold(
            key: const Key('mobile-entry-editor-screen'),
            appBar: AppBar(
              leadingWidth: 92,
              leading: TextButton(
                key: const Key('mobile-editor-cancel'),
                onPressed: isSaving ? null : _requestCancel,
                child: const Text('Cancel'),
              ),
              title: Text(
                widget.entry == null ? 'New prompt' : 'Edit prompt',
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                TextButton(
                  key: const Key('mobile-editor-save'),
                  onPressed: isSaving ? null : _formController.save,
                  child: Text(isSaving ? 'Saving…' : 'Save'),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: SafeArea(
              key: const Key('mobile-editor-body'),
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: EntryEditorForm(
                  controller: widget.controller,
                  formController: _formController,
                  bodySizePolicy: _bodySize,
                  entry: widget.entry,
                  onSaved: _handleSaved,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

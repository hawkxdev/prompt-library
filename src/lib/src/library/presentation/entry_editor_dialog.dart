/// Entry editor dialog.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../models/entry.dart';
import '../models/entry_input.dart';
import '../models/library_failure.dart';
import 'library_controller.dart';
import 'library_failure_message.dart';
import 'library_state.dart';

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

final class _EntryEditorDialog extends StatefulWidget {
  const _EntryEditorDialog({required this.controller, this.entry});

  final LibraryController controller;
  final Entry? entry;

  @override
  State<_EntryEditorDialog> createState() => _EntryEditorDialogState();
}

final class _EntryEditorDialogState extends State<_EntryEditorDialog> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _keyword;
  late LibraryState _state;
  late final StreamSubscription<LibraryState> _subscription;
  String? _categoryId;
  late Set<String> _tagIds;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _title = TextEditingController(text: entry?.title ?? '');
    _body = TextEditingController(text: entry?.body ?? '');
    _keyword = TextEditingController(text: entry?.keyword ?? '');
    _categoryId = entry?.categoryId;
    _tagIds = {...?entry?.tagIds};
    _state = widget.controller.state;
    _subscription = widget.controller.states.listen((state) {
      if (mounted) setState(() => _state = state);
    });
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    _title.dispose();
    _body.dispose();
    _keyword.dispose();
    super.dispose();
  }

  LibraryMutationKey get _mutationKey {
    final entry = widget.entry;
    return entry == null
        ? const LibraryMutationKey(LibraryMutationKind.createEntry)
        : LibraryMutationKey(
            LibraryMutationKind.updateEntry,
            entityId: entry.id,
          );
  }

  Future<void> _save() async {
    if (_state.isMutationActive(_mutationKey)) return;
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }
    if (_body.text.trim().isEmpty) {
      setState(() => _error = 'Body is required.');
      return;
    }
    final existing = widget.entry;
    final input = EntryInput.validate(
      title: _title.text,
      body: _body.text,
      keyword: _keyword.text,
      categoryId: _categoryId,
      tagIds: _tagIds,
      isFavorite: existing?.isFavorite ?? false,
      isArchived: existing?.isArchived ?? false,
    );
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      if (existing == null) {
        await widget.controller.createEntry(input);
      } else {
        await widget.controller.updateEntry(existing.id, input);
      }
      if (mounted) Navigator.pop(context);
    } on LibraryFailure catch (failure) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = messageForLibraryFailure(failure);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _state.snapshot;
    final isSaving = _isSaving || _state.isMutationActive(_mutationKey);
    return AlertDialog(
      title: Text(widget.entry == null ? 'New prompt' : 'Edit prompt'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('editor-title'),
                controller: _title,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('editor-body'),
                controller: _body,
                minLines: 7,
                maxLines: 14,
                decoration: const InputDecoration(labelText: 'Body'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _keyword,
                decoration: const InputDecoration(labelText: 'Keyword'),
              ),
              if (snapshot != null) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Uncategorized'),
                    ),
                    for (final category in snapshot.categories)
                      DropdownMenuItem(
                        value: category.id,
                        child: Text(category.name),
                      ),
                  ],
                  onChanged: (value) => setState(() => _categoryId = value),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 6,
                    children: [
                      for (final tag in snapshot.tags)
                        FilterChip(
                          label: Text(tag.name),
                          selected: _tagIds.contains(tag.id),
                          onSelected: (selected) => setState(() {
                            selected
                                ? _tagIds.add(tag.id)
                                : _tagIds.remove(tag.id);
                          }),
                        ),
                    ],
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: isSaving ? null : _save,
          child: Text(isSaving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}

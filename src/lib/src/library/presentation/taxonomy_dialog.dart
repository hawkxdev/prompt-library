/// Taxonomy management dialog.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../models/library_failure.dart';
import '../models/library_snapshot.dart';
import 'library_controller.dart';
import 'library_failure_message.dart';
import 'library_state.dart';

/// Opens category and tag manager.
Future<void> showTaxonomyDialog(
  BuildContext context, {
  required LibraryController controller,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _TaxonomyDialog(controller: controller),
  );
}

final class _TaxonomyDialog extends StatefulWidget {
  const _TaxonomyDialog({required this.controller});

  final LibraryController controller;

  @override
  State<_TaxonomyDialog> createState() => _TaxonomyDialogState();
}

final class _TaxonomyDialogState extends State<_TaxonomyDialog> {
  late LibraryState _state;
  late final StreamSubscription<LibraryState> _subscription;
  final TextEditingController _categoryName = TextEditingController();
  final TextEditingController _tagName = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _state = widget.controller.state;
    _subscription = widget.controller.states.listen((state) {
      if (mounted) setState(() => _state = state);
    });
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    _categoryName.dispose();
    _tagName.dispose();
    super.dispose();
  }

  Future<bool> _run(Future<void> Function() operation) async {
    try {
      await operation();
      if (mounted) setState(() => _error = null);
      return true;
    } on LibraryFailure catch (failure) {
      if (mounted) setState(() => _error = messageForLibraryFailure(failure));
      return false;
    }
  }

  Future<bool> _confirm(String title, String content) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _rename({
    required String title,
    required String initialValue,
    required Future<void> Function(String) operation,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => _RenameTaxonomyDialog(
        title: title,
        initialValue: initialValue,
        operation: operation,
      ),
    );
  }

  bool _active(LibraryMutationKind kind, {String? entityId}) {
    return _state.isMutationActive(
      LibraryMutationKey(kind, entityId: entityId),
    );
  }

  void _moveCategory(List<String> categoryIds, int oldIndex, int newIndex) {
    if (_active(LibraryMutationKind.reorderCategories) ||
        oldIndex == newIndex) {
      return;
    }
    final reordered = [...categoryIds];
    final id = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, id);
    unawaited(_run(() => widget.controller.reorderCategories(reordered)));
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _state.snapshot;
    return DefaultTabController(
      length: 2,
      child: AlertDialog(
        title: const Text('Categories and tags'),
        content: SizedBox(
          width: 560,
          height: 460,
          child: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(text: 'Categories'),
                  Tab(text: 'Tags'),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Expanded(
                child: TabBarView(
                  children: [_categories(snapshot), _tags(snapshot)],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Builds category creation, ordering and actions.
  Widget _categories(LibrarySnapshot? snapshot) {
    final categories = snapshot?.categories ?? const [];
    final categoryIds = [for (final category in categories) category.id];
    final reorderActive = _active(LibraryMutationKind.reorderCategories);
    return Column(
      children: [
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _categoryName,
                decoration: const InputDecoration(labelText: 'New category'),
              ),
            ),
            IconButton(
              tooltip: 'Add category',
              onPressed: _active(LibraryMutationKind.createCategory)
                  ? null
                  : () async {
                      final name = _categoryName.text.trim();
                      if (name.isEmpty) return;
                      if (await _run(
                        () => widget.controller.createCategory(name),
                      )) {
                        _categoryName.clear();
                      }
                    },
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        Expanded(
          child: ReorderableListView.builder(
            itemCount: categories.length,
            onReorderItem: (oldIndex, newIndex) =>
                _moveCategory(categoryIds, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final category = categories[index];
              return ListTile(
                key: ValueKey(category.id),
                title: Text(category.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Move ${category.name} up',
                      onPressed: index == 0 || reorderActive
                          ? null
                          : () => _moveCategory(categoryIds, index, index - 1),
                      icon: const Icon(Icons.keyboard_arrow_up),
                    ),
                    IconButton(
                      tooltip: 'Move ${category.name} down',
                      onPressed: index == categories.length - 1 || reorderActive
                          ? null
                          : () => _moveCategory(categoryIds, index, index + 1),
                      icon: const Icon(Icons.keyboard_arrow_down),
                    ),
                    IconButton(
                      tooltip: 'Edit category',
                      onPressed:
                          _active(
                            LibraryMutationKind.renameCategory,
                            entityId: category.id,
                          )
                          ? null
                          : () => _rename(
                              title: 'Rename category',
                              initialValue: category.name,
                              operation: (name) => widget.controller
                                  .renameCategory(category.id, name),
                            ),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Delete category',
                      onPressed:
                          _active(
                            LibraryMutationKind.deleteCategory,
                            entityId: category.id,
                          )
                          ? null
                          : () async {
                              final count =
                                  snapshot?.entries
                                      .where(
                                        (entry) =>
                                            entry.categoryId == category.id,
                                      )
                                      .length ??
                                  0;
                              if (await _confirm(
                                'Delete category?',
                                '$count prompts will become uncategorized.',
                              )) {
                                await _run(
                                  () => widget.controller.deleteCategory(
                                    category.id,
                                  ),
                                );
                              }
                            },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Builds tag creation and actions.
  Widget _tags(LibrarySnapshot? snapshot) {
    final tags = snapshot?.tags ?? const [];
    return Column(
      children: [
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tagName,
                decoration: const InputDecoration(labelText: 'New tag'),
              ),
            ),
            IconButton(
              tooltip: 'Add tag',
              onPressed: _active(LibraryMutationKind.createTag)
                  ? null
                  : () async {
                      final name = _tagName.text.trim();
                      if (name.isEmpty) return;
                      if (await _run(() => widget.controller.createTag(name))) {
                        _tagName.clear();
                      }
                    },
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        Expanded(
          child: ListView(
            children: [
              for (final tag in tags)
                ListTile(
                  title: Text(tag.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit tag',
                        onPressed:
                            _active(
                              LibraryMutationKind.renameTag,
                              entityId: tag.id,
                            )
                            ? null
                            : () => _rename(
                                title: 'Rename tag',
                                initialValue: tag.name,
                                operation: (name) =>
                                    widget.controller.renameTag(tag.id, name),
                              ),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Delete tag',
                        onPressed:
                            _active(
                              LibraryMutationKind.deleteTag,
                              entityId: tag.id,
                            )
                            ? null
                            : () async {
                                final count =
                                    snapshot?.entries
                                        .where(
                                          (entry) =>
                                              entry.tagIds.contains(tag.id),
                                        )
                                        .length ??
                                    0;
                                if (await _confirm(
                                  'Delete tag?',
                                  'The tag will be removed from $count prompts.',
                                )) {
                                  await _run(
                                    () => widget.controller.deleteTag(tag.id),
                                  );
                                }
                              },
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

final class _RenameTaxonomyDialog extends StatefulWidget {
  const _RenameTaxonomyDialog({
    required this.title,
    required this.initialValue,
    required this.operation,
  });

  final String title;
  final String initialValue;
  final Future<void> Function(String) operation;

  @override
  State<_RenameTaxonomyDialog> createState() => _RenameTaxonomyDialogState();
}

final class _RenameTaxonomyDialogState extends State<_RenameTaxonomyDialog> {
  late final TextEditingController _nameController;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = _nameController.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await widget.operation(value);
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
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('taxonomy-name'),
            controller: _nameController,
            autofocus: true,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: Text(_isSaving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}

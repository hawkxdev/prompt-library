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

  Future<void> _run(Future<void> Function() operation) async {
    try {
      await operation();
      if (mounted) setState(() => _error = null);
    } on LibraryFailure catch (failure) {
      if (mounted) setState(() => _error = messageForLibraryFailure(failure));
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
  }) async {
    final controller = TextEditingController(text: initialValue);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          key: const Key('taxonomy-name'),
          controller: controller,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null && value.isNotEmpty) {
      await _run(() => operation(value));
    }
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

  Widget _categories(LibrarySnapshot? snapshot) {
    final categories = snapshot?.categories ?? const [];
    return Column(
      children: [
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
              onPressed: () {
                final name = _categoryName.text.trim();
                if (name.isEmpty) return;
                unawaited(_run(() => widget.controller.createCategory(name)));
                _categoryName.clear();
              },
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        Expanded(
          child: ReorderableListView.builder(
            itemCount: categories.length,
            onReorderItem: (oldIndex, newIndex) {
              final ids = <String>[
                for (final category in categories) category.id,
              ];
              final id = ids.removeAt(oldIndex);
              ids.insert(newIndex, id);
              unawaited(_run(() => widget.controller.reorderCategories(ids)));
            },
            itemBuilder: (context, index) {
              final category = categories[index];
              return ListTile(
                key: ValueKey(category.id),
                title: Text(category.name),
                leading: const Icon(Icons.drag_handle),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Edit category',
                      onPressed: () => _rename(
                        title: 'Rename category',
                        initialValue: category.name,
                        operation: (name) =>
                            widget.controller.renameCategory(category.id, name),
                      ),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Delete category',
                      onPressed: () async {
                        final count =
                            snapshot?.entries
                                .where(
                                  (entry) => entry.categoryId == category.id,
                                )
                                .length ??
                            0;
                        if (await _confirm(
                          'Delete category?',
                          '$count prompts will become uncategorized.',
                        )) {
                          await _run(
                            () => widget.controller.deleteCategory(category.id),
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

  Widget _tags(LibrarySnapshot? snapshot) {
    final tags = snapshot?.tags ?? const [];
    return Column(
      children: [
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
              onPressed: () {
                final name = _tagName.text.trim();
                if (name.isEmpty) return;
                unawaited(_run(() => widget.controller.createTag(name)));
                _tagName.clear();
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
                        onPressed: () => _rename(
                          title: 'Rename tag',
                          initialValue: tag.name,
                          operation: (name) =>
                              widget.controller.renameTag(tag.id, name),
                        ),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Delete tag',
                        onPressed: () async {
                          final count =
                              snapshot?.entries
                                  .where(
                                    (entry) => entry.tagIds.contains(tag.id),
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

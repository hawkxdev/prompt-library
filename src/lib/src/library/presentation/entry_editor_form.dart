/// Shared entry editor form.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../models/entry.dart';
import '../models/entry_input.dart';
import '../models/library_failure.dart';
import 'library_controller.dart';
import 'library_failure_message.dart';
import 'library_state.dart';

// === Form policy ===

/// Defines body field sizing.
final class EntryEditorBodySize {
  /// Creates body field sizing.
  const EntryEditorBodySize({required this.minLines, required this.maxLines})
    : assert(minLines > 0),
      assert(maxLines >= minLines);

  /// Minimum visible body lines.
  final int minLines;

  /// Maximum visible body lines.
  final int maxLines;
}

/// Resolves body field sizing.
typedef EntryEditorBodySizePolicy = EntryEditorBodySize Function(
  BuildContext context,
);

/// Resolves editor mutation identity.
LibraryMutationKey entryEditorMutationKey(Entry? entry) {
  return entry == null
      ? const LibraryMutationKey(LibraryMutationKind.createEntry)
      : LibraryMutationKey(LibraryMutationKind.updateEntry, entityId: entry.id);
}

// === Form coordination ===

/// Coordinates external form actions.
final class EntryEditorFormController extends ChangeNotifier {
  /// Creates attached form coordination.
  EntryEditorFormController.forEditor({
    required LibraryController controller,
    Entry? entry,
  }) : _isSaving = controller.state.isMutationActive(
         entryEditorMutationKey(entry),
       );

  Future<void> Function()? _save;
  bool _isSaving;
  bool _isDisposed = false;

  /// Whether saving is active.
  bool get isSaving => _isSaving;

  /// Requests one form save.
  Future<void> save() async {
    if (_isDisposed) {
      throw StateError('Entry editor form controller is disposed.');
    }
    if (_isSaving) return;
    final save = _save;
    if (save == null) {
      throw StateError('Entry editor form is not attached.');
    }
    await save();
  }

  /// Attaches current form state.
  void _bind(Future<void> Function() save) {
    if (_isDisposed) {
      throw StateError('Entry editor form controller is disposed.');
    }
    if (_save != null && _save != save) {
      throw StateError('Entry editor form controller is already attached.');
    }
    _save = save;
  }

  /// Detaches current form state.
  void _unbind(Future<void> Function() save) {
    if (_save == save) {
      _save = null;
    }
  }

  /// Updates observable saving state.
  void _setSaving(bool value) {
    if (_isDisposed || _isSaving == value) return;
    _isSaving = value;
    notifyListeners();
  }

  /// Releases coordination resources.
  @override
  void dispose() {
    _isDisposed = true;
    _save = null;
    super.dispose();
  }
}

// === Shared form ===

/// Owns one editor draft.
final class EntryEditorForm extends StatefulWidget {
  /// Creates shared editor form.
  const EntryEditorForm({
    required this.controller,
    required this.formController,
    required this.bodySizePolicy,
    required this.onSaved,
    this.entry,
    super.key,
  });

  /// Shared library controller.
  final LibraryController controller;

  /// External action coordination.
  final EntryEditorFormController formController;

  /// Body field sizing policy.
  final EntryEditorBodySizePolicy bodySizePolicy;

  /// Successful save callback.
  final VoidCallback onSaved;

  /// Existing entry when editing.
  final Entry? entry;

  /// Creates local draft state.
  @override
  State<EntryEditorForm> createState() => _EntryEditorFormState();
}

/// Maintains shared editor draft.
final class _EntryEditorFormState extends State<EntryEditorForm> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _keyword;
  late LibraryState _state;
  late StreamSubscription<LibraryState> _subscription;
  String? _categoryId;
  late Set<String> _tagIds;
  bool _isSaving = false;
  String? _error;

  /// Initializes draft resources.
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
    _subscription = _listenTo(widget.controller);
    widget.formController._bind(_save);
    _scheduleSavingSync();
  }

  /// Rebinds changed collaborators.
  @override
  void didUpdateWidget(covariant EntryEditorForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry?.id != widget.entry?.id) {
      _replaceDraft(widget.entry);
    }
    if (oldWidget.controller != widget.controller) {
      unawaited(_subscription.cancel());
      _state = widget.controller.state;
      _subscription = _listenTo(widget.controller);
    }
    if (oldWidget.formController != widget.formController) {
      oldWidget.formController._unbind(_save);
      widget.formController._bind(_save);
    }
    _scheduleSavingSync();
  }

  /// Replaces all draft values.
  void _replaceDraft(Entry? entry) {
    _title.text = entry?.title ?? '';
    _body.text = entry?.body ?? '';
    _keyword.text = entry?.keyword ?? '';
    _categoryId = entry?.categoryId;
    _tagIds = {...?entry?.tagIds};
    _isSaving = false;
    _error = null;
  }

  /// Cancels owned draft resources.
  @override
  void dispose() {
    widget.formController._unbind(_save);
    unawaited(_subscription.cancel());
    _title.dispose();
    _body.dispose();
    _keyword.dispose();
    super.dispose();
  }

  /// Listens to controller states.
  StreamSubscription<LibraryState> _listenTo(LibraryController controller) {
    return controller.states.listen((state) {
      if (!mounted) return;
      setState(() => _state = state);
      _syncSaving();
    });
  }

  /// Resolves effective saving state.
  bool get _saving {
    return _isSaving ||
        _state.isMutationActive(entryEditorMutationKey(widget.entry));
  }

  /// Publishes effective saving state.
  void _syncSaving() {
    widget.formController._setSaving(_saving);
  }

  /// Defers lifecycle saving updates.
  void _scheduleSavingSync() {
    final formController = widget.formController;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.formController != formController) return;
      _syncSaving();
    });
  }

  /// Validates and persists draft.
  Future<void> _save() async {
    if (_saving) return;
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
    _syncSaving();
    try {
      if (existing == null) {
        await widget.controller.createEntry(input);
      } else {
        await widget.controller.updateEntry(existing.id, input);
      }
      if (mounted) widget.onSaved();
    } on LibraryFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = messageForLibraryFailure(failure);
      });
      _syncSaving();
    }
  }

  /// Builds shared draft fields.
  @override
  Widget build(BuildContext context) {
    final snapshot = _state.snapshot;
    final bodySize = widget.bodySizePolicy(context);
    return SingleChildScrollView(
      key: const Key('editor-content'),
      padding: const EdgeInsets.only(top: 14, bottom: 16),
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
            minLines: bodySize.minLines,
            maxLines: bodySize.maxLines,
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
                        selected ? _tagIds.add(tag.id) : _tagIds.remove(tag.id);
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
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

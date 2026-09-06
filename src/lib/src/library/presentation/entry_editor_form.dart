/// Shared entry editor form.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

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
  bool _isDirty = false;
  bool _isDisposed = false;

  /// Whether saving is active.
  bool get isSaving => _isSaving;

  /// Whether the draft differs.
  bool get isDirty => _isDirty;

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

  /// Updates observable dirty state.
  void _setDirty(bool value) {
    if (_isDisposed || _isDirty == value) return;
    _isDirty = value;
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
  final FocusNode _titleFocus = FocusNode(debugLabel: 'editor-title');
  final FocusNode _bodyFocus = FocusNode(debugLabel: 'editor-body');
  late LibraryState _state;
  late StreamSubscription<LibraryState> _subscription;
  String? _categoryId;
  late Set<String> _tagIds;
  late String _initialTitle;
  late String _initialBody;
  late String _initialKeyword;
  String? _initialCategoryId;
  late Set<String> _initialTagIds;
  bool _isSaving = false;
  bool _suppressDirtySync = false;
  String? _titleError;
  String? _bodyError;
  String? _failure;

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
    _captureBaseline();
    _title.addListener(_syncDirty);
    _body.addListener(_syncDirty);
    _keyword.addListener(_syncDirty);
    _title.addListener(_clearResolvedFieldErrors);
    _body.addListener(_clearResolvedFieldErrors);
    _state = widget.controller.state;
    _subscription = _listenTo(widget.controller);
    widget.formController._bind(_save);
    _scheduleCoordinatorSync();
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
    _scheduleCoordinatorSync();
  }

  /// Replaces all draft values.
  void _replaceDraft(Entry? entry) {
    _suppressDirtySync = true;
    _title.text = entry?.title ?? '';
    _body.text = entry?.body ?? '';
    _keyword.text = entry?.keyword ?? '';
    _categoryId = entry?.categoryId;
    _tagIds = {...?entry?.tagIds};
    _isSaving = false;
    _titleError = null;
    _bodyError = null;
    _failure = null;
    _captureBaseline();
    _suppressDirtySync = false;
  }

  /// Drops a field refusal the user has resolved.
  void _clearResolvedFieldErrors() {
    if (_suppressDirtySync) return;
    final titleResolved = _titleError != null && _title.text.trim().isNotEmpty;
    final bodyResolved = _bodyError != null && _body.text.trim().isNotEmpty;
    if (!titleResolved && !bodyResolved) return;
    setState(() {
      if (titleResolved) _titleError = null;
      if (bodyResolved) _bodyError = null;
    });
  }

  /// Refuses the save at one field.
  void _refuseAt(FocusNode focus, {String? title, String? body}) {
    setState(() {
      _titleError = title;
      _bodyError = body;
      _failure = null;
    });
    // Focus is requested synchronously so the blocking field is both announced
    // and scrolled into view by the framework's own focus handling.
    focus.requestFocus();
  }

  /// Captures the current baseline.
  void _captureBaseline() {
    _initialTitle = _title.text;
    _initialBody = _body.text;
    _initialKeyword = _keyword.text;
    _initialCategoryId = _categoryId;
    _initialTagIds = {..._tagIds};
  }

  /// Cancels owned draft resources.
  @override
  void dispose() {
    widget.formController._unbind(_save);
    unawaited(_subscription.cancel());
    _title.dispose();
    _body.dispose();
    _keyword.dispose();
    _titleFocus.dispose();
    _bodyFocus.dispose();
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

  /// Publishes effective dirty state.
  void _syncDirty() {
    if (_suppressDirtySync) return;
    widget.formController._setDirty(
      _title.text != _initialTitle ||
          _body.text != _initialBody ||
          _keyword.text != _initialKeyword ||
          _categoryId != _initialCategoryId ||
          !_setEquals(_tagIds, _initialTagIds),
    );
  }

  /// Defers lifecycle saving updates.
  void _scheduleCoordinatorSync() {
    final formController = widget.formController;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.formController != formController) return;
      _syncSaving();
      _syncDirty();
    });
  }

  /// Validates and persists draft.
  Future<void> _save() async {
    if (_saving) return;
    if (_title.text.trim().isEmpty) {
      _refuseAt(_titleFocus, title: 'Title is required.');
      return;
    }
    if (_body.text.trim().isEmpty) {
      _refuseAt(_bodyFocus, body: 'Body is required.');
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
      _titleError = null;
      _bodyError = null;
      _failure = null;
    });
    _syncSaving();
    try {
      if (existing == null) {
        await widget.controller.createEntry(input);
      } else {
        await widget.controller.updateEntry(existing.id, input);
      }
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _failure = null;
        _captureBaseline();
      });
      _syncSaving();
      _syncDirty();
      widget.onSaved();
    } on LibraryFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _failure = messageForLibraryFailure(failure);
      });
      _syncSaving();
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        _syncSaving();
      }
      rethrow;
    }
  }

  /// Selects the draft category.
  void _selectCategory(String? value) {
    setState(() => _categoryId = value);
    _syncDirty();
  }

  /// Selects one draft tag.
  void _selectTag(String id, bool selected) {
    setState(() {
      selected ? _tagIds.add(id) : _tagIds.remove(id);
    });
    _syncDirty();
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
        key: const Key('editor-fields'),
        mainAxisSize: MainAxisSize.min,
        children: [
          // The refusal belongs to the field that blocks the save: the error
          // text is announced together with the field's own label, and the
          // validation result carries the state to the platform without
          // relying on color.
          Semantics(
            validationResult: _titleError == null
                ? SemanticsValidationResult.none
                : SemanticsValidationResult.invalid,
            child: TextField(
              key: const Key('editor-title'),
              controller: _title,
              focusNode: _titleFocus,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Title',
                errorText: _titleError,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            validationResult: _bodyError == null
                ? SemanticsValidationResult.none
                : SemanticsValidationResult.invalid,
            child: TextField(
              key: const Key('editor-body'),
              controller: _body,
              focusNode: _bodyFocus,
              minLines: bodySize.minLines,
              maxLines: bodySize.maxLines,
              decoration: InputDecoration(
                labelText: 'Body',
                errorText: _bodyError,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('editor-keyword'),
            controller: _keyword,
            decoration: const InputDecoration(labelText: 'Keyword'),
          ),
          if (snapshot != null) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              key: const Key('editor-category'),
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'Category'),
              // The selected label is laid out next to the arrow, so at large
              // text scales an intrinsic-width item overflows the field.
              isExpanded: true,
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Uncategorized', overflow: TextOverflow.ellipsis),
                ),
                for (final category in snapshot.categories)
                  DropdownMenuItem(
                    value: category.id,
                    child: Text(category.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: _selectCategory,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                children: [
                  for (final tag in snapshot.tags)
                    FilterChip(
                      key: Key('editor-tag-${tag.id}'),
                      label: Text(tag.name),
                      selected: _tagIds.contains(tag.id),
                      onSelected: (selected) => _selectTag(tag.id, selected),
                    ),
                ],
              ),
            ),
          ],
          // A persistence failure has no field to blame, so it keeps the
          // summary, and announces itself because nothing else will.
          if (_failure != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _failure!,
                  key: const Key('editor-failure'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compares string sets.
bool _setEquals(Set<String> first, Set<String> second) {
  return first.length == second.length && first.containsAll(second);
}

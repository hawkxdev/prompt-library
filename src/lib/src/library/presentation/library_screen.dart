/// Full library screen.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/entry.dart';
import '../models/library_failure.dart';
import '../models/library_snapshot.dart';
import 'delete_entry_dialog.dart';
import 'entry_editor_dialog.dart';
import 'library_clipboard.dart';
import 'library_controller.dart';
import 'library_detail.dart';
import 'library_failure_message.dart';
import 'library_filter.dart';
import 'library_list.dart';
import 'library_shortcuts.dart';
import 'library_sidebar.dart';
import 'library_state.dart';
import 'taxonomy_dialog.dart';

/// Complete full-library experience.
final class LibraryScreen extends StatefulWidget {
  /// Creates library screen.
  const LibraryScreen({
    required this.controller,
    required this.clipboard,
    super.key,
  });

  final LibraryController controller;
  final LibraryClipboard clipboard;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

final class _LibraryScreenState extends State<LibraryScreen> {
  late LibraryState _state;
  late final StreamSubscription<LibraryState> _subscription;
  late final TextEditingController _searchController;
  final FocusNode _searchFocus = FocusNode(debugLabel: 'library-search');
  final FocusNode _listFocus = FocusNode(debugLabel: 'library-list');
  bool _showNarrowDetail = false;

  @override
  void initState() {
    super.initState();
    _state = widget.controller.state;
    _searchController = TextEditingController(text: _state.filter.searchQuery);
    _subscription = widget.controller.states.listen((state) {
      if (!mounted) return;
      setState(() => _state = state);
    });
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    _searchController.dispose();
    _searchFocus.dispose();
    _listFocus.dispose();
    super.dispose();
  }

  Entry? get _selectedEntry {
    final id = _state.selectedEntryId;
    if (id == null) return null;
    for (final entry in _state.visibleEntries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  Future<void> _copySelected() async {
    final entry = _selectedEntry;
    if (entry == null) return;
    try {
      await widget.clipboard.writeText(entry.body);
    } on LibraryClipboardFailure {
      if (mounted) _showMessage('The prompt could not be copied.');
      return;
    }
    try {
      await widget.controller.markCopied(entry.id);
    } on LibraryFailure {
      // The clipboard already contains the exact body; retained state shows metadata failure.
    }
    if (mounted) _showMessage('Copied');
  }

  Future<void> _runMutation(Future<void> Function() operation) async {
    try {
      await operation();
    } on LibraryFailure {
      // The controller retains a non-sensitive failure for the banner.
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _moveSelection(int offset) {
    final entries = _state.visibleEntries;
    if (entries.isEmpty) return;
    final current = entries.indexWhere(
      (entry) => entry.id == _state.selectedEntryId,
    );
    final next = (current < 0 ? 0 : current + offset).clamp(
      0,
      entries.length - 1,
    );
    widget.controller.selectEntry(entries[next].id);
  }

  void _selectBoundary(bool last) {
    final entries = _state.visibleEntries;
    if (entries.isEmpty) return;
    widget.controller.selectEntry(last ? entries.last.id : entries.first.id);
  }

  Future<void> _deleteSelected() async {
    final entry = _selectedEntry;
    if (entry == null) return;
    if (await showDeleteEntryDialog(context, entry: entry)) {
      await _runMutation(() => widget.controller.deleteEntry(entry.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final shortcuts = <ShortcutActivator, Intent>{
      const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
          const FocusLibrarySearchIntent(),
      const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
          const CreateLibraryEntryIntent(),
      const SingleActivator(LogicalKeyboardKey.keyE, meta: true):
          const EditLibraryEntryIntent(),
      const SingleActivator(LogicalKeyboardKey.keyN, control: true):
          const CreateLibraryEntryIntent(),
    };
    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: {
          FocusLibrarySearchIntent: CallbackAction<FocusLibrarySearchIntent>(
            onInvoke: (_) => _searchFocus.requestFocus(),
          ),
          CreateLibraryEntryIntent: CallbackAction<CreateLibraryEntryIntent>(
            onInvoke: (_) =>
                showEntryEditorDialog(context, controller: widget.controller),
          ),
          EditLibraryEntryIntent: CallbackAction<EditLibraryEntryIntent>(
            onInvoke: (_) {
              final entry = _selectedEntry;
              if (entry != null) {
                return showEntryEditorDialog(
                  context,
                  controller: widget.controller,
                  entry: entry,
                );
              }
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(body: SafeArea(child: _buildBody())),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_state.loadStatus == LibraryLoadStatus.loading &&
        !_state.hasUsableSnapshot) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_state.loadStatus == LibraryLoadStatus.failure &&
        !_state.hasUsableSnapshot) {
      return _InitialFailure(failure: _state.failure);
    }
    final snapshot = _state.snapshot;
    if (snapshot == null) return const SizedBox.shrink();
    return Column(
      children: [
        if (_state.failure != null)
          MaterialBanner(
            content: Text(messageForLibraryFailure(_state.failure!)),
            actions: [
              TextButton(
                onPressed: widget.controller.dismissFailure,
                child: const Text('Dismiss'),
              ),
            ],
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 720) return _narrowPane(snapshot);
              final wide = constraints.maxWidth >= 1040;
              return Row(
                children: [
                  if (wide)
                    SizedBox(
                      width: 230,
                      child: LibrarySidebar(
                        snapshot: snapshot,
                        filter: _state.filter,
                        onScope: widget.controller.setFilterScope,
                        onCategory: widget.controller.setCategoryFilter,
                        onManageTaxonomy: () => showTaxonomyDialog(
                          context,
                          controller: widget.controller,
                        ),
                      ),
                    ),
                  SizedBox(
                    width: wide ? 340 : 300,
                    child: _resultPane(snapshot),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: _detailPane(snapshot)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _resultPane(LibrarySnapshot snapshot) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('library-search'),
                  controller: _searchController,
                  focusNode: _searchFocus,
                  onChanged: widget.controller.updateSearchQuery,
                  decoration: const InputDecoration(
                    hintText: 'Search prompts',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'New prompt',
                onPressed: () => showEntryEditorDialog(
                  context,
                  controller: widget.controller,
                ),
                icon: const Icon(Icons.add),
              ),
              if (MediaQuery.sizeOf(context).width < 1040)
                PopupMenuButton<LibraryFilterScope>(
                  tooltip: 'Library scope',
                  onSelected: widget.controller.setFilterScope,
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: LibraryFilterScope.active,
                      child: Text('All prompts'),
                    ),
                    PopupMenuItem(
                      value: LibraryFilterScope.favorites,
                      child: Text('Favorites'),
                    ),
                    PopupMenuItem(
                      value: LibraryFilterScope.archived,
                      child: Text('Archived'),
                    ),
                  ],
                ),
            ],
          ),
        ),
        Expanded(
          child: _state.visibleEntries.isEmpty
              ? _EmptyState(
                  filtered:
                      _state.filter.searchQuery.isNotEmpty ||
                      _state.filter.scope != LibraryFilterScope.active ||
                      _state.filter.categoryId != null ||
                      _state.filter.tagIds.isNotEmpty,
                  onCreate: () => showEntryEditorDialog(
                    context,
                    controller: widget.controller,
                  ),
                )
              : Shortcuts(
                  shortcuts: const {
                    SingleActivator(LogicalKeyboardKey.arrowUp):
                        MoveLibrarySelectionIntent(-1),
                    SingleActivator(LogicalKeyboardKey.arrowDown):
                        MoveLibrarySelectionIntent(1),
                    SingleActivator(LogicalKeyboardKey.home):
                        SelectLibraryBoundaryIntent(last: false),
                    SingleActivator(LogicalKeyboardKey.end):
                        SelectLibraryBoundaryIntent(last: true),
                    SingleActivator(LogicalKeyboardKey.enter):
                        CopySelectedEntryIntent(),
                  },
                  child: Actions(
                    actions: {
                      MoveLibrarySelectionIntent:
                          CallbackAction<MoveLibrarySelectionIntent>(
                            onInvoke: (intent) => _moveSelection(intent.offset),
                          ),
                      SelectLibraryBoundaryIntent:
                          CallbackAction<SelectLibraryBoundaryIntent>(
                            onInvoke: (intent) => _selectBoundary(intent.last),
                          ),
                      CopySelectedEntryIntent:
                          CallbackAction<CopySelectedEntryIntent>(
                            onInvoke: (_) => _copySelected(),
                          ),
                    },
                    child: LibraryList(
                      entries: _state.visibleEntries,
                      selectedEntryId: _state.selectedEntryId,
                      onSelected: (id) {
                        widget.controller.selectEntry(id);
                        if (MediaQuery.sizeOf(context).width < 720) {
                          setState(() => _showNarrowDetail = true);
                        }
                      },
                      focusNode: _listFocus,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _narrowPane(LibrarySnapshot snapshot) {
    if (!_showNarrowDetail || _selectedEntry == null) {
      return _resultPane(snapshot);
    }
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _showNarrowDetail = false),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Prompts'),
          ),
        ),
        Expanded(child: _detailPane(snapshot)),
      ],
    );
  }

  Widget _detailPane(LibrarySnapshot snapshot) {
    final entry = _selectedEntry;
    if (entry == null) {
      return const Center(child: Text('Select a prompt'));
    }
    return LibraryDetail(
      entry: entry,
      snapshot: snapshot,
      onCopy: _copySelected,
      onEdit: () => showEntryEditorDialog(
        context,
        controller: widget.controller,
        entry: entry,
      ),
      onFavorite: () => _runMutation(
        () => widget.controller.setFavorite(
          entry.id,
          isFavorite: !entry.isFavorite,
        ),
      ),
      onArchive: () => _runMutation(
        () => widget.controller.setArchived(
          entry.id,
          isArchived: !entry.isArchived,
        ),
      ),
      onDelete: _deleteSelected,
    );
  }
}

final class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filtered, required this.onCreate});

  final bool filtered;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            filtered ? Icons.search_off : Icons.library_add_outlined,
            size: 42,
          ),
          const SizedBox(height: 12),
          Text(filtered ? 'No matching prompts' : 'Your library is empty'),
          if (!filtered) ...[
            const SizedBox(height: 12),
            FilledButton(onPressed: onCreate, child: const Text('New prompt')),
          ],
        ],
      ),
    );
  }
}

final class _InitialFailure extends StatelessWidget {
  const _InitialFailure({required this.failure});

  final LibraryFailure? failure;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          failure == null
              ? 'The library could not be opened.'
              : messageForLibraryFailure(failure!),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

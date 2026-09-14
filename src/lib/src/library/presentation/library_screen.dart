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
    this.onConfigureHotKey,
    super.key,
  });

  /// Shared application controller.
  final LibraryController controller;

  /// Exact clipboard boundary.
  final LibraryClipboard clipboard;

  /// Optional macOS global-shortcut settings action.
  final VoidCallback? onConfigureHotKey;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

/// Owns screen-local controllers, focus and subscription.
final class _LibraryScreenState extends State<LibraryScreen> {
  late LibraryState _state;
  late final StreamSubscription<LibraryState> _subscription;
  late final TextEditingController _searchController;
  final FocusNode _searchFocus = FocusNode(debugLabel: 'library-search');
  final FocusNode _listFocus = FocusNode(debugLabel: 'library-list');
  final ScrollController _listScrollController = ScrollController();
  final Map<String, GlobalKey> _rowKeys = {};
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
    _listScrollController.dispose();
    _rowKeys.clear();
    super.dispose();
  }

  /// Resolves the selected entry from visible results.
  Entry? get _selectedEntry {
    final id = _state.selectedEntryId;
    if (id == null) return null;
    for (final entry in _state.visibleEntries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  /// Copies the selected body and reports the outcome.
  Future<void> _copySelected() async {
    final entry = _selectedEntry;
    if (entry == null) return;
    final outcome = await copyLibraryEntry(
      entry: entry,
      clipboard: widget.clipboard,
      controller: widget.controller,
    );
    if (outcome == LibraryCopyOutcome.clipboardFailure) {
      if (mounted) _showMessage('The prompt could not be copied.');
      return;
    }
    if (mounted) _showMessage('Copied');
  }

  /// Runs a mutation and leaves typed failures to the retained banner.
  Future<void> _runMutation(Future<void> Function() operation) async {
    try {
      await operation();
    } on LibraryFailure {
      // The controller retains a non-sensitive failure for the banner.
    }
  }

  /// Shows a transient message.
  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Opens navigation for compact surfaces.
  Future<void> _showLibraryNavigation() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: SizedBox(
          width: 320,
          height: 520,
          child: StreamBuilder<LibraryState>(
            initialData: widget.controller.state,
            stream: widget.controller.states,
            builder: (context, stateSnapshot) {
              final state = stateSnapshot.data ?? widget.controller.state;
              final snapshot = state.snapshot;
              if (snapshot == null) return const SizedBox.shrink();
              return LibrarySidebar(
                snapshot: snapshot,
                filter: state.filter,
                onScope: widget.controller.setFilterScope,
                onCategory: widget.controller.setCategoryFilter,
                onTags: widget.controller.setTagFilter,
                onManageTaxonomy: () {
                  Navigator.pop(dialogContext);
                  unawaited(
                    showTaxonomyDialog(
                      this.context,
                      controller: widget.controller,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  /// Resolves a stable row key.
  GlobalKey _rowKeyFor(String id) {
    return _rowKeys.putIfAbsent(id, () => GlobalKey(debugLabel: 'entry-$id'));
  }

  /// Selects an entry and keeps it visible.
  void _selectAndReveal(int index) {
    final entry = _state.visibleEntries[index];
    if (_listScrollController.hasClients) {
      final position = _listScrollController.position;
      const itemExtent = 52.0;
      final itemStart = index * itemExtent;
      final itemEnd = itemStart + itemExtent;
      if (itemStart < position.pixels ||
          itemEnd > position.pixels + position.viewportDimension) {
        final target =
            (itemStart - (position.viewportDimension - itemExtent) / 2)
                .clamp(position.minScrollExtent, position.maxScrollExtent)
                .toDouble();
        _listScrollController.jumpTo(target);
      }
    }
    widget.controller.selectEntry(entry.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_ensureSelectionVisible(entry.id));
    });
  }

  /// Scrolls the selected row into view.
  Future<void> _ensureSelectionVisible(String id) async {
    final rowContext = _rowKeys[id]?.currentContext;
    if (rowContext != null) {
      await Scrollable.ensureVisible(
        rowContext,
        duration: const Duration(milliseconds: 100),
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    }
  }

  /// Moves selection by one step.
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
    _selectAndReveal(next);
  }

  /// Selects the first or last entry.
  void _selectBoundary(bool last) {
    final entries = _state.visibleEntries;
    if (entries.isEmpty) return;
    _selectAndReveal(last ? entries.length - 1 : 0);
  }

  /// Focuses search immediately, deferring only until a narrow surface
  /// mounts the field.
  void _focusSearch() {
    if (_showNarrowDetail) {
      setState(() => _showNarrowDetail = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
      return;
    }
    _searchFocus.requestFocus();
  }

  /// Deletes the selected entry after confirmation.
  Future<void> _deleteSelected() async {
    final entry = _selectedEntry;
    if (entry == null) return;
    if (await showDeleteEntryDialog(context, entry: entry)) {
      await _runMutation(() => widget.controller.deleteEntry(entry.id));
    }
  }

  /// Builds application shortcuts, actions and the screen body.
  @override
  Widget build(BuildContext context) {
    final shortcuts = <ShortcutActivator, Intent>{
      const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
          const FocusLibrarySearchIntent(),
      const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
          const CreateLibraryEntryIntent(),
      const SingleActivator(LogicalKeyboardKey.keyE, meta: true):
          const EditLibraryEntryIntent(),
    };
    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: {
          FocusLibrarySearchIntent: CallbackAction<FocusLibrarySearchIntent>(
            onInvoke: (_) => _focusSearch(),
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

  /// Builds the observable library state surface.
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
        // Non-blocking failure banner
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
        // Adaptive panes
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
                        onTags: widget.controller.setTagFilter,
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

  /// Builds search, filters and the result list.
  Widget _resultPane(LibrarySnapshot snapshot) {
    return Column(
      children: [
        // Search and pane actions
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
              if (MediaQuery.sizeOf(context).width < 1040)
                IconButton(
                  tooltip: 'Library navigation',
                  onPressed: _showLibraryNavigation,
                  icon: const Icon(Icons.menu),
                ),
              IconButton(
                tooltip: 'New prompt',
                onPressed: () => showEntryEditorDialog(
                  context,
                  controller: widget.controller,
                ),
                icon: const Icon(Icons.add),
              ),
              if (widget.onConfigureHotKey != null)
                IconButton(
                  key: const Key('hotkey-settings'),
                  tooltip: 'Global shortcut',
                  onPressed: widget.onConfigureHotKey,
                  icon: const Icon(Icons.keyboard),
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
        // Result list or empty state
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
                      scrollController: _listScrollController,
                      rowKeyFor: _rowKeyFor,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  /// Builds the narrow list or detail surface.
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

  /// Builds the detail pane for the current selection.
  Widget _detailPane(LibrarySnapshot snapshot) {
    final entry = _selectedEntry;
    if (entry == null) {
      return const Center(child: Text('Select a prompt'));
    }
    bool active(LibraryMutationKind kind) =>
        _state.isMutationActive(LibraryMutationKey(kind, entityId: entry.id));
    return LibraryDetail(
      entry: entry,
      snapshot: snapshot,
      onCopy: _copySelected,
      onEdit: active(LibraryMutationKind.updateEntry)
          ? null
          : () => showEntryEditorDialog(
              context,
              controller: widget.controller,
              entry: entry,
            ),
      onFavorite: active(LibraryMutationKind.setFavorite)
          ? null
          : () => _runMutation(
              () => widget.controller.setFavorite(
                entry.id,
                isFavorite: !entry.isFavorite,
              ),
            ),
      onArchive: active(LibraryMutationKind.setArchived)
          ? null
          : () => _runMutation(
              () => widget.controller.setArchived(
                entry.id,
                isArchived: !entry.isArchived,
              ),
            ),
      onDelete: active(LibraryMutationKind.deleteEntry)
          ? null
          : _deleteSelected,
    );
  }
}

/// Empty result placeholder.
final class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filtered, required this.onCreate});

  final bool filtered;
  final VoidCallback onCreate;

  /// Builds the empty state.
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

/// Initial load failure surface.
final class _InitialFailure extends StatelessWidget {
  const _InitialFailure({required this.failure});

  final LibraryFailure? failure;

  /// Builds the failure message.
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

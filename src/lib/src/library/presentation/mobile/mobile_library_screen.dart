/// Mobile library screen.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../models/entry.dart';
import '../../models/library_failure.dart';
import '../delete_entry_dialog.dart';
import '../library_clipboard.dart';
import '../library_controller.dart';
import '../library_failure_message.dart';
import '../library_haptics.dart';
import '../library_share.dart';
import '../library_state.dart';
import '../transfer/library_transfer_controller.dart';
import '../transfer/library_transfer_screen.dart';
import '../transfer/library_transfer_state.dart';
import 'mobile_entry_editor_screen.dart';
import 'mobile_entry_detail_screen.dart';
import 'mobile_filter_sheet.dart';
import 'mobile_library_actions.dart';
import 'mobile_library_mode.dart';

/// Search-first mobile retrieval surface.
final class MobileLibraryScreen extends StatefulWidget {
  /// Creates mobile library screen.
  const MobileLibraryScreen({
    required this.controller,
    required this.clipboard,
    required this.transfer,
    required this.share,
    required this.haptics,
    super.key,
  });

  /// Shared application controller.
  final LibraryController controller;

  /// Exact clipboard boundary.
  final LibraryClipboard clipboard;

  /// Shared transfer operation owner.
  final LibraryTransferController transfer;

  /// System sharing boundary.
  final LibraryShare share;

  /// Best-effort tactile feedback boundary.
  final LibraryHaptics haptics;

  @override
  State<MobileLibraryScreen> createState() => _MobileLibraryScreenState();
}

/// Actions available from the mobile row context menu.
enum _MobileRowAction { favorite, archive, delete }

/// Owns screen-local search, subscription, mode and actions.
final class _MobileLibraryScreenState extends State<MobileLibraryScreen> {
  late LibraryState _state;
  late final StreamSubscription<LibraryState> _subscription;
  late final StreamSubscription<LibraryTransferState> _transferSubscription;
  late final TextEditingController _searchController;
  late final MobileLibraryActions _actions;
  MobileLibraryMode _mode = MobileLibraryMode.all;

  @override
  void initState() {
    super.initState();
    _state = widget.controller.state;
    _searchController = TextEditingController(text: _state.filter.searchQuery);
    _actions = MobileLibraryActions(
      controller: widget.controller,
      clipboard: widget.clipboard,
      share: widget.share,
      haptics: widget.haptics,
    );
    _subscription = widget.controller.states.listen(
      (state) {
        if (!mounted) return;
        setState(() => _state = state);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted) return;
        _showMessage('The library could not be updated. Try again.');
      },
    );
    _transferSubscription = widget.transfer.states.listen((state) {
      if (!mounted) return;
      if (state is LibraryTransferRestoreDone) {
        widget.controller.resetView();
        setState(() {
          _searchController.clear();
          _mode = MobileLibraryMode.all;
        });
      }
    });
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    unawaited(_transferSubscription.cancel());
    _searchController.dispose();
    super.dispose();
  }

  /// Whether any filter narrows the current result.
  bool get _isFiltered {
    return _state.filter.searchQuery.isNotEmpty ||
        _mode != MobileLibraryMode.all ||
        _state.filter.categoryId != null ||
        _state.filter.tagIds.isNotEmpty;
  }

  /// Builds the mobile scaffold.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _buildBody()),
      floatingActionButton: _state.hasUsableSnapshot
          ? FloatingActionButton(
              key: const Key('mobile-create-entry'),
              tooltip: 'New prompt',
              onPressed: () => unawaited(_openEditor()),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  /// Opens the create editor route.
  Future<void> _openEditor() {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MobileEntryEditorScreen(controller: widget.controller),
      ),
    );
  }

  /// Opens the transfer operation route over the shared owner.
  Future<void> _openTransfer() {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Transfer library')),
          body: LibraryTransferScreen(
            transfer: widget.transfer,
            onFinished: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }

  /// Builds the observable library state surface.
  Widget _buildBody() {
    if (_state.loadStatus == LibraryLoadStatus.loading &&
        !_state.hasUsableSnapshot) {
      return const Center(
        key: Key('mobile-library-loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (_state.loadStatus == LibraryLoadStatus.failure &&
        !_state.hasUsableSnapshot) {
      return _MobileInitialFailure(failure: _state.failure);
    }
    if (!_state.hasUsableSnapshot) {
      return const SizedBox.shrink();
    }
    final entries = projectMobileEntries(_state.visibleEntries, _mode);
    return Column(
      children: [
        _buildSearchBar(),
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
          child: entries.isEmpty
              ? _MobileEmptyState(filtered: _isFiltered)
              : _buildList(entries),
        ),
      ],
    );
  }

  /// Builds the search field row.
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('mobile-library-search'),
              controller: _searchController,
              onChanged: widget.controller.updateSearchQuery,
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search prompts',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
          IconButton(
            key: const Key('mobile-filter-button'),
            tooltip: 'Filters',
            onPressed: () => unawaited(_openFilters()),
            icon: const Icon(Icons.filter_list),
          ),
          IconButton(
            key: const Key('mobile-transfer-button'),
            tooltip: 'Transfer library',
            onPressed: () => unawaited(_openTransfer()),
            icon: const Icon(Icons.swap_horiz),
          ),
        ],
      ),
    );
  }

  /// Opens the mobile filter sheet.
  Future<void> _openFilters() {
    return showMobileFilterSheet(
      context,
      controller: widget.controller,
      mode: _mode,
      onMode: (mode) {
        if (!mounted) return;
        setState(() => _mode = mode);
      },
    );
  }

  /// Builds the retrieval list.
  Widget _buildList(List<Entry> entries) {
    return ListView.builder(
      key: const Key('mobile-library-list'),
      itemCount: entries.length,
      itemBuilder: (context, index) => _buildRow(entries[index]),
    );
  }

  /// Builds one retrieval row with separate copy and disclosure targets.
  Widget _buildRow(Entry entry) {
    final pending = _actions.isPending(entry.id);
    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: entry.title,
            hint: pending ? 'Copying' : 'Copy prompt',
            excludeSemantics: true,
            customSemanticsActions: {
              CustomSemanticsAction(
                label: entry.isFavorite
                    ? 'Remove from favorites'
                    : 'Add to favorites',
              ): () =>
                  unawaited(_handleFavorite(entry)),
              CustomSemanticsAction(
                label: entry.isArchived ? 'Restore' : 'Archive',
              ): () =>
                  unawaited(_handleArchive(entry)),
              const CustomSemanticsAction(label: 'Delete'): () =>
                  unawaited(_confirmAndDelete(entry)),
            },
            child: Builder(
              builder: (rowContext) {
                return InkWell(
                  key: Key('mobile-entry-${entry.id}'),
                  onTap: () => unawaited(_handleCopy(entry)),
                  onLongPress: () => unawaited(_showRowMenu(rowContext, entry)),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (entry.isFavorite)
                            const Icon(Icons.star_rounded, size: 18),
                          if (pending)
                            const Padding(
                              padding: EdgeInsets.only(left: 10),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Semantics(
          button: true,
          label: 'Open details for ${entry.title}',
          excludeSemantics: true,
          child: InkWell(
            key: Key('mobile-entry-disclosure-${entry.id}'),
            onTap: () => unawaited(_openDetails(entry)),
            child: const SizedBox(
              width: 48,
              height: 48,
              child: Center(child: Icon(Icons.chevron_right)),
            ),
          ),
        ),
      ],
    );
  }

  /// Toggles favorite for one entry from the mobile surface.
  Future<void> _handleFavorite(Entry entry) {
    if (_actions.isActionPending(entry.id, LibraryMutationKind.setFavorite)) {
      return Future.value();
    }
    return _actions.setFavorite(entry);
  }

  /// Toggles archive for one entry from the mobile surface.
  Future<void> _handleArchive(Entry entry) {
    if (_actions.isActionPending(entry.id, LibraryMutationKind.setArchived)) {
      return Future.value();
    }
    return _actions.setArchived(entry);
  }

  /// Confirms and deletes one entry from the mobile surface.
  Future<void> _confirmAndDelete(Entry entry) async {
    if (_actions.isActionPending(entry.id, LibraryMutationKind.deleteEntry)) {
      return;
    }
    final confirmed = await showDeleteEntryDialog(context, entry: entry);
    if (!confirmed || !mounted) {
      return;
    }
    await _actions.deleteEntry(entry);
  }

  /// Shows the long-press context menu positioned from row geometry.
  Future<void> _showRowMenu(BuildContext rowContext, Entry entry) async {
    final renderBox = rowContext.findRenderObject();
    if (renderBox is! RenderBox || !renderBox.hasSize) {
      return;
    }
    final overlay = Overlay.maybeOf(rowContext)?.context.findRenderObject();
    if (overlay is! RenderBox || !overlay.hasSize) {
      return;
    }
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        renderBox.localToGlobal(Offset.zero, ancestor: overlay),
        renderBox.localToGlobal(
          renderBox.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    final favoritePending = _actions.isActionPending(
      entry.id,
      LibraryMutationKind.setFavorite,
    );
    final archivePending = _actions.isActionPending(
      entry.id,
      LibraryMutationKind.setArchived,
    );
    final deletePending = _actions.isActionPending(
      entry.id,
      LibraryMutationKind.deleteEntry,
    );

    final action = await showMenu<_MobileRowAction>(
      context: rowContext,
      position: position,
      constraints: const BoxConstraints(minWidth: 160, maxWidth: 300),
      items: [
        PopupMenuItem<_MobileRowAction>(
          key: const Key('mobile-row-action-favorite'),
          value: _MobileRowAction.favorite,
          enabled: !favoritePending,
          child: Row(
            children: [
              Icon(
                entry.isFavorite
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  entry.isFavorite
                      ? 'Remove from favorites'
                      : 'Add to favorites',
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<_MobileRowAction>(
          key: const Key('mobile-row-action-archive'),
          value: _MobileRowAction.archive,
          enabled: !archivePending,
          child: Row(
            children: [
              Icon(
                entry.isArchived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(entry.isArchived ? 'Restore' : 'Archive')),
            ],
          ),
        ),
        PopupMenuItem<_MobileRowAction>(
          key: const Key('mobile-row-action-delete'),
          value: _MobileRowAction.delete,
          enabled: !deletePending,
          child: const Row(
            children: [
              Icon(Icons.delete_outline),
              SizedBox(width: 12),
              Expanded(child: Text('Delete')),
            ],
          ),
        ),
      ],
    );

    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case _MobileRowAction.favorite:
        unawaited(_handleFavorite(entry));
      case _MobileRowAction.archive:
        unawaited(_handleArchive(entry));
      case _MobileRowAction.delete:
        unawaited(_confirmAndDelete(entry));
    }
  }

  /// Opens the detail route for one entry.
  Future<void> _openDetails(Entry entry) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MobileEntryDetailScreen(
          entryId: entry.id,
          controller: widget.controller,
          actions: _actions,
        ),
      ),
    );
  }

  /// Runs one coalesced copy cycle for the tapped entry.
  Future<void> _handleCopy(Entry entry) async {
    final cycle = _actions.copyEntry(entry);
    if (mounted) {
      setState(() {});
    }
    MobileCopyOutcome? outcome;
    try {
      outcome = await cycle;
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
    if (!mounted || outcome == null) {
      return;
    }
    _showMessage(switch (outcome) {
      MobileCopyOutcome.copied => 'Copied',
      MobileCopyOutcome.clipboardFailure => 'The prompt could not be copied.',
    });
  }

  /// Shows one transient retrieval message.
  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Empty mobile result placeholder.
final class _MobileEmptyState extends StatelessWidget {
  const _MobileEmptyState({required this.filtered});

  final bool filtered;

  /// Builds the empty state.
  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('mobile-empty-state'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            filtered ? Icons.search_off : Icons.library_books_outlined,
            size: 42,
          ),
          const SizedBox(height: 12),
          Text(filtered ? 'No matching prompts' : 'Your library is empty'),
        ],
      ),
    );
  }
}

/// Initial mobile load failure surface.
final class _MobileInitialFailure extends StatelessWidget {
  const _MobileInitialFailure({required this.failure});

  final LibraryFailure? failure;

  /// Builds the failure message.
  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('mobile-initial-failure'),
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

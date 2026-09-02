/// Mobile library screen.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/entry.dart';
import '../../models/library_failure.dart';
import '../library_clipboard.dart';
import '../library_controller.dart';
import '../library_failure_message.dart';
import '../library_haptics.dart';
import '../library_share.dart';
import '../library_state.dart';
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
    required this.share,
    required this.haptics,
    super.key,
  });

  /// Shared application controller.
  final LibraryController controller;

  /// Exact clipboard boundary.
  final LibraryClipboard clipboard;

  /// System sharing boundary.
  final LibraryShare share;

  /// Best-effort tactile feedback boundary.
  final LibraryHaptics haptics;

  @override
  State<MobileLibraryScreen> createState() => _MobileLibraryScreenState();
}

/// Owns screen-local search, subscription, mode and actions.
final class _MobileLibraryScreenState extends State<MobileLibraryScreen> {
  late LibraryState _state;
  late final StreamSubscription<LibraryState> _subscription;
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
    _subscription = widget.controller.states.listen((state) {
      if (!mounted) return;
      setState(() => _state = state);
    });
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
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
    return Scaffold(body: SafeArea(child: _buildBody()));
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
            child: InkWell(
              key: Key('mobile-entry-${entry.id}'),
              onTap: () => unawaited(_handleCopy(entry)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
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

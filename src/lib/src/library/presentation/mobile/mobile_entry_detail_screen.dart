/// Mobile entry detail screen.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/entry.dart';
import '../../models/library_failure.dart';
import '../delete_entry_dialog.dart';
import '../library_controller.dart';
import '../library_failure_message.dart';
import '../library_share.dart';
import '../library_state.dart';
import 'mobile_entry_editor_screen.dart';
import 'mobile_library_actions.dart';

/// Scroll-safe mobile entry detail route.
final class MobileEntryDetailScreen extends StatefulWidget {
  /// Creates mobile detail screen.
  const MobileEntryDetailScreen({
    required this.entryId,
    required this.controller,
    required this.actions,
    super.key,
  });

  /// Identifier of the presented entry.
  final String entryId;

  /// Shared application controller.
  final LibraryController controller;

  /// Shared retrieval actions.
  final MobileLibraryActions actions;

  @override
  State<MobileEntryDetailScreen> createState() =>
      _MobileEntryDetailScreenState();
}

/// Owns the detail subscription and route lifetime.
final class _MobileEntryDetailScreenState
    extends State<MobileEntryDetailScreen> {
  late LibraryState _state;
  late final StreamSubscription<LibraryState> _subscription;
  final GlobalKey _shareAnchorKey = GlobalKey();
  bool _popRequested = false;

  @override
  void initState() {
    super.initState();
    _state = widget.controller.state;
    _subscription = widget.controller.states.listen(_handleState);
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }

  /// Applies a state transition and closes the route for a removed entry.
  void _handleState(LibraryState state) {
    if (!mounted) {
      return;
    }
    setState(() => _state = state);
    if (_resolveEntry() == null && !_popRequested) {
      _popRequested = true;
      unawaited(Navigator.of(context).maybePop());
    }
  }

  /// Resolves the presented entry from the current snapshot.
  Entry? _resolveEntry() {
    final snapshot = _state.snapshot;
    if (snapshot == null) {
      return null;
    }
    for (final entry in snapshot.entries) {
      if (entry.id == widget.entryId) {
        return entry;
      }
    }
    return null;
  }

  /// Builds the detail route.
  @override
  Widget build(BuildContext context) {
    final entry = _resolveEntry();
    if (entry == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final snapshot = _state.snapshot!;
    final category = entry.categoryId == null
        ? null
        : snapshot.categoryById[entry.categoryId];
    final tags = snapshot.tagsForEntry[entry.id] ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: Text(entry.title),
        actions: [
          IconButton(
            key: const Key('mobile-detail-edit'),
            tooltip: 'Edit',
            onPressed:
                _isMutationActive(LibraryMutationKind.updateEntry, entry.id)
                ? null
                : () => unawaited(_editEntry(entry)),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            key: const Key('mobile-detail-favorite'),
            tooltip: entry.isFavorite
                ? 'Remove from favorites'
                : 'Add to favorites',
            onPressed:
                _isMutationActive(LibraryMutationKind.setFavorite, entry.id)
                ? null
                : () => unawaited(_setFavorite(entry)),
            icon: Icon(
              entry.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
            ),
          ),
          IconButton(
            key: const Key('mobile-detail-archive'),
            tooltip: entry.isArchived ? 'Restore' : 'Archive',
            onPressed:
                _isMutationActive(LibraryMutationKind.setArchived, entry.id)
                ? null
                : () => unawaited(_setArchived(entry)),
            icon: Icon(
              entry.isArchived
                  ? Icons.unarchive_outlined
                  : Icons.archive_outlined,
            ),
          ),
          IconButton(
            key: const Key('mobile-detail-delete'),
            tooltip: 'Delete',
            onPressed:
                _isMutationActive(LibraryMutationKind.deleteEntry, entry.id)
                ? null
                : () => unawaited(_deleteEntry(entry)),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_state.failure != null)
              MaterialBanner(
                key: const Key('mobile-detail-failure-banner'),
                content: Text(messageForLibraryFailure(_state.failure!)),
                actions: [
                  TextButton(
                    onPressed: widget.controller.dismissFailure,
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
            Expanded(
              child: SingleChildScrollView(
                key: const Key('mobile-detail-scroll'),
                padding: const EdgeInsets.all(16),
                child: Column(
                  key: const Key('mobile-detail-body'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (category != null || tags.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (category != null)
                            Chip(label: Text(category.name)),
                          for (final tag in tags) Chip(label: Text(tag.name)),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    SelectableText(
                      entry.body,
                      style: const TextStyle(fontSize: 15, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _lastCopiedLabel(entry),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ConstrainedBox(
                      key: _shareAnchorKey,
                      constraints: const BoxConstraints(minHeight: 48),
                      child: OutlinedButton.icon(
                        key: const Key('mobile-detail-share'),
                        onPressed: () => unawaited(_handleShare(entry)),
                        icon: widget.actions.isSharePending(entry.id)
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.share_outlined),
                        label: const Text('Share'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: FilledButton.icon(
                        key: const Key('mobile-detail-copy'),
                        onPressed: () => unawaited(_handleCopy(entry)),
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('Copy'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Whether one entry mutation is active.
  bool _isMutationActive(LibraryMutationKind kind, String entryId) {
    return _state.isMutationActive(LibraryMutationKey(kind, entityId: entryId));
  }

  /// Opens the entry editor route.
  Future<void> _editEntry(Entry entry) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MobileEntryEditorScreen(
          controller: widget.controller,
          entry: entry,
        ),
      ),
    );
  }

  /// Toggles the favorite state.
  Future<void> _setFavorite(Entry entry) {
    return _runMutation(
      () => widget.controller.setFavorite(
        entry.id,
        isFavorite: !entry.isFavorite,
      ),
    );
  }

  /// Toggles the archive state.
  Future<void> _setArchived(Entry entry) {
    return _runMutation(
      () => widget.controller.setArchived(
        entry.id,
        isArchived: !entry.isArchived,
      ),
    );
  }

  /// Confirms and deletes one entry.
  Future<void> _deleteEntry(Entry entry) async {
    final confirmed = await showDeleteEntryDialog(context, entry: entry);
    if (!confirmed || !mounted) {
      return;
    }
    await _runMutation(() => widget.controller.deleteEntry(entry.id));
  }

  /// Runs a mutation through the retained failure banner.
  Future<void> _runMutation(Future<void> Function() operation) async {
    try {
      await operation();
    } on LibraryFailure {
      // The controller retains a non-sensitive failure for the banner.
    }
  }

  /// Runs one coalesced share cycle from the detail route.
  Future<void> _handleShare(Entry entry) async {
    final cycle = widget.actions.shareEntry(entry, anchor: _shareAnchor());
    if (mounted) {
      setState(() {});
    }
    LibraryShareOutcome? outcome;
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
    final message = switch (outcome) {
      LibraryShareOutcome.selected || LibraryShareOutcome.dismissed => null,
      LibraryShareOutcome.unavailable =>
        'Sharing is not available on this device.',
      LibraryShareOutcome.invocationFailure =>
        'The prompt could not be shared.',
    };
    if (message != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// Resolves the share button rectangle.
  Rect? _shareAnchor() {
    final renderObject = _shareAnchorKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }
    final anchor = renderObject.localToGlobal(Offset.zero) & renderObject.size;
    return anchor.isEmpty ? null : anchor;
  }

  /// Runs one coalesced copy cycle from the detail route.
  Future<void> _handleCopy(Entry entry) async {
    final outcome = await widget.actions.copyEntry(entry);
    if (!mounted || outcome == null) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(switch (outcome) {
            MobileCopyOutcome.copied => 'Copied',
            MobileCopyOutcome.clipboardFailure =>
              'The prompt could not be copied.',
          }),
        ),
      );
  }
}

/// Describes the last copy of one entry.
String _lastCopiedLabel(Entry entry) {
  final copied = entry.lastCopiedAt;
  if (copied == null) {
    return 'Not copied yet';
  }
  return 'Last copied ${_formatTimestamp(copied)}';
}

/// Formats one UTC timestamp for display.
String _formatTimestamp(DateTime value) {
  final utc = value.toUtc();
  String pad(int part) => part.toString().padLeft(2, '0');
  return '${utc.year}-${pad(utc.month)}-${pad(utc.day)} '
      '${pad(utc.hour)}:${pad(utc.minute)}';
}

/// Mobile entry detail screen.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/entry.dart';
import '../library_controller.dart';
import '../library_state.dart';
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
    if (_resolveEntry() == null) {
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
      appBar: AppBar(title: Text(entry.title)),
      body: SafeArea(
        child: Column(
          children: [
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
              child: SizedBox(
                width: double.infinity,
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
    );
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

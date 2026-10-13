/// Adaptive transfer operation screen.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../transfer/library_transfer_plan.dart';
import '../library_document_files.dart';
import '../library_failure_message.dart';
import 'library_transfer_controller.dart';
import 'library_transfer_state.dart';

/// Presents the managed transfer operation across window sizes.
final class LibraryTransferScreen extends StatefulWidget {
  /// Creates the transfer screen.
  const LibraryTransferScreen({
    required this.transfer,
    this.onFinished,
    super.key,
  });

  /// Owned operation controller.
  final LibraryTransferController transfer;

  /// Called when the user closes a finished operation summary.
  final VoidCallback? onFinished;

  @override
  State<LibraryTransferScreen> createState() => _LibraryTransferScreenState();
}

/// Maintains the screen binding to the controller.
final class _LibraryTransferScreenState extends State<LibraryTransferScreen> {
  late LibraryTransferState _state;
  late StreamSubscription<LibraryTransferState> _subscription;
  String? _shutdownNotice;

  @override
  void initState() {
    super.initState();
    _state = widget.transfer.state;
    _subscription = _listenTo(widget.transfer);
  }

  @override
  void didUpdateWidget(covariant LibraryTransferScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transfer != widget.transfer) {
      unawaited(_subscription.cancel());
      _state = widget.transfer.state;
      _subscription = _listenTo(widget.transfer);
    }
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }

  StreamSubscription<LibraryTransferState> _listenTo(
    LibraryTransferController controller,
  ) {
    return controller.states.listen((state) {
      if (!mounted) return;
      setState(() => _state = state);
    });
  }

  /// Merges one row choice into the latest request for the current source.
  ///
  /// The latest request is read at tap time, so a second choice made before
  /// the first recalculation publishes keeps both choices.
  void _choose(RaycastSelection Function(RaycastSelection latest) change) {
    _runOperationGuarded(
      () => widget.transfer.updateSelection(
        change(widget.transfer.raycastSelection),
      ),
    );
  }

  /// Runs one operation-opening action, reporting a shutdown refusal.
  ///
  /// Only [LibraryTransferShuttingDown] is translated into the visible
  /// notice; every other error keeps propagating to its owner.
  Future<void> _runOperationGuarded(Future<void> Function() action) async {
    try {
      await action();
    } on LibraryTransferShuttingDown {
      if (mounted) {
        setState(() {
          _shutdownNotice =
              'The application is closing. The operation was not started.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 640;
        final body = Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_shutdownNotice != null)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight / 3,
                  ),
                  child: SingleChildScrollView(child: _buildShutdownNotice()),
                ),
              Expanded(
                child: switch (_state) {
                  LibraryTransferIdle() => _scroll(_buildIdle(context)),
                  LibraryTransferExportReady() => _scroll(
                    _buildExportReady(context),
                  ),
                  LibraryTransferRestoreReview done => _buildRestoreReview(
                    done.plan,
                  ),
                  LibraryTransferRaycastReview done => _buildRaycastReview(
                    done.plan,
                  ),
                  LibraryTransferBackupRequired done => _scroll(
                    _buildBackupRequired(done),
                  ),
                  LibraryTransferBackupSaved done => _scroll(
                    _buildBackupSaved(done),
                  ),
                  LibraryTransferBackupVerified done => _scroll(
                    _buildBackupVerified(done),
                  ),
                  LibraryTransferStale() => _scroll(
                    _buildMessage(
                      context,
                      'The library changed during the operation.'
                      ' Start a new review to continue.',
                    ),
                  ),
                  LibraryTransferApplying() => _scroll(
                    _buildMessage(context, 'Applying the operation…'),
                  ),
                  LibraryTransferRestoreDone done => _scroll(
                    _buildRestoreDone(done),
                  ),
                  LibraryTransferImportDone done => _scroll(
                    _buildImportDone(done),
                  ),
                  LibraryTransferUnsupportedFile() => _scroll(
                    _buildUnsupported(context),
                  ),
                  LibraryTransferFailed() => _scroll(_buildFailed(context)),
                },
              ),
            ],
          ),
        );
        return wide
            ? Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: body,
                ),
              )
            : body;
      },
    );
  }

  /// Wraps fixed-height columns so large text scales scroll instead of
  /// overflowing.
  Widget _scroll(Widget child) => SingleChildScrollView(child: child);

  /// Builds the live-region shutdown refusal.
  Widget _buildShutdownNotice() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        liveRegion: true,
        child: Text(
          _shutdownNotice!,
          key: const Key('transfer-shutdown-notice'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }

  Widget _buildIdle(BuildContext context) {
    return Column(
      key: const Key('transfer-idle'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Transfer library', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('transfer-export-json'),
          onPressed: () => _runOperationGuarded(
            () => widget.transfer.prepareExport(DocumentExportKind.json),
          ),
          icon: const Icon(Icons.file_download_outlined),
          label: const Text('Export JSON'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const Key('transfer-export-markdown'),
          onPressed: () => _runOperationGuarded(
            () => widget.transfer.prepareExport(DocumentExportKind.markdown),
          ),
          icon: const Icon(Icons.description_outlined),
          label: const Text('Export Markdown'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('transfer-import'),
          onPressed: () =>
              _runOperationGuarded(() => widget.transfer.startImport()),
          icon: const Icon(Icons.file_upload_outlined),
          label: const Text('Import from file…'),
        ),
      ],
    );
  }

  Widget _buildExportReady(BuildContext context) {
    final state = _state as LibraryTransferExportReady;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Export library', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(
          state.fileName,
          key: const Key('transfer-export-name'),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        Text(state.kind == DocumentExportKind.json ? 'JSON' : 'Markdown'),
        const SizedBox(height: 12),
        Text(
          'Not included: Search state, Selection, Drafts, Global shortcut,'
          ' Platform settings.',
          key: const Key('transfer-export-exclusions'),
        ),
        Text('Each document is limited to 32 MiB.'),
        const Text('This file contains the unencrypted texts of your library.'),
        if (state.savedPath != null) ...[
          const SizedBox(height: 8),
          Text('Saved. Path: ${state.savedPath}'),
        ],
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('transfer-export-save'),
          onPressed: () =>
              _runOperationGuarded(() => widget.transfer.exportPrepared()),
          child: const Text('Save…'),
        ),
        const SizedBox(height: 8),
        TextButton(
          key: const Key('transfer-export-cancel'),
          onPressed: () => widget.transfer.cancel(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  /// Presents the full replacement preview with scrollable actions.
  Widget _buildRestoreReview(LibraryRestorePlan plan) {
    final differences = [
      ..._differenceLines('Entry', plan.entries),
      ..._differenceLines('Category', plan.categories),
      ..._differenceLines('Tag', plan.tags),
    ];
    return _reviewList(
      key: const Key('transfer-restore-differences'),
      heading: Text(
        'Review restore',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      count: differences.isEmpty ? 1 : differences.length,
      rowBuilder: (context, index) {
        if (differences.isEmpty) {
          return const Text('The document matches the current library.');
        }
        final row = differences[index];
        final difference = row.$2;
        final before = difference.before;
        final after = difference.after;
        return ExpansionTile(
          key: ValueKey(row.$1),
          title: Text(row.$1),
          subtitle: Text(difference.fields.join(', ')),
          children: [
            // Every field of the entity is shown so the complete incoming and
            // outgoing state can be checked; a modification marks only the
            // fields whose values actually differ.
            for (final field in (before ?? after)!.keys)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _fieldLabel(
                      field,
                      changed:
                          difference.kind == EntityChangeKind.modified &&
                          difference.fields.contains(field),
                    ),
                    if (before != null)
                      SelectableText('Before: ${jsonEncode(before[field])}'),
                    if (after != null)
                      SelectableText('After: ${jsonEncode(after[field])}'),
                  ],
                ),
              ),
          ],
        );
      },
      continueKey: const Key('transfer-restore-continue'),
    );
  }

  /// Names one entity field; a changed field is marked in text, not color.
  Widget _fieldLabel(String field, {required bool changed}) {
    if (!changed) return Text(field);
    return Text(
      '$field (changed)',
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.error,
      ),
    );
  }

  /// Keeps lists lazy while allowing headings and actions to scroll.
  Widget _reviewList({
    required Key key,
    required Widget heading,
    required int count,
    required IndexedWidgetBuilder rowBuilder,
    required Key continueKey,
  }) {
    return CustomScrollView(
      key: key,
      slivers: [
        SliverToBoxAdapter(child: heading),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        SliverList(
          delegate: SliverChildBuilderDelegate(rowBuilder, childCount: count),
        ),
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              FilledButton(
                key: continueKey,
                onPressed: () => _runOperationGuarded(
                  () => widget.transfer.continueFromReview(),
                ),
                child: const Text('Continue…'),
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const Key('transfer-review-cancel'),
                onPressed: () => widget.transfer.cancel(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<(String, EntityDifference)> _differenceLines(
    String collection,
    List<EntityDifference> rows,
  ) {
    return [
      for (final row in rows)
        if (row.kind != EntityChangeKind.unchanged)
          ('$collection ${row.kind.name}: ${row.id}', row),
    ];
  }

  /// Presents the source review with explicit decisions and predictions.
  Widget _buildRaycastReview(RaycastImportPlan plan) {
    final state = _state as LibraryTransferRaycastReview;
    final selection = state.selection ?? RaycastSelection();
    return _reviewList(
      key: const Key('transfer-raycast-rows'),
      heading: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Review import', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Valid: ${plan.validCount}, Will add: ${plan.predictedAdded},'
            ' Skipped: ${plan.predictedSkipped}, Warnings: ${plan.warningRowCount}',
          ),
        ],
      ),
      count: plan.rows.length,
      rowBuilder: (context, index) =>
          _buildRaycastRow(plan.rows[index], selection),
      continueKey: const Key('transfer-import-continue'),
    );
  }

  /// Presents source diagnostics and explicit row choices.
  Widget _buildRaycastRow(PlannedRaycastRow row, RaycastSelection selection) {
    final source = row.source;
    final snippet = source.snippet;
    final index = source.index;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CheckboxListTile(
            key: Key('transfer-exclude-$index'),
            dense: true,
            value: !selection.excludedIndices.contains(index),
            // Each tap toggles the latest requested choice. The checkbox value
            // comes from the last published review, so a second tap before
            // that review arrives would otherwise repeat the first decision.
            onChanged: snippet == null
                ? null
                : (_) => _choose(
                    (latest) => RaycastSelection(
                      excludedIndices: _toggled(latest.excludedIndices, index),
                      addAsNewIndices: latest.addAsNewIndices,
                      acceptedUnknownFieldIndices:
                          latest.acceptedUnknownFieldIndices,
                    ),
                  ),
            title: Text(snippet?.title ?? 'Invalid row ${index + 1}'),
            subtitle: Text(_outcomeLabel(row.outcome)),
          ),
          if (snippet != null && snippet.originalTitle != snippet.title)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                'Title: ${jsonEncode(snippet.originalTitle)} → ${jsonEncode(snippet.title)}',
              ),
            ),
          if (source.failure != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text('Row ${index + 1}: ${source.failure!.code.name}'),
            ),
          if (source.hasPlaceholderSyntax)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                'Literal placeholders are kept as text and never executed.',
              ),
            ),
          if (source.unknownFields.isNotEmpty)
            CheckboxListTile(
              key: Key('transfer-unknown-$index'),
              title: Text(
                'Import supported fields only; omit: ${source.unknownFields.join(', ')}',
              ),
              value: selection.acceptedUnknownFieldIndices.contains(index),
              onChanged: snippet == null
                  ? null
                  : (_) => _choose(
                      (latest) => RaycastSelection(
                        excludedIndices: latest.excludedIndices,
                        addAsNewIndices: latest.addAsNewIndices,
                        acceptedUnknownFieldIndices: _toggled(
                          latest.acceptedUnknownFieldIndices,
                          index,
                        ),
                      ),
                    ),
            ),
          if (row.outcome == ImportRowOutcome.conflict ||
              selection.addAsNewIndices.contains(index))
            CheckboxListTile(
              key: Key('transfer-add-new-$index'),
              title: const Text(
                'Add as a separate entry without replacing existing entries',
              ),
              value: selection.addAsNewIndices.contains(index),
              onChanged: (_) => _choose(
                (latest) => RaycastSelection(
                  excludedIndices: latest.excludedIndices,
                  addAsNewIndices: _toggled(latest.addAsNewIndices, index),
                  acceptedUnknownFieldIndices:
                      latest.acceptedUnknownFieldIndices,
                ),
              ),
            ),
          if (snippet != null)
            ExpansionTile(
              key: Key('transfer-source-$index'),
              title: const Text('Preview exact text and keyword'),
              children: [
                SelectableText('Text: ${jsonEncode(snippet.body)}'),
                SelectableText('Keyword: ${jsonEncode(snippet.keyword)}'),
              ],
            ),
        ],
      ),
    );
  }

  /// Flips one row index in a copy of the requested choices.
  Set<int> _toggled(Set<int> values, int index) {
    final next = {...values};
    if (!next.remove(index)) next.add(index);
    return next;
  }

  /// Names each exclusive disposition for the user.
  String _outcomeLabel(ImportRowOutcome outcome) => switch (outcome) {
    ImportRowOutcome.selected => 'Selected for addition',
    ImportRowOutcome.duplicate => 'Skipped: exact duplicate',
    ImportRowOutcome.conflict => 'Skipped: conflicting title or keyword',
    ImportRowOutcome.invalid => 'Skipped: invalid source row',
    ImportRowOutcome.userSkipped => 'Skipped by your choice',
    ImportRowOutcome.unsupportedFields =>
      'Skipped: unknown fields need your consent',
  };

  Widget _buildBackupRequired(LibraryTransferBackupRequired state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Back up the current library',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Text(
          'Before replacing, the current library is saved outside the'
          ' application as "${state.backupName}". You will re-open this'
          ' file to verify the copy before anything is applied.',
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('transfer-backup-save'),
          onPressed: () =>
              _runOperationGuarded(() => widget.transfer.createBackupCopy()),
          child: const Text('Save backup copy…'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => widget.transfer.cancel(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildBackupSaved(LibraryTransferBackupSaved state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Backup saved', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(
          'The copy "${state.backupName}" is saved.'
          ' Re-open it to prove the backup reads back exactly.',
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('transfer-backup-verify'),
          onPressed: () =>
              _runOperationGuarded(() => widget.transfer.verifyBackupCopy()),
          child: const Text('Verify by re-opening…'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => widget.transfer.cancel(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildBackupVerified(LibraryTransferBackupVerified state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Ready to apply', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(
          state.backupName == null
              ? 'The current library is empty, so no backup copy is required.'
              : 'The copy "${state.backupName}" was re-read and matches the'
                    ' reviewed state exactly.',
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('transfer-apply'),
          onPressed: () => _runOperationGuarded(() => widget.transfer.apply()),
          child: const Text('Apply'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => widget.transfer.cancel(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  /// Closes a finished summary and reports it to the host route.
  void _finishSummary() {
    widget.transfer.cancel();
    widget.onFinished?.call();
  }

  Widget _buildRestoreDone(LibraryTransferRestoreDone state) {
    return Column(
      key: const Key('transfer-restore-done'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Library restored', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(
          'Changed entries: ${state.entriesChanged}, categories:'
          ' ${state.categoriesChanged}, tags: ${state.tagsChanged}.',
        ),
        if (state.backupName.isNotEmpty)
          Text('The backup copy is kept as "${state.backupName}".'),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('transfer-restore-done-button'),
          onPressed: _finishSummary,
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _buildImportDone(LibraryTransferImportDone state) {
    final added = state.outcomeCounts[ImportRowOutcome.selected] ?? 0;
    final skipped =
        state.outcomeCounts.values.fold<int>(0, (sum, count) => sum + count) -
        added;
    return Column(
      key: const Key('transfer-import-done'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Import finished', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(
          'Added: $added, Skipped: $skipped,'
          ' Warnings: ${state.warningRowCount}.',
        ),
        for (final outcome in ImportRowOutcome.values)
          if (outcome != ImportRowOutcome.selected)
            Text(
              '${_outcomeLabel(outcome)}: ${state.outcomeCounts[outcome] ?? 0}',
            ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('transfer-import-done-button'),
          onPressed: _finishSummary,
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _buildUnsupported(BuildContext context) {
    final state = _state as LibraryTransferUnsupportedFile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Import file', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(
          key: const Key('transfer-unsupported'),
          'The picked file is not a supported transfer document.'
          ' Reason: ${state.failure.code.name}.',
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => widget.transfer.cancel(),
          child: const Text('Back'),
        ),
      ],
    );
  }

  Widget _buildFailed(BuildContext context) {
    final state = _state as LibraryTransferFailed;
    final hasReview = widget.transfer.canResumeReview;
    return Column(
      key: const Key('transfer-failed'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Transfer failed', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(
          'The transfer operation could not be completed.'
          ' Nothing was partially applied.',
        ),
        Semantics(liveRegion: true, child: Text(_failureMessage(state))),
        const SizedBox(height: 16),
        if (hasReview)
          FilledButton(
            key: const Key('transfer-back-to-review'),
            onPressed: () => widget.transfer.resumeReview(),
            child: const Text('Back to review'),
          ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => widget.transfer.cancel(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  /// Explains the failure without exposing document contents.
  String _failureMessage(LibraryTransferFailed state) {
    if (state.libraryFailure != null) {
      return messageForLibraryFailure(state.libraryFailure!);
    }
    if (state.failure != null) {
      return 'The document was rejected: ${state.failure!.code.name}.';
    }
    return switch (state.code) {
      DocumentFileFailureCode.existingFile => 'The file already exists. Choose a different name; the existing file was not overwritten.',
      DocumentFileFailureCode.limitExceeded =>
        'The document exceeds the 32 MiB limit.',
      DocumentFileFailureCode.readFailed => 'The file could not be read. Check its availability and choose it again.',
      DocumentFileFailureCode.writeFailed => 'The file could not be saved. Check free space and access to the destination.',
      DocumentFileFailureCode.verifyFailed => 'The copy does not match the reviewed library. Create and verify a new backup.',
      DocumentFileFailureCode.invalidArguments =>
        'The file name or document type was rejected. Choose another name.',
      DocumentFileFailureCode.unknownOutcome =>
        'The system returned an unexpected result. Start the operation again.',
      null => 'File transfer is unavailable. Start the operation again.',
    };
  }

  Widget _buildMessage(BuildContext context, String message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(message),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => widget.transfer.cancel(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

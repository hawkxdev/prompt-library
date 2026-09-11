/// Adaptive transfer operation screen.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../transfer/library_transfer_plan.dart';
import '../library_document_files.dart';
import 'library_transfer_controller.dart';
import 'library_transfer_state.dart';

/// Presents the managed transfer operation across window sizes.
final class LibraryTransferScreen extends StatefulWidget {
  /// Creates the transfer screen.
  const LibraryTransferScreen({required this.transfer, super.key});

  /// Owned operation controller.
  final LibraryTransferController transfer;

  @override
  State<LibraryTransferScreen> createState() => _LibraryTransferScreenState();
}

/// Maintains the screen binding to the controller.
final class _LibraryTransferScreenState extends State<LibraryTransferScreen> {
  late LibraryTransferState _state;
  late StreamSubscription<LibraryTransferState> _subscription;
  final Set<int> _excluded = {};
  final Set<int> _addAsNew = {};
  final Set<int> _acceptedUnknown = {};

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

  void _toggle(Set<int> set, int index) {
    setState(() {
      set.contains(index) ? set.remove(index) : set.add(index);
    });
    widget.transfer.updateSelection(
      RaycastSelection(
        excludedIndices: _excluded,
        addAsNewIndices: _addAsNew,
        acceptedUnknownFieldIndices: _acceptedUnknown,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 640;
        final body = Padding(
          padding: const EdgeInsets.all(16),
          child: switch (_state) {
            LibraryTransferIdle() => _scroll(_buildIdle(context)),
            LibraryTransferExportReady() => _scroll(_buildExportReady(context)),
            LibraryTransferRestoreReview done => _buildRestoreReview(done.plan),
            LibraryTransferRaycastReview done => _buildRaycastReview(done.plan),
            LibraryTransferBackupRequired done => _scroll(
              _buildBackupRequired(done),
            ),
            LibraryTransferBackupSaved done => _scroll(_buildBackupSaved(done)),
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
            LibraryTransferApplying() => _buildMessage(
              context,
              'Applying the operation…',
            ),
            LibraryTransferRestoreDone done => _scroll(_buildRestoreDone(done)),
            LibraryTransferImportDone done => _scroll(_buildImportDone(done)),
            LibraryTransferUnsupportedFile() => _scroll(
              _buildUnsupported(context),
            ),
            LibraryTransferFailed() => _scroll(_buildFailed(context)),
          },
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

  Widget _buildIdle(BuildContext context) {
    return Column(
      key: const Key('transfer-idle'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Transfer library', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('transfer-export-json'),
          onPressed: () =>
              widget.transfer.prepareExport(DocumentExportKind.json),
          icon: const Icon(Icons.file_download_outlined),
          label: const Text('Export JSON'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const Key('transfer-export-markdown'),
          onPressed: () =>
              widget.transfer.prepareExport(DocumentExportKind.markdown),
          icon: const Icon(Icons.description_outlined),
          label: const Text('Export Markdown'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('transfer-import'),
          onPressed: () => widget.transfer.startImport(),
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
        if (state.savedPath != null) ...[
          const SizedBox(height: 8),
          Text('Saved. Path: ${state.savedPath}'),
        ],
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('transfer-export-save'),
          onPressed: () => widget.transfer.exportPrepared(),
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

  Widget _buildRestoreReview(LibraryRestorePlan plan) {
    final differences = [
      ..._differenceLines('Entry', plan.entries),
      ..._differenceLines('Category', plan.categories),
      ..._differenceLines('Tag', plan.tags),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Review restore', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Expanded(
          child: differences.isEmpty
              ? ListView(
                  key: const Key('transfer-restore-differences'),
                  children: const [
                    Text('The document matches the current library.'),
                  ],
                )
              : ListView.builder(
                  key: const Key('transfer-restore-differences'),
                  itemCount: differences.length,
                  itemBuilder: (context, index) {
                    final row = differences[index];
                    return ListTile(
                      dense: true,
                      title: Text(row.$1),
                      subtitle: row.$2 == null ? null : Text(row.$2!),
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('transfer-restore-continue'),
          onPressed: () => widget.transfer.continueFromReview(),
          child: const Text('Continue…'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => widget.transfer.cancel(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  List<(String, String?)> _differenceLines(
    String collection,
    List<EntityDifference> rows,
  ) {
    return [
      for (final row in rows)
        if (row.kind != EntityChangeKind.unchanged)
          (
            '$collection ${row.kind.name}: ${row.id}',
            row.fields.isEmpty ? null : row.fields.join(', '),
          ),
    ];
  }

  Widget _buildRaycastReview(RaycastImportPlan plan) {
    final counts = plan.outcomeCounts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Review import', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Added: ${counts[ImportRowOutcome.selected]},'
          ' Skipped: ${plan.predictedSkipped},'
          ' Warnings: ${plan.warningRowCount}',
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            key: const Key('transfer-raycast-rows'),
            itemCount: plan.rows.length,
            itemBuilder: (context, index) {
              final row = plan.rows[index];
              return CheckboxListTile(
                dense: true,
                value: row.outcome == ImportRowOutcome.selected,
                onChanged: row.source.snippet == null
                    ? null
                    : (_) => _toggle(_excluded, row.source.index),
                title: Text(row.source.snippet?.title ?? 'Invalid row'),
                subtitle: Text(row.outcome.name),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('transfer-import-continue'),
          onPressed: () => widget.transfer.continueFromReview(),
          child: const Text('Continue…'),
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
          onPressed: () => widget.transfer.createBackupCopy(),
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
          onPressed: () => widget.transfer.verifyBackupCopy(),
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
          onPressed: () => widget.transfer.apply(),
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
        Text('The backup copy is kept as "${state.backupName}".'),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => widget.transfer.cancel(),
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
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => widget.transfer.cancel(),
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
    final hasReview = state.libraryFailure != null;
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

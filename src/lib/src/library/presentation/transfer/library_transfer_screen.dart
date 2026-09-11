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
            LibraryTransferIdle() => _buildIdle(context),
            LibraryTransferExportReady() => _buildExportReady(context),
            LibraryTransferRestoreReview(:final plan) => _buildRestoreReview(
              plan,
            ),
            LibraryTransferRaycastReview(:final plan) => _buildRaycastReview(
              plan,
            ),
            LibraryTransferBackupRequired(:final backupName) => _buildMessage(
              context,
              'A verified backup copy is required: $backupName',
            ),
            LibraryTransferBackupSaved(:final backupName) => _buildMessage(
              context,
              'Backup saved as $backupName; now re-open it to verify.',
            ),
            LibraryTransferBackupVerified(:final backupName) => _buildMessage(
              context,
              'Backup $backupName verified. Confirm to apply.',
            ),
            LibraryTransferStale() => _buildMessage(
              context,
              'The library changed during the operation.'
              ' Start a new review to continue.',
            ),
            LibraryTransferApplying() => _buildMessage(
              context,
              'Applying the operation…',
            ),
            LibraryTransferRestoreDone() => _buildMessage(
              context,
              'Library restored.',
            ),
            LibraryTransferImportDone() => _buildMessage(
              context,
              'Import finished.',
            ),
            LibraryTransferUnsupportedFile() => _buildUnsupported(context),
            LibraryTransferFailed() => _buildMessage(
              context,
              'The transfer operation failed.',
            ),
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
          onPressed: () => widget.transfer.cancel(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildRestoreReview(LibraryRestorePlan plan) {
    final differences = <Widget>[];
    differences.addAll(_differenceLines('Entry', plan.entries));
    differences.addAll(_differenceLines('Category', plan.categories));
    differences.addAll(_differenceLines('Tag', plan.tags));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Review restore', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            key: const Key('transfer-restore-differences'),
            children: differences.isEmpty
                ? const [Text('The document matches the current library.')]
                : differences,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('transfer-restore-continue'),
          onPressed: () {},
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

  List<Widget> _differenceLines(
    String collection,
    List<EntityDifference> rows,
  ) {
    return [
      for (final row in rows)
        if (row.kind != EntityChangeKind.unchanged)
          ListTile(
            dense: true,
            title: Text('$collection ${row.kind.name}: ${row.id}'),
            subtitle: row.fields.isEmpty ? null : Text(row.fields.join(', ')),
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
          child: ListView(
            key: const Key('transfer-raycast-rows'),
            children: [
              for (final row in plan.rows)
                CheckboxListTile(
                  dense: true,
                  value: row.outcome == ImportRowOutcome.selected,
                  onChanged: row.source.snippet == null
                      ? null
                      : (_) => _toggle(_excluded, row.source.index),
                  title: Text(row.source.snippet?.title ?? 'Invalid row'),
                  subtitle: Text(row.outcome.name),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('transfer-import-continue'),
          onPressed: () {},
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

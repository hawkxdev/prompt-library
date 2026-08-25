/// Library detail pane.
library;

import 'package:flutter/material.dart';

import '../models/entry.dart';
import '../models/library_snapshot.dart';

/// Selected prompt detail.
final class LibraryDetail extends StatelessWidget {
  /// Creates detail pane.
  const LibraryDetail({
    required this.entry,
    required this.snapshot,
    required this.onCopy,
    required this.onEdit,
    required this.onFavorite,
    required this.onArchive,
    required this.onDelete,
    super.key,
  });

  /// Selected entry.
  final Entry entry;

  /// Current snapshot.
  final LibrarySnapshot snapshot;

  /// Action callbacks.
  final VoidCallback onCopy;
  final VoidCallback? onEdit;
  final VoidCallback? onFavorite;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final category = entry.categoryId == null
        ? null
        : snapshot.categoryById[entry.categoryId];
    final tags = snapshot.tagsForEntry[entry.id] ?? const [];
    return ColoredBox(
      color: const Color(0xFFFFFFFF),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                Tooltip(
                  message: entry.isFavorite
                      ? 'Remove from favorites'
                      : 'Add to favorites',
                  child: IconButton(
                    onPressed: onFavorite,
                    icon: Icon(
                      entry.isFavorite
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                    ),
                  ),
                ),
                Tooltip(
                  message: entry.isArchived ? 'Restore' : 'Archive',
                  child: IconButton(
                    onPressed: onArchive,
                    icon: Icon(
                      entry.isArchived
                          ? Icons.unarchive_outlined
                          : Icons.archive_outlined,
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Delete',
                  child: IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (category != null) Chip(label: Text(category.name)),
                for (final tag in tags) Chip(label: Text(tag.name)),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Color(0xFF315E9E), width: 4),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(left: 18, right: 8),
                  child: SelectableText(
                    entry.body,
                    style: const TextStyle(fontSize: 14, height: 1.55),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copy'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

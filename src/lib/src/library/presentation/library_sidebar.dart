/// Library navigation sidebar.
library;

import 'package:flutter/material.dart';

import '../models/library_snapshot.dart';
import 'library_filter.dart';

/// Scope and taxonomy navigation.
final class LibrarySidebar extends StatelessWidget {
  /// Creates sidebar.
  const LibrarySidebar({
    required this.snapshot,
    required this.filter,
    required this.onScope,
    required this.onCategory,
    required this.onManageTaxonomy,
    super.key,
  });

  final LibrarySnapshot snapshot;
  final LibraryFilter filter;
  final ValueChanged<LibraryFilterScope> onScope;
  final ValueChanged<String?> onCategory;
  final VoidCallback onManageTaxonomy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE7ECF1),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(10, 18, 10, 12),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'LIBRARY',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          const SizedBox(height: 6),
          _scopeTile(
            'All prompts',
            Icons.library_books_outlined,
            LibraryFilterScope.active,
          ),
          _scopeTile(
            'Favorites',
            Icons.star_border_rounded,
            LibraryFilterScope.favorites,
          ),
          _scopeTile(
            'Archived',
            Icons.archive_outlined,
            LibraryFilterScope.archived,
          ),
          const Divider(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'CATEGORIES',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Manage categories and tags',
                  onPressed: onManageTaxonomy,
                  icon: const Icon(Icons.tune, size: 18),
                ),
              ],
            ),
          ),
          ListTile(
            dense: true,
            selected: filter.categoryId == null,
            title: const Text('All categories'),
            onTap: () => onCategory(null),
          ),
          for (final category in snapshot.categories)
            ListTile(
              dense: true,
              selected: filter.categoryId == category.id,
              title: Text(category.name, overflow: TextOverflow.ellipsis),
              onTap: () => onCategory(category.id),
            ),
        ],
      ),
    );
  }

  Widget _scopeTile(String title, IconData icon, LibraryFilterScope scope) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 19),
      selected: filter.scope == scope,
      title: Text(title),
      onTap: () => onScope(scope),
    );
  }
}

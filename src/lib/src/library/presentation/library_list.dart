/// Library result list.
library;

import 'package:flutter/material.dart';

import '../models/entry.dart';

/// Selectable prompt list.
final class LibraryList extends StatelessWidget {
  /// Creates result list.
  const LibraryList({
    required this.entries,
    required this.selectedEntryId,
    required this.onSelected,
    required this.focusNode,
    required this.scrollController,
    required this.rowKeyFor,
    super.key,
  });

  /// Visible entries.
  final List<Entry> entries;

  /// Selected entry identifier.
  final String? selectedEntryId;

  /// Selection callback.
  final ValueChanged<String> onSelected;

  /// Keyboard focus owner.
  final FocusNode focusNode;

  /// Result list scroll owner.
  final ScrollController scrollController;

  /// Resolves stable row keys.
  final GlobalKey Function(String id) rowKeyFor;

  /// Builds the focus outline and selectable rows.
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, child) => Focus(
        focusNode: focusNode,
        child: DecoratedBox(
          key: const Key('library-list-focus-outline'),
          decoration: BoxDecoration(
            border: Border.all(
              color: focusNode.hasFocus
                  ? const Color(0x8A315E9E)
                  : Colors.transparent,
            ),
          ),
          child: child,
        ),
      ),
      child: ListView.builder(
        controller: scrollController,
        itemExtent: 52,
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          final selected = entry.id == selectedEntryId;
          return Semantics(
            key: ValueKey('entry-${entry.id}'),
            selected: selected,
            button: true,
            label: entry.title,
            child: InkWell(
              key: rowKeyFor(entry.id),
              onTap: () {
                focusNode.requestFocus();
                onSelected(entry.id);
              },
              child: AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 120),
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: selected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Colors.transparent,
                  border: Border(
                    left: BorderSide(
                      width: 3,
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (entry.isFavorite)
                      const Icon(Icons.star_rounded, size: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

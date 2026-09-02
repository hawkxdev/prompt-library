/// Mobile filter sheet.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../library_controller.dart';
import '../library_state.dart';
import 'mobile_library_mode.dart';

/// Shows the mobile filter sheet.
Future<void> showMobileFilterSheet(
  BuildContext context, {
  required LibraryController controller,
  required MobileLibraryMode mode,
  required ValueChanged<MobileLibraryMode> onMode,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) =>
        _MobileFilterSheet(controller: controller, mode: mode, onMode: onMode),
  );
}

/// Mode, category and tag selection without taxonomy mutation.
final class _MobileFilterSheet extends StatefulWidget {
  const _MobileFilterSheet({
    required this.controller,
    required this.mode,
    required this.onMode,
  });

  final LibraryController controller;
  final MobileLibraryMode mode;
  final ValueChanged<MobileLibraryMode> onMode;

  @override
  State<_MobileFilterSheet> createState() => _MobileFilterSheetState();
}

/// Owns the sheet subscription and selected mode.
final class _MobileFilterSheetState extends State<_MobileFilterSheet> {
  late LibraryState _state;
  late MobileLibraryMode _mode;
  late final StreamSubscription<LibraryState> _subscription;

  @override
  void initState() {
    super.initState();
    _state = widget.controller.state;
    _mode = widget.mode;
    _subscription = widget.controller.states.listen((state) {
      if (!mounted) return;
      setState(() => _state = state);
    });
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }

  /// Applies one mobile mode and its shared scope.
  void _selectMode(MobileLibraryMode mode) {
    setState(() => _mode = mode);
    widget.onMode(mode);
    widget.controller.setFilterScope(scopeForMobileMode(mode));
  }

  /// Toggles one tag inside the shared filter.
  void _toggleTag(String tagId) {
    final tagIds = _state.filter.tagIds.toSet();
    if (!tagIds.remove(tagId)) {
      tagIds.add(tagId);
    }
    widget.controller.setTagFilter(tagIds.toList()..sort());
  }

  /// Builds the filter sheet.
  @override
  Widget build(BuildContext context) {
    final snapshot = _state.snapshot;
    if (snapshot == null) {
      return const SizedBox.shrink();
    }
    final filter = _state.filter;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: ListView(
          key: const Key('mobile-filter-list'),
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      'Filters',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                TextButton(
                  key: const Key('mobile-filter-done'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ],
            ),
            _sectionLabel(context, 'MODE'),
            _modeTile('All prompts', MobileLibraryMode.all),
            _modeTile('Favorites', MobileLibraryMode.favorites),
            _modeTile('Recent', MobileLibraryMode.recent),
            _modeTile('Archived', MobileLibraryMode.archived),
            const Divider(height: 28),
            _sectionLabel(context, 'CATEGORIES'),
            ListTile(
              key: const Key('mobile-category-all'),
              selected: filter.categoryId == null,
              title: const Text('All categories'),
              onTap: () => widget.controller.setCategoryFilter(null),
            ),
            for (final category in snapshot.categories)
              ListTile(
                key: Key('mobile-category-${category.id}'),
                selected: filter.categoryId == category.id,
                title: Text(category.name, overflow: TextOverflow.ellipsis),
                onTap: () => widget.controller.setCategoryFilter(category.id),
              ),
            const Divider(height: 28),
            _sectionLabel(context, 'TAGS'),
            ListTile(
              key: const Key('mobile-tag-all'),
              selected: filter.tagIds.isEmpty,
              title: const Text('All tags'),
              onTap: () => widget.controller.setTagFilter(const []),
            ),
            for (final tag in snapshot.tags)
              ListTile(
                key: Key('mobile-tag-${tag.id}'),
                selected: filter.tagIds.contains(tag.id),
                title: Text(tag.name, overflow: TextOverflow.ellipsis),
                trailing: filter.tagIds.contains(tag.id)
                    ? const Icon(Icons.check, size: 18)
                    : null,
                onTap: () => _toggleTag(tag.id),
              ),
          ],
        ),
      ),
    );
  }

  /// Builds one mode row.
  Widget _modeTile(String title, MobileLibraryMode mode) {
    return ListTile(
      key: Key('mobile-mode-${mode.name}'),
      selected: _mode == mode,
      title: Text(title),
      onTap: () => _selectMode(mode),
    );
  }
}

/// Builds one section label.
Widget _sectionLabel(BuildContext context, String title) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: Text(title, style: Theme.of(context).textTheme.labelSmall),
  );
}

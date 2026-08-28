import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../library/presentation/library_controller.dart';
import '../../library/presentation/library_failure_message.dart';
import '../../library/presentation/library_list.dart';
import '../../library/presentation/library_state.dart';
import 'mac_quick_panel_port.dart';
import 'quick_panel_controller.dart';
import 'quick_panel_state.dart';

/// Compact keyboard-first surface shown by the existing Runner window.
final class QuickModeView extends StatefulWidget {
  /// Creates a quick surface over shared library and quick controllers.
  const QuickModeView({
    required this.libraryController,
    required this.quickPanelController,
    super.key,
  });

  /// Shared application library state owner.
  final LibraryController libraryController;

  /// Quick workflow and native capability owner.
  final QuickPanelController quickPanelController;

  @override
  State<QuickModeView> createState() => _QuickModeViewState();
}

final class _QuickModeViewState extends State<QuickModeView> {
  late LibraryState _libraryState;
  late QuickPanelState _quickState;
  late final TextEditingController _searchController;
  late final FocusNode _searchFocus;
  late final FocusNode _listFocus;
  late final ScrollController _scrollController;
  late final StreamSubscription<LibraryState> _librarySubscription;
  late final StreamSubscription<QuickPanelState> _quickSubscription;
  final Map<String, GlobalKey> _rowKeys = {};

  @override
  void initState() {
    super.initState();
    _libraryState = widget.libraryController.state;
    _quickState = widget.quickPanelController.state;
    _searchController = TextEditingController(
      text: _libraryState.filter.searchQuery,
    );
    _searchFocus = FocusNode(debugLabel: 'quick-search');
    _listFocus = FocusNode(debugLabel: 'quick-list');
    _scrollController = ScrollController();
    _librarySubscription = widget.libraryController.states.listen(
      _handleLibraryState,
    );
    _quickSubscription = widget.quickPanelController.states.listen(
      _handleQuickState,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    unawaited(_librarySubscription.cancel());
    unawaited(_quickSubscription.cancel());
    _searchController.dispose();
    _searchFocus.dispose();
    _listFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleLibraryState(LibraryState state) {
    if (!mounted) {
      return;
    }
    if (_searchController.text != state.filter.searchQuery) {
      _searchController.value = TextEditingValue(
        text: state.filter.searchQuery,
        selection: TextSelection.collapsed(
          offset: state.filter.searchQuery.length,
        ),
      );
    }
    setState(() => _libraryState = state);
  }

  void _handleQuickState(QuickPanelState state) {
    if (!mounted) {
      return;
    }
    final shouldRefocus =
        state.mode == QuickPanelMode.quick &&
        state.requestGeneration != _quickState.requestGeneration;
    setState(() => _quickState = state);
    if (shouldRefocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _searchFocus.requestFocus();
        }
      });
    }
  }

  void _moveSelection(int offset) {
    final entries = _libraryState.visibleEntries;
    if (entries.isEmpty) {
      return;
    }
    final current = entries.indexWhere(
      (entry) => entry.id == _libraryState.selectedEntryId,
    );
    final start = current < 0 ? 0 : current;
    final next = (start + offset).clamp(0, entries.length - 1);
    final id = entries[next].id;
    widget.libraryController.selectEntry(id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rowContext = _rowKeys[id]?.currentContext;
      if (rowContext != null) {
        unawaited(
          Scrollable.ensureVisible(
            rowContext,
            duration: const Duration(milliseconds: 100),
            alignment: 0.5,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowUp): _MoveQuickSelectionIntent(
          -1,
        ),
        SingleActivator(LogicalKeyboardKey.arrowDown):
            _MoveQuickSelectionIntent(1),
        SingleActivator(LogicalKeyboardKey.enter): _CopyQuickSelectionIntent(),
        SingleActivator(LogicalKeyboardKey.escape): _DismissQuickModeIntent(),
      },
      child: Actions(
        actions: {
          _MoveQuickSelectionIntent: CallbackAction<_MoveQuickSelectionIntent>(
            onInvoke: (intent) => _moveSelection(intent.offset),
          ),
          _CopyQuickSelectionIntent: CallbackAction<_CopyQuickSelectionIntent>(
            onInvoke: (_) => widget.quickPanelController.copySelected(),
          ),
          _DismissQuickModeIntent: CallbackAction<_DismissQuickModeIntent>(
            onInvoke: (_) => widget.quickPanelController.dismiss(),
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      key: const Key('quick-search'),
                      controller: _searchController,
                      focusNode: _searchFocus,
                      autofocus: true,
                      onChanged: widget.libraryController.updateSearchQuery,
                      onSubmitted: (_) {
                        unawaited(widget.quickPanelController.copySelected());
                      },
                      decoration: const InputDecoration(
                        hintText: 'Search prompts',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_quickState.copied)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Copied',
                          key: Key('quick-copied'),
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    if (_quickState.copyFailed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'The prompt could not be copied.',
                          key: const Key('quick-copy-failure'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (_quickState.latestNativeFailure != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _nativeFailureMessage(
                            _quickState.latestNativeFailure!,
                          ),
                          key: const Key('quick-native-failure'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (_libraryState.failure != null &&
                        _libraryState.hasUsableSnapshot)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          messageForLibraryFailure(_libraryState.failure!),
                          key: const Key('quick-library-failure'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    Expanded(child: _buildResults()),
                    const SizedBox(height: 8),
                    const Text(
                      '↑/↓ Select   Enter Copy   Esc Close',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_libraryState.loadStatus == LibraryLoadStatus.loading &&
        !_libraryState.hasUsableSnapshot) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_libraryState.loadStatus == LibraryLoadStatus.failure &&
        !_libraryState.hasUsableSnapshot) {
      final failure = _libraryState.failure;
      return Center(
        child: Text(
          failure == null
              ? 'The library could not be loaded.'
              : messageForLibraryFailure(failure),
        ),
      );
    }
    if (_libraryState.visibleEntries.isEmpty) {
      return const Center(
        child: Text('No matching prompts', key: Key('quick-empty')),
      );
    }
    return LibraryList(
      entries: _libraryState.visibleEntries,
      selectedEntryId: _libraryState.selectedEntryId,
      onSelected: widget.libraryController.selectEntry,
      focusNode: _listFocus,
      scrollController: _scrollController,
      rowKeyFor: (id) => _rowKeys.putIfAbsent(id, GlobalKey.new),
    );
  }
}

/// Moves selection in the quick result list.
final class _MoveQuickSelectionIntent extends Intent {
  const _MoveQuickSelectionIntent(this.offset);

  final int offset;
}

/// Copies the current quick selection.
final class _CopyQuickSelectionIntent extends Intent {
  const _CopyQuickSelectionIntent();
}

/// Dismisses quick mode without copying.
final class _DismissQuickModeIntent extends Intent {
  const _DismissQuickModeIntent();
}

String _nativeFailureMessage(MacQuickPanelResult result) {
  return switch (result.kind) {
    MacQuickPanelResultKind.collision => 'The shortcut is already in use.',
    MacQuickPanelResultKind.invalidShortcut => 'The shortcut is invalid.',
    MacQuickPanelResultKind.unavailable => 'Quick access is unavailable.',
    MacQuickPanelResultKind.nativeFailure => 'Quick access could not finish.',
    MacQuickPanelResultKind.registered => '',
  };
}

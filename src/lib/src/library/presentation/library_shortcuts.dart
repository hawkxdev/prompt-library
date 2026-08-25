/// Library keyboard intents.
library;

import 'package:flutter/widgets.dart';

/// Focuses library search.
final class FocusLibrarySearchIntent extends Intent {
  /// Creates focus intent.
  const FocusLibrarySearchIntent();
}

/// Moves current selection.
final class MoveLibrarySelectionIntent extends Intent {
  /// Creates movement intent.
  const MoveLibrarySelectionIntent(this.offset);

  /// Relative movement amount.
  final int offset;
}

/// Selects list boundary.
final class SelectLibraryBoundaryIntent extends Intent {
  /// Creates boundary intent.
  const SelectLibraryBoundaryIntent({required this.last});

  /// Whether to select last entry.
  final bool last;
}

/// Copies selected entry.
final class CopySelectedEntryIntent extends Intent {
  /// Creates copy intent.
  const CopySelectedEntryIntent();
}

/// Creates new entry.
final class CreateLibraryEntryIntent extends Intent {
  /// Creates entry intent.
  const CreateLibraryEntryIntent();
}

/// Edits selected entry.
final class EditLibraryEntryIntent extends Intent {
  /// Creates edit intent.
  const EditLibraryEntryIntent();
}

/// Pure library transfer planning.
library;

import '../models/library_snapshot.dart';
import 'library_document.dart';
import 'raycast_snippet_decoder.dart';

/// Classifies source row disposition.
enum ImportRowOutcome {
  selected,
  duplicate,
  conflict,
  invalid,
  userSkipped,
  unsupportedFields,
}

/// Holds explicit import choices.
final class RaycastSelection {
  /// Freezes explicit row choices.
  RaycastSelection({
    Set<int> excludedIndices = const {},
    Set<int> addAsNewIndices = const {},
    Set<int> acceptedUnknownFieldIndices = const {},
  }) : excludedIndices = Set.unmodifiable(excludedIndices),
       addAsNewIndices = Set.unmodifiable(addAsNewIndices),
       acceptedUnknownFieldIndices = Set.unmodifiable(
         acceptedUnknownFieldIndices,
       );
  final Set<int> excludedIndices;
  final Set<int> addAsNewIndices;
  final Set<int> acceptedUnknownFieldIndices;

  /// Rejects unknown source indices.
  void validate(int count) {
    for (final indices in [
      excludedIndices,
      addAsNewIndices,
      acceptedUnknownFieldIndices,
    ]) {
      if (indices.any((index) => index < 0 || index >= count)) {
        throw ArgumentError('Selection index outside source');
      }
    }
  }
}

/// Holds immutable row disposition.
final class PlannedRaycastRow {
  /// Associates source and outcome.
  const PlannedRaycastRow(this.source, this.outcome);
  final RaycastRow source;
  final ImportRowOutcome outcome;
}

/// Plans additions without writing.
final class RaycastImportPlan {
  /// Freezes complete import preview.
  RaycastImportPlan._(this.expectedSnapshot, Iterable<PlannedRaycastRow> rows)
    : rows = List.unmodifiable(rows);

  /// Classifies selected source rows.
  factory RaycastImportPlan.build(
    RaycastDocument source,
    LibrarySnapshot expected, {
    RaycastSelection? selection,
  }) {
    validateLibrarySnapshot(expected);
    final choice = selection ?? RaycastSelection();
    choice.validate(source.rows.length);
    final exact = <(String, String, String?)>{};
    final names = <String>{};
    final keywords = <String>{};
    for (final entry in expected.entries) {
      exact.add((entry.title.trim(), entry.body, entry.keyword));
      names.add(entry.title.trim());
      if (_hasKeyword(entry.keyword)) keywords.add(entry.keyword!);
    }
    final planned = <PlannedRaycastRow>[];
    for (final row in source.rows) {
      final value = row.snippet;
      final ImportRowOutcome outcome;
      if (row.failure != null || value == null) {
        outcome = ImportRowOutcome.invalid;
      } else if (choice.excludedIndices.contains(row.index)) {
        outcome = ImportRowOutcome.userSkipped;
      } else if (row.unknownFields.isNotEmpty &&
          !choice.acceptedUnknownFieldIndices.contains(row.index)) {
        outcome = ImportRowOutcome.unsupportedFields;
      } else if (exact.contains((value.title, value.body, value.keyword))) {
        outcome = ImportRowOutcome.duplicate;
      } else if ((names.contains(value.title) ||
              (_hasKeyword(value.keyword) &&
                  keywords.contains(value.keyword))) &&
          !choice.addAsNewIndices.contains(row.index)) {
        outcome = ImportRowOutcome.conflict;
      } else {
        outcome = ImportRowOutcome.selected;
        exact.add((value.title, value.body, value.keyword));
        names.add(value.title);
        if (_hasKeyword(value.keyword)) keywords.add(value.keyword!);
      }
      planned.add(PlannedRaycastRow(row, outcome));
    }
    return RaycastImportPlan._(expected, planned);
  }

  final LibrarySnapshot expectedSnapshot;
  final List<PlannedRaycastRow> rows;

  /// Exposes selected source rows.
  List<RaycastRow> get selectedRows => List.unmodifiable(
    rows
        .where((row) => row.outcome == ImportRowOutcome.selected)
        .map((row) => row.source),
  );

  /// Counts predicted inserted rows.
  int get predictedAdded => outcomeCounts[ImportRowOutcome.selected]!;

  /// Counts every skipped row.
  int get predictedSkipped => rows.length - predictedAdded;

  /// Counts structurally valid rows.
  int get validCount => rows.where((row) => row.source.failure == null).length;

  /// Counts independent warning rows.
  int get warningRowCount => rows
      .where(
        (row) =>
            row.source.unknownFields.isNotEmpty ||
            row.source.hasPlaceholderSyntax,
      )
      .length;

  /// Counts mutually exclusive outcomes.
  Map<ImportRowOutcome, int> get outcomeCounts {
    final counts = {for (final outcome in ImportRowOutcome.values) outcome: 0};
    for (final row in rows) {
      counts[row.outcome] = counts[row.outcome]! + 1;
    }
    return Map.unmodifiable(counts);
  }
}

/// Identifies meaningful conflict alias.
bool _hasKeyword(String? keyword) =>
    keyword != null && keyword.trim().isNotEmpty;

/// Classifies full entity differences.
enum EntityChangeKind { added, removed, modified, unchanged }

/// Holds immutable field comparison.
final class EntityDifference {
  /// Freezes before and after.
  EntityDifference._(
    this.id,
    this.kind,
    Iterable<String> fields,
    Map<String, Object?>? before,
    Map<String, Object?>? after,
  ) : fields = List.unmodifiable(fields),
      before = _freezeRow(before),
      after = _freezeRow(after);
  final String id;
  final EntityChangeKind kind;
  final List<String> fields;
  final Map<String, Object?>? before;
  final Map<String, Object?>? after;
}

/// Describes full snapshot replacement.
final class LibraryRestorePlan {
  /// Freezes full entity differences.
  LibraryRestorePlan._(
    this.expectedSnapshot,
    this.incomingSnapshot,
    this.entries,
    this.categories,
    this.tags,
  );

  /// Compares full library snapshots.
  factory LibraryRestorePlan.compare(
    LibrarySnapshot expected,
    LibrarySnapshot incoming,
  ) {
    validateLibrarySnapshot(expected);
    validateLibrarySnapshot(incoming);
    final before = librarySnapshotValue(expected);
    final after = librarySnapshotValue(incoming);
    return LibraryRestorePlan._(
      expected,
      incoming,
      _differences(before['entries']! as List, after['entries']! as List),
      _differences(before['categories']! as List, after['categories']! as List),
      _differences(before['tags']! as List, after['tags']! as List),
    );
  }
  final LibrarySnapshot expectedSnapshot;
  final LibrarySnapshot incomingSnapshot;
  final List<EntityDifference> entries;
  final List<EntityDifference> categories;
  final List<EntityDifference> tags;
}

/// Freezes serializable entity fields.
Map<String, Object?>? _freezeRow(Map<String, Object?>? row) => row == null
    ? null
    : Map.unmodifiable({
        for (final entry in row.entries)
          entry.key: entry.value is List
              ? List<Object?>.unmodifiable(entry.value! as List)
              : entry.value,
      });

/// Compares flat entity field values.
bool _equalField(Object? left, Object? right) {
  if (left is List && right is List) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }
  return left == right;
}

/// Compares deterministic entity unions.
List<EntityDifference> _differences(List before, List after) {
  final left = <String, Map<String, Object?>>{
    for (final row in before)
      (row as Map)['id'] as String: Map<String, Object?>.from(row),
  };
  final right = <String, Map<String, Object?>>{
    for (final row in after)
      (row as Map)['id'] as String: Map<String, Object?>.from(row),
  };
  final ids = {...left.keys, ...right.keys}.toList()..sort();
  return List.unmodifiable([
    for (final id in ids) _difference(id, left[id], right[id]),
  ]);
}

/// Classifies one entity comparison.
EntityDifference _difference(
  String id,
  Map<String, Object?>? before,
  Map<String, Object?>? after,
) {
  if (before == null) {
    return EntityDifference._(
      id,
      EntityChangeKind.added,
      after!.keys,
      null,
      after,
    );
  }
  if (after == null) {
    return EntityDifference._(
      id,
      EntityChangeKind.removed,
      before.keys,
      before,
      null,
    );
  }
  final fields = before.keys
      .where((key) => !_equalField(before[key], after[key]))
      .toList();
  return EntityDifference._(
    id,
    fields.isEmpty ? EntityChangeKind.unchanged : EntityChangeKind.modified,
    fields,
    before,
    after,
  );
}

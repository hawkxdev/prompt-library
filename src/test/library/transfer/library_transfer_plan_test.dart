/// Pure transfer planning tests.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/library/models/library_snapshot.dart';
import 'package:prompt_library/src/library/transfer/library_document.dart';
import 'package:prompt_library/src/library/transfer/library_transfer_plan.dart';
import 'package:prompt_library/src/library/transfer/raycast_snippet_decoder.dart';

import 'transfer_test_support.dart';

/// Decodes synthetic source rows.
RaycastDocument source(List<Object?> rows) =>
    RaycastSnippetDecoder().decode(utf8.encode(jsonEncode(rows)));

void main() {
  test('records exact field diffs and immutable after values', () {
    final before = documentFixture().snapshot;
    final raw = rawDocument();
    rawEntry(raw)
      ..['title'] = 'Changed'
      ..['body'] = 'Changed body'
      ..['keyword'] = ''
      ..['categoryId'] = null
      ..['tagIds'] = <String>[]
      ..['isFavorite'] = false
      ..['isArchived'] = false
      ..['createdAt'] = '2020-01-01T00:00:00Z'
      ..['updatedAt'] = '2020-01-02T00:00:00Z'
      ..['lastCopiedAt'] = null;
    final after = LibraryDocument.fromValue(raw).snapshot;
    final diff = LibraryRestorePlan.compare(before, after).entries.single;
    expect(diff.fields.toSet(), {
      'title',
      'body',
      'keyword',
      'categoryId',
      'tagIds',
      'isFavorite',
      'isArchived',
      'createdAt',
      'updatedAt',
      'lastCopiedAt',
    });
    expect(() => diff.after!['body'] = 'mutated', throwsUnsupportedError);
    expect(
      LibraryRestorePlan.compare(
        before,
        const LibrarySnapshot.empty(),
      ).entries.single.kind,
      EntityChangeKind.removed,
    );
  });
  test(
    'selection is immutable and snapshot permutation leaves decisions equal',
    () {
      final excluded = <int>{0};
      final selection = RaycastSelection(excludedIndices: excluded);
      excluded.clear();
      expect(selection.excludedIndices, {0});
      final input = source([
        {'name': 'A', 'text': 'B'},
        {'name': 'C', 'text': 'D'},
      ]);
      final snapshot = documentFixture().snapshot;
      final reordered = LibrarySnapshot(
        entries: snapshot.entries.reversed,
        categories: snapshot.categories.reversed,
        tags: snapshot.tags.reversed,
      );
      expect(
        RaycastImportPlan.build(input, snapshot).rows.map((r) => r.outcome),
        RaycastImportPlan.build(input, reordered).rows.map((r) => r.outcome),
      );
      final plan = RaycastImportPlan.build(
        input,
        snapshot,
        selection: selection,
      );
      expect(plan.predictedAdded, 1);
      expect(plan.predictedSkipped, 1);
      expect(
        plan.outcomeCounts.values.fold(0, (a, b) => a + b),
        input.rows.length,
      );
    },
  );
  test(
    'deduplicates archived entries and classifies conflicts without writes',
    () {
      final doc = documentFixture();
      final entry = doc.snapshot.entries.single;
      final input = source([
        {'name': entry.title, 'text': entry.body, 'keyword': entry.keyword},
        {'name': entry.title, 'text': 'different'},
        {'name': 'Fresh', 'text': 'different'},
        {'name': 'Fresh', 'text': 'different'},
      ]);
      final plan = RaycastImportPlan.build(input, doc.snapshot);
      expect(plan.rows.map((r) => r.outcome), [
        ImportRowOutcome.duplicate,
        ImportRowOutcome.conflict,
        ImportRowOutcome.selected,
        ImportRowOutcome.duplicate,
      ]);
      expect(plan.predictedAdded, 1);
      expect(plan.predictedSkipped, 3);
      expect(plan.expectedSnapshot, same(doc.snapshot));
      expect(() => plan.rows.clear(), throwsUnsupportedError);
    },
  );
  test('recomputes duplicate representative after deselection', () {
    final input = source([
      {'name': 'A', 'text': 'B'},
      {'name': 'A', 'text': 'B'},
    ]);
    final empty = const LibrarySnapshot.empty();
    expect(RaycastImportPlan.build(input, empty).selectedRows.single.index, 0);
    final plan = RaycastImportPlan.build(
      input,
      empty,
      selection: RaycastSelection(excludedIndices: {0}),
    );
    expect(plan.selectedRows.single.index, 1);
    expect(plan.rows.first.outcome, ImportRowOutcome.userSkipped);
  });
  test('unknown fields require consent and never reserve duplicate keys', () {
    final input = source([
      {'name': 'A', 'text': 'B', 'tags': []},
      {'name': 'A', 'text': 'B'},
    ]);
    final plan = RaycastImportPlan.build(input, const LibrarySnapshot.empty());
    expect(plan.rows.first.outcome, ImportRowOutcome.unsupportedFields);
    expect(plan.selectedRows.single.index, 1);
    expect(plan.warningRowCount, 1);
    final accepted = RaycastImportPlan.build(
      input,
      const LibrarySnapshot.empty(),
      selection: RaycastSelection(acceptedUnknownFieldIndices: {0}),
    );
    expect(accepted.selectedRows.single.index, 0);
    expect(
      accepted.predictedAdded + accepted.predictedSkipped,
      input.rows.length,
    );
  });
  test('explicit add allows conflict but not exact duplicates', () {
    final input = source([
      {'name': 'A', 'text': 'B'},
      {'name': 'A', 'text': 'C'},
      {'name': 'A', 'text': 'C'},
    ]);
    final plan = RaycastImportPlan.build(
      input,
      const LibrarySnapshot.empty(),
      selection: RaycastSelection(addAsNewIndices: {1, 2}),
    );
    expect(plan.predictedAdded, 2);
    expect(plan.rows.last.outcome, ImportRowOutcome.duplicate);
  });
  test('null empty and blank aliases do not create unrelated conflicts', () {
    final input = source([
      {'name': 'A', 'text': 'B'},
      {'name': 'C', 'text': 'B', 'keyword': ''},
      {'name': 'D', 'text': 'B', 'keyword': ' '},
    ]);
    expect(
      RaycastImportPlan.build(
        input,
        const LibrarySnapshot.empty(),
      ).predictedAdded,
      3,
    );
    final different = source([
      {'name': 'A', 'text': 'B'},
      {'name': 'A', 'text': 'B', 'keyword': ''},
    ]);
    expect(
      RaycastImportPlan.build(
        different,
        const LibrarySnapshot.empty(),
      ).rows.last.outcome,
      ImportRowOutcome.conflict,
    );
  });
  test(
    'counts invalid excluded and empty selections and validates indices',
    () {
      final input = source([
        null,
        {'name': 'A', 'text': 'B'},
      ]);
      final plan = RaycastImportPlan.build(
        input,
        const LibrarySnapshot.empty(),
        selection: RaycastSelection(excludedIndices: {1}),
      );
      expect(plan.validCount, 1);
      expect(plan.predictedAdded, 0);
      expect(plan.predictedSkipped, 2);
      expect(
        RaycastImportPlan.build(source([]), const LibrarySnapshot.empty()).rows,
        isEmpty,
      );
      expect(
        () => RaycastImportPlan.build(
          input,
          const LibrarySnapshot.empty(),
          selection: RaycastSelection(excludedIndices: {3}),
        ),
        throwsArgumentError,
      );
    },
  );
  test('compares every field including copy dates and unused taxonomy', () {
    final before = documentFixture().snapshot;
    final raw = rawDocument();
    rawEntry(raw)['lastCopiedAt'] = '2026-09-08T02:03:04Z';
    (raw['tags']! as List).removeLast();
    final after = LibraryDocument.fromValue(raw).snapshot;
    final plan = LibraryRestorePlan.compare(before, after);
    expect(plan.entries.single.kind, EntityChangeKind.modified);
    expect(plan.entries.single.fields, ['lastCopiedAt']);
    expect(
      plan.tags.where((d) => d.kind == EntityChangeKind.removed).single.id,
      'unused',
    );
    expect(
      plan.categories.every((d) => d.kind == EntityChangeKind.unchanged),
      isTrue,
    );
    expect(
      () => (plan.entries.single.before!['tagIds']! as List).clear(),
      throwsUnsupportedError,
    );
    expect(
      LibraryRestorePlan.compare(
        const LibrarySnapshot.empty(),
        after,
      ).entries.single.kind,
      EntityChangeKind.added,
    );
  });
  test('does not collapse composite keys with embedded separators', () {
    final input = source([
      {'name': 'a|b', 'text': 'c', 'keyword': 'd'},
      {'name': 'a', 'text': 'b|c', 'keyword': 'd'},
    ]);
    expect(
      RaycastImportPlan.build(
        input,
        const LibrarySnapshot.empty(),
        selection: RaycastSelection(addAsNewIndices: {1}),
      ).predictedAdded,
      2,
    );
  });
}

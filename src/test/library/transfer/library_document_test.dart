/// Portable document contract tests.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/library/models/library_snapshot.dart';
import 'package:prompt_library/src/library/transfer/library_document.dart';

import 'transfer_test_support.dart';

/// Matches safe document failure.
Matcher failure(DocumentFailureCode code) =>
    isA<DocumentFailure>().having((e) => e.code, 'code', code);

void main() {
  for (final pair in <(String, Object?)>[
    ('id', ''),
    ('title', '  '),
    ('body', ''),
    ('keyword', 1),
    ('isFavorite', 1),
    ('isArchived', null),
    ('tagIds', ['missing']),
  ]) {
    test('rejects invalid entry field ${pair.$1}', () {
      final raw = rawDocument();
      rawEntry(raw)[pair.$1] = pair.$2;
      expect(
        () => LibraryDocument.fromValue(raw),
        throwsA(isA<DocumentFailure>()),
      );
    });
  }
  test('validates resource configuration and copies supplied byte chunks', () {
    expect(() => DocumentLimits(maxBytes: 0), throwsArgumentError);
    expect(() => DocumentLimits(maxDepth: 0), throwsArgumentError);
    expect(() => DocumentLimits(maxObjectKeys: 0), throwsArgumentError);
    final source = [1, 2, 3];
    final sink = DocumentByteSink(DocumentLimits(maxBytes: 3));
    sink.add(source);
    source[0] = 9;
    expect(sink.takeBytes(), [1, 2, 3]);
    expect(() => sink.add([1]), throwsStateError);
  });
  test('rejects invalid snapshot identifier before export', () {
    final valid = documentFixture();
    final snapshot = LibrarySnapshot(
      entries: [valid.snapshot.entries.single.copyWith(id: '')],
      categories: valid.snapshot.categories,
      tags: valid.snapshot.tags,
    );
    expect(
      () => LibraryDocument(snapshot: snapshot, exportedAt: valid.exportedAt),
      throwsA(failure(DocumentFailureCode.invalidValue)),
    );
  });
  test('locates invalid fields without exposing the source value', () {
    final raw = rawDocument();
    rawEntry(raw)['body'] = '  ';
    expect(
      () => LibraryDocument.fromValue(raw),
      throwsA(
        isA<DocumentFailure>()
            .having((e) => e.rowIndex, 'row', 0)
            .having((e) => e.collection, 'collection', 'entries')
            .having((e) => e.field, 'field', 'body'),
      ),
    );
  });
  test('preserves the complete snapshot and freezes collections', () {
    final raw = rawDocument();
    final document = LibraryDocument.fromValue(raw);
    expect(document.toValue(), raw);
    expect(document.snapshot.entries.single.body, rawEntry(raw)['body']);
    expect(document.snapshot.entries.single.keyword, '  alias  ');
    expect(document.snapshot.entries.single.isArchived, isTrue);
    expect(document.snapshot.categories, hasLength(2));
    expect(document.snapshot.tags, hasLength(2));
    expect(() => document.snapshot.entries.clear(), throwsUnsupportedError);
    rawEntry(raw)['body'] = 'mutated';
    expect(document.snapshot.entries.single.body, isNot('mutated'));
  });
  for (final keyword in <String?>[null, '', ' ', '  alias  ']) {
    test('preserves exact keyword ${keyword?.length}', () {
      final raw = rawDocument();
      rawEntry(raw)['keyword'] = keyword;
      expect(
        LibraryDocument.fromValue(raw).snapshot.entries.single.keyword,
        keyword,
      );
    });
  }
  test('accepts empty snapshot and requires explicit nullable fields', () {
    final empty = LibraryDocument(
      snapshot: const LibrarySnapshot.empty(),
      exportedAt: DateTime.utc(2026),
    );
    expect(
      LibraryDocument.fromValue(empty.toValue()).snapshot,
      const LibrarySnapshot.empty(),
    );
    final raw = rawDocument();
    rawEntry(raw).remove('keyword');
    expect(
      () => LibraryDocument.fromValue(raw),
      throwsA(failure(DocumentFailureCode.missingField)),
    );
  });
  for (final date in [
    '2026-02-30T00:00:00Z',
    '2026-01-01T24:00:00Z',
    '2026-01-01T00:00:60Z',
    '2026-01-01T00:00:00.000Z',
    '2026-01-01T00:00:00+00:00',
    '2026-01-01T00:00:00z',
    '0000-01-01T00:00:00Z',
  ]) {
    test('rejects noncanonical date $date', () {
      final raw = rawDocument();
      rawEntry(raw)['createdAt'] = date;
      expect(
        () => LibraryDocument.fromValue(raw),
        throwsA(failure(DocumentFailureCode.invalidDate)),
      );
    });
  }
  test('accepts leap day and date endpoints without chronology invention', () {
    final raw = rawDocument();
    rawEntry(raw)['createdAt'] = '9999-12-31T23:59:59Z';
    rawEntry(raw)['updatedAt'] = '0001-01-01T00:00:00Z';
    rawEntry(raw)['lastCopiedAt'] = '2024-02-29T00:00:00Z';
    expect(
      LibraryDocument.fromValue(raw).snapshot.entries.single.createdAt.year,
      9999,
    );
  });
  test('rejects duplicate identifiers before maps discard them', () {
    final raw = rawDocument();
    (raw['entries']! as List).add({...rawEntry(raw)});
    expect(
      () => LibraryDocument.fromValue(raw),
      throwsA(failure(DocumentFailureCode.duplicateId)),
    );
  });
  test('rejects repeated links before entity constructor deduplicates', () {
    final raw = rawDocument();
    rawEntry(raw)['tagIds'] = ['tag-1', 'tag-1'];
    expect(
      () => LibraryDocument.fromValue(raw),
      throwsA(failure(DocumentFailureCode.duplicateLink)),
    );
  });
  test('rejects missing references', () {
    final raw = rawDocument();
    rawEntry(raw)['categoryId'] = 'missing';
    expect(
      () => LibraryDocument.fromValue(raw),
      throwsA(failure(DocumentFailureCode.danglingReference)),
    );
  });
  test(
    'rejects unsupported fields and versions without content diagnostics',
    () {
      final raw = rawDocument();
      raw['private body'] = true;
      expect(
        () => LibraryDocument.fromValue(raw),
        throwsA(failure(DocumentFailureCode.unsupportedField)),
      );
      try {
        LibraryDocument.fromValue(raw);
      } on DocumentFailure catch (e) {
        expect(e.toString(), isNot(contains('private body')));
      }
      raw.remove('private body');
      raw['formatVersion'] = 1.0;
      expect(
        () => LibraryDocument.fromValue(raw),
        throwsA(failure(DocumentFailureCode.unsupportedVersion)),
      );
    },
  );
  test('rejects invalid names and duplicate normalized taxonomy', () {
    final raw = rawDocument();
    ((raw['tags']! as List).last as Map)['normalizedName'] = 'WRONG';
    expect(
      () => LibraryDocument.fromValue(raw),
      throwsA(failure(DocumentFailureCode.invalidValue)),
    );
    final duplicate = rawDocument();
    ((duplicate['tags']! as List).last as Map)
      ..['name'] = 'Tag'
      ..['normalizedName'] = 'tag';
    expect(
      () => LibraryDocument.fromValue(duplicate),
      throwsA(failure(DocumentFailureCode.duplicateName)),
    );
  });
  test('rejects lone surrogates before encoding loses data', () {
    final raw = rawDocument();
    rawEntry(raw)['body'] = String.fromCharCode(0xd800);
    expect(
      () => LibraryDocument.fromValue(raw),
      throwsA(failure(DocumentFailureCode.invalidUnicode)),
    );
  });
  test('rejects snapshot with fractional timestamps', () {
    final fixture = documentFixture();
    expect(
      () => LibraryDocument(
        snapshot: fixture.snapshot,
        exportedAt: DateTime.utc(2026, 1, 1, 0, 0, 0, 1),
      ),
      throwsA(failure(DocumentFailureCode.invalidDate)),
    );
  });
}

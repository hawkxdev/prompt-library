/// Strict JSON boundary tests.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/library/models/library_snapshot.dart';
import 'package:prompt_library/src/library/transfer/library_document.dart';
import 'package:prompt_library/src/library/transfer/library_json_codec.dart';

import 'transfer_test_support.dart';

/// Matches document error code.
Matcher code(DocumentFailureCode value) =>
    isA<DocumentFailure>().having((e) => e.code, 'code', value);

void main() {
  test('roundtrips every field and exact body with canonical bytes', () {
    final codec = LibraryJsonCodec();
    final doc = documentFixture();
    final bytes = codec.encode(doc);
    expect(codec.decode(bytes).snapshot, doc.snapshot);
    expect(codec.decode(bytes).exportedAt, doc.exportedAt);
    expect(bytes.last, 10);
    expect(codec.encode(codec.decode(bytes)), bytes);
    expect(() => bytes[0] = 0, throwsUnsupportedError);
    final reordered = LibrarySnapshot(
      entries: doc.snapshot.entries.reversed,
      categories: doc.snapshot.categories.reversed,
      tags: doc.snapshot.tags.reversed,
    );
    expect(
      codec.encode(
        LibraryDocument(snapshot: reordered, exportedAt: doc.exportedAt),
      ),
      bytes,
    );
  });
  for (final input in [
    r'{"a":1,"a":2}',
    r'{"a":1,"\u0061":2}',
    r'{"child":{"a":1,"a":2}}',
  ]) {
    test('rejects duplicate keys $input', () {
      expect(
        () => LibraryJsonCodec().decodeValue(utf8.encode(input)),
        throwsA(code(DocumentFailureCode.duplicateKey)),
      );
    });
  }
  test('allows same keys in separate objects and JSON text in strings', () {
    final value = [
      {'a': '{"a":1,"a":2}'},
      {'a': 'quote " and slash \\'},
    ];
    expect(
      LibraryJsonCodec().decodeValue(utf8.encode(jsonEncode(value))),
      value,
    );
  });
  for (final input in [
    '[',
    '{"a":}',
    'true false',
    '{"a":1,}',
    '[1,]',
    '"bad\nstring"',
  ]) {
    test('rejects malformed JSON without content leakage $input', () {
      expect(
        () => LibraryJsonCodec().decodeValue(utf8.encode(input)),
        throwsA(code(DocumentFailureCode.invalidJson)),
      );
    });
  }
  test('rejects malformed UTF8 and unpaired escaped Unicode', () {
    expect(
      () => LibraryJsonCodec().decodeValue([34, 255, 34]),
      throwsA(code(DocumentFailureCode.invalidUtf8)),
    );
    expect(
      () => LibraryJsonCodec().decodeValue([255]),
      throwsA(code(DocumentFailureCode.invalidUtf8)),
    );
    for (final input in [r'"\ud800"', r'{"\udc00":0}', r'{"extra":"\ud800"}']) {
      expect(
        () => LibraryJsonCodec().decodeValue(utf8.encode(input)),
        throwsA(code(DocumentFailureCode.invalidUnicode)),
      );
    }
    expect(
      LibraryJsonCodec().decodeValue(utf8.encode(r'"\uD83E\uDD8A"')),
      '🦊',
    );
  });
  test('counts BOM in budget and accepts only a leading BOM', () {
    final codec = LibraryJsonCodec();
    final bytes = codec.encode(documentFixture());
    expect(
      codec.decode([239, 187, 191, ...bytes]).snapshot,
      documentFixture().snapshot,
    );
    expect(
      () => codec.decodeValue([239, 187, 191, 239, 187, 191, 49]),
      throwsA(code(DocumentFailureCode.invalidJson)),
    );
  });
  test('enforces byte boundary inclusive for input and output', () {
    final doc = documentFixture();
    final bytes = LibraryJsonCodec().encode(doc);
    final exact = LibraryJsonCodec(
      limits: DocumentLimits(maxBytes: bytes.length),
    );
    expect(exact.decode(bytes).snapshot, doc.snapshot);
    expect(exact.encode(doc), bytes);
    expect(
      () => exact.decode([...bytes, 32]),
      throwsA(code(DocumentFailureCode.limitExceeded)),
    );
    expect(
      () =>
          LibraryJsonCodec(limits: DocumentLimits(maxBytes: bytes.length - 1))
              .encode(doc),
      throwsA(code(DocumentFailureCode.limitExceeded)),
    );
  });
  test('enforces depth and object key boundaries with controls', () {
    final codec = LibraryJsonCodec(
      limits: DocumentLimits(maxDepth: 2, maxObjectKeys: 2),
    );
    expect(codec.decodeValue(utf8.encode('{"a":[1],"b":0}')), {
      'a': [1],
      'b': 0,
    });
    expect(
      () => codec.decodeValue(utf8.encode('[[[]]]')),
      throwsA(code(DocumentFailureCode.limitExceeded)),
    );
    expect(
      () => codec.decodeValue(utf8.encode('{"a":1,"b":2,"c":3}')),
      throwsA(code(DocumentFailureCode.limitExceeded)),
    );
    expect(
      () => codec.encode(documentFixture()),
      throwsA(code(DocumentFailureCode.limitExceeded)),
    );
  });
}

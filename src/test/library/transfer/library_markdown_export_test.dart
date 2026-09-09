/// Readable document export tests.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/library/models/library_snapshot.dart';
import 'package:prompt_library/src/library/transfer/library_document.dart';
import 'package:prompt_library/src/library/transfer/library_markdown_export.dart';

import 'transfer_test_support.dart';

void main() {
  test('keeps literal body safely fenced with all metadata', () {
    final doc = documentFixture();
    final text = utf8.decode(LibraryMarkdownExport().encode(doc));
    expect(text, contains('````\n${doc.snapshot.entries.single.body}\n````'));
    expect(text, contains('"isArchived":true'));
    expect(text, contains('"id":"unused"'));
    expect(text, contains('"keyword":"  alias  "'));
  });
  test('escapes metadata and preserves body boundary variants', () {
    for (final body in [
      'no final newline',
      'space  \n',
      'line\r\n',
      '~~~\n```\n`````\nend',
    ]) {
      final raw = rawDocument();
      rawEntry(raw)['body'] = body;
      rawEntry(raw)['title'] = 'Injected\n# Heading\n```';
      final bytes = LibraryMarkdownExport().encode(
        LibraryDocument.fromValue(raw),
      );
      final text = utf8.decode(bytes);
      expect(text, contains(body));
      expect(text, isNot(contains('\n# Heading\n')));
      expect(text, contains('Injected\\n# Heading\\n```'));
    }
  });
  for (final ending in {
    'CR': '\r',
    'LF': '\n',
    'CRLF': '\r\n',
    'none': '',
  }.entries) {
    test('separates the next entry after body ending ${ending.key}', () {
      final raw = rawDocument();
      final body = '  Я 🦊\r\n`````\nend  ${ending.value}';
      final first = rawEntry(raw)..['body'] = body;
      (raw['entries']! as List).add({
        ...first,
        'id': 'entry-2',
        'body': 'Next body',
      });
      final document = LibraryDocument.fromValue(raw);
      final text = utf8.decode(LibraryMarkdownExport().encode(document));
      final blocks = RegExp(r'\n\n(`{3,})\n([\s\S]*?)\n\1\n')
          .allMatches(text)
          .toList();

      expect(blocks, hasLength(2));
      expect(blocks.first.group(1), '``````');
      expect(
        blocks.first.group(2),
        body.endsWith('\n') ? body.substring(0, body.length - 1) : body,
      );
      expect(blocks.last.group(2), 'Next body');
      expect(
        text.substring(blocks.first.end, blocks.last.start),
        startsWith('\n## Entry 2\n\n```json\n'),
      );
      expect(
        document.snapshot.entries
            .singleWhere((entry) => entry.id == 'entry-1')
            .body,
        body,
      );
    });
  }
  test('exports empty library and bounds output bytes', () {
    final doc = LibraryDocument(
      snapshot: const LibrarySnapshot.empty(),
      exportedAt: DateTime.utc(2026),
    );
    final bytes = LibraryMarkdownExport().encode(doc);
    expect(utf8.decode(bytes), contains('"categories":[]'));
    expect(utf8.decode(bytes), isNot(contains('## Entry')));
    expect(
      LibraryMarkdownExport(limits: DocumentLimits(maxBytes: bytes.length))
          .encode(doc),
      bytes,
    );
    expect(
      () => LibraryMarkdownExport(
        limits: DocumentLimits(maxBytes: bytes.length - 1),
      ).encode(doc),
      throwsA(
        isA<DocumentFailure>().having(
          (e) => e.code,
          'code',
          DocumentFailureCode.limitExceeded,
        ),
      ),
    );
  });
}

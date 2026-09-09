/// Raycast source contract tests.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/library/transfer/library_document.dart';
import 'package:prompt_library/src/library/transfer/raycast_snippet_decoder.dart';

void main() {
  test(
    'preserves exact text and keyword with explicit title transformation',
    () {
      final raw = [
        {
          'name': '  Title  ',
          'text': '  body\r\n{clipboard}  ',
          'keyword': '  key  ',
          'tags': ['x'],
        },
      ];
      final row = RaycastSnippetDecoder()
          .decode(utf8.encode(jsonEncode(raw)))
          .rows
          .single;
      expect(row.snippet!.title, 'Title');
      expect(row.snippet!.originalTitle, '  Title  ');
      expect(row.snippet!.body, '  body\r\n{clipboard}  ');
      expect(row.snippet!.keyword, '  key  ');
      expect(row.unknownFields, ['tags']);
      expect(row.hasPlaceholderSyntax, isTrue);
      expect(() => row.unknownFields.clear(), throwsUnsupportedError);
      expect(row.toString(), isNot(contains('clipboard')));
    },
  );
  test('reports row errors without discarding other rows', () {
    final rows = RaycastSnippetDecoder()
        .decode(
          utf8.encode(
            jsonEncode([
              3,
              {'name': ' ', 'text': 'body'},
              {'name': 'Title', 'text': ' '},
              {'name': 'Title', 'text': 'body', 'keyword': null},
              {'name': 'Good', 'text': 'body'},
              {'name': 'Blank keyword', 'text': 'body', 'keyword': ''},
            ]),
          ),
        )
        .rows;
    expect(rows.where((r) => r.failure != null), hasLength(4));
    expect(rows[0].failure!.rowIndex, 0);
    expect(rows[4].snippet!.keyword, isNull);
    expect(rows[5].snippet!.keyword, '');
    expect(() => rows.clear(), throwsUnsupportedError);
  });
  test('syntax duplicate keys and unknown invalid Unicode abort document', () {
    for (final input in [
      r'[{"name":"A","name":"B","text":"x"}]',
      r'[{"name":"A","text":"x","unknown":"\ud800"}]',
    ]) {
      expect(
        () => RaycastSnippetDecoder().decode(utf8.encode(input)),
        throwsA(isA<DocumentFailure>()),
      );
    }
    expect(
      () => RaycastSnippetDecoder().decode(utf8.encode('{}')),
      throwsA(isA<DocumentFailure>()),
    );
    expect(RaycastSnippetDecoder().decode(utf8.encode('[]')).rows, isEmpty);
  });
}

/// Document boundary outcome contracts.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/library/presentation/library_document_files.dart';

void main() {
  group('DocumentPickResult outcomes', () {
    test(
      'every pick outcome carries its payload and stays distinguishable',
      () {
        final outcomes = <DocumentPickResult>[
          DocumentPicked(fileName: 'a.json', bytes: Uint8List(0)),
          const DocumentPickCancelled(),
          const DocumentPickUnavailable(),
          const DocumentPickFailure(code: DocumentFileFailureCode.readFailed),
        ];

        final labels = outcomes.map((outcome) {
          return switch (outcome) {
            DocumentPicked(:final fileName) => 'picked:$fileName',
            DocumentPickCancelled() => 'cancelled',
            DocumentPickUnavailable() => 'unavailable',
            DocumentPickFailure(:final code) => 'failure:${code.name}',
          };
        }).toList();

        expect(labels, [
          'picked:a.json',
          'cancelled',
          'unavailable',
          'failure:readFailed',
        ]);
      },
    );
  });

  group('DocumentExportResult outcomes', () {
    test(
      'every export outcome carries its payload and stays distinguishable',
      () {
        final outcomes = <DocumentExportResult>[
          const DocumentSaved(path: '/tmp/library.json'),
          const DocumentExportCancelled(),
          const DocumentExportUnavailable(),
          const DocumentExportFailure(
            code: DocumentFileFailureCode.verifyFailed,
          ),
        ];

        final labels = outcomes.map((outcome) {
          return switch (outcome) {
            DocumentSaved(:final path) => 'saved:$path',
            DocumentExportCancelled() => 'cancelled',
            DocumentExportUnavailable() => 'unavailable',
            DocumentExportFailure(:final code) => 'failure:${code.name}',
          };
        }).toList();

        expect(labels, [
          'saved:/tmp/library.json',
          'cancelled',
          'unavailable',
          'failure:verifyFailed',
        ]);
      },
    );

    test('failure codes cover every channel outcome source', () {
      expect(DocumentFileFailureCode.values.length, 7);
    });
  });
}

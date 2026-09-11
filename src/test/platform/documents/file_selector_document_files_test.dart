/// File-selector document boundary tests.
library;

import 'dart:async';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/library/presentation/library_document_files.dart';
import 'package:prompt_library/src/library/transfer/library_document.dart';
import 'package:prompt_library/src/platform/documents/file_selector_document_files.dart';

/// In-memory XFile that keeps the chosen file name.
final class _MemoryJsonFile extends XFile {
  _MemoryJsonFile(List<int> payload, String fileName)
    : _payload = payload,
      _fileName = fileName,
      super.fromData(Uint8List.fromList(payload));

  final List<int> _payload;
  final String _fileName;

  @override
  String get name => _fileName;

  @override
  Stream<Uint8List> openRead([int? start, int? end]) {
    return Stream<Uint8List>.value(Uint8List.fromList(_payload));
  }
}

/// XFile whose reported length differs from its streamed payload.
final class _LyingLengthFile extends XFile {
  _LyingLengthFile(this.payload) : super.fromData(Uint8List.fromList(payload));

  final List<int> payload;

  @override
  Future<int> length() async => 4;

  @override
  Stream<Uint8List> openRead([int? start, int? end]) {
    return Stream<Uint8List>.value(Uint8List.fromList(payload));
  }
}

/// XFile whose read fails after a successful length probe.
final class _BrokenReadFile extends XFile {
  _BrokenReadFile() : super.fromData(Uint8List.fromList([1, 2, 3]));

  @override
  Future<int> length() async => 3;

  @override
  Stream<Uint8List> openRead([int? start, int? end]) {
    return Stream<Uint8List>.error(StateError('read failed'));
  }
}

void main() {
  group('FileSelectorDocumentFiles pickDocument', () {
    test('returns picked name and immutable bytes for a chosen file', () async {
      final payload = utf8.encode('{"a":1}');
      final files = FileSelectorDocumentFiles(
        pickFile: () async => _MemoryJsonFile(payload, 'library.json'),
      );

      final result = await files.pickDocument();

      expect(result, isA<DocumentPicked>());
      final picked = result as DocumentPicked;
      expect(picked.fileName, 'library.json');
      expect(picked.bytes, payload);
      expect(() => picked.bytes[0] = 0, throwsA(isA<UnsupportedError>()));
    });

    test('returns cancelled when the picker is dismissed', () async {
      final files = FileSelectorDocumentFiles(pickFile: () async => null);

      final result = await files.pickDocument();

      expect(result, isA<DocumentPickCancelled>());
    });

    test('rejects an oversized file before reading it', () async {
      final files = FileSelectorDocumentFiles(
        limits: DocumentLimits(maxBytes: 8),
        pickFile: () async => XFile.fromData(
          Uint8List.fromList(List<int>.filled(32, 65)),
          name: 'big.json',
        ),
      );

      final result = await files.pickDocument();

      expect(
        result,
        isA<DocumentPickFailure>().having(
          (failure) => failure.code,
          'code',
          DocumentFileFailureCode.limitExceeded,
        ),
      );
    });

    test('rejects growth between the length probe and the read', () async {
      final files = FileSelectorDocumentFiles(
        limits: DocumentLimits(maxBytes: 8),
        pickFile: () async => _LyingLengthFile(List<int>.filled(32, 66)),
      );

      final result = await files.pickDocument();

      expect(
        result,
        isA<DocumentPickFailure>().having(
          (failure) => failure.code,
          'code',
          DocumentFileFailureCode.limitExceeded,
        ),
      );
    });

    test('maps a failed read to a typed failure', () async {
      final files = FileSelectorDocumentFiles(
        pickFile: () async => _BrokenReadFile(),
      );

      final result = await files.pickDocument();

      expect(
        result,
        isA<DocumentPickFailure>().having(
          (failure) => failure.code,
          'code',
          DocumentFileFailureCode.readFailed,
        ),
      );
    });

    test('maps missing platform support to unavailable', () async {
      final files = FileSelectorDocumentFiles(
        pickFile: () => throw MissingPluginException(),
      );

      final result = await files.pickDocument();

      expect(result, isA<DocumentPickUnavailable>());
    });
  });

  group('FileSelectorDocumentFiles exportDocument', () {
    test('delegates to the native export client', () async {
      var calls = 0;
      DocumentExportKind? seenKind;
      String? seenName;
      Uint8List? seenBytes;
      final files = FileSelectorDocumentFiles(
        exportClient:
            ({required kind, required suggestedName, required bytes}) {
              calls += 1;
              seenKind = kind;
              seenName = suggestedName;
              seenBytes = bytes;
              return Future<DocumentExportResult>.value(
                const DocumentSaved(path: '/tmp/library.json'),
              );
            },
      );

      final result = await files.exportDocument(
        kind: DocumentExportKind.markdown,
        suggestedName: 'library.md',
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      expect(calls, 1);
      expect(seenKind, DocumentExportKind.markdown);
      expect(seenName, 'library.md');
      expect(seenBytes, Uint8List.fromList([1, 2, 3]));
      expect(result, const DocumentSaved(path: '/tmp/library.json'));
    });

    test('returns unavailable without an export client', () async {
      final files = FileSelectorDocumentFiles();

      final result = await files.exportDocument(
        kind: DocumentExportKind.json,
        suggestedName: 'library.json',
        bytes: Uint8List(0),
      );

      expect(result, isA<DocumentExportUnavailable>());
    });
  });
}

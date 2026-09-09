/// Readable library export.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'library_document.dart';

/// Exports readable complete documents.
final class LibraryMarkdownExport {
  /// Creates bounded exporter.
  LibraryMarkdownExport({DocumentLimits? limits})
    : limits = limits ?? DocumentLimits();
  final DocumentLimits limits;

  /// Writes complete Markdown bytes.
  Uint8List encode(LibraryDocument document) {
    final sink = DocumentByteSink(limits);
    final root = document.toValue();
    _text(sink, '# Prompt Library\n\n## Metadata\n\n');
    _json(sink, {
      'format': root['format'],
      'formatVersion': root['formatVersion'],
      'exportedAt': root['exportedAt'],
      'categories': root['categories'],
      'tags': root['tags'],
    });
    var index = 0;
    for (final value in root['entries']! as List) {
      final row = Map<String, Object?>.from(value as Map);
      final body = row.remove('body')! as String;
      _text(sink, '\n## Entry ${++index}\n\n');
      _json(sink, row);
      final fence = _fence(body);
      _text(sink, '\n$fence\n');
      _text(sink, body);
      if (!body.endsWith('\n')) _text(sink, '\n');
      _text(sink, '$fence\n');
    }
    return sink.takeBytes();
  }

  /// Chooses safe literal fence.
  String _fence(String body) {
    var longest = 0;
    var current = 0;
    for (final unit in body.codeUnits) {
      if (unit == 96) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 0;
      }
    }
    final length = longest < 3 ? 3 : longest + 1;
    if (length * 2 + body.length + 2 > limits.maxBytes) {
      throw const DocumentFailure(DocumentFailureCode.limitExceeded);
    }
    return String.fromCharCode(96) * length;
  }

  /// Streams exact text chunks.
  void _text(DocumentByteSink sink, String value) {
    final encoder = utf8.encoder.startChunkedConversion(_BorrowedSink(sink));
    encoder.add(value);
    encoder.close();
  }

  /// Streams escaped metadata block.
  void _json(DocumentByteSink sink, Object value) {
    _text(sink, String.fromCharCode(96) * 3 + 'json\n');
    final encoder = JsonUtf8Encoder().startChunkedConversion(
      _BorrowedSink(sink),
    );
    encoder.add(value);
    encoder.close();
    _text(sink, '\n${String.fromCharCode(96) * 3}\n');
  }
}

/// Keeps shared collector open.
final class _BorrowedSink implements Sink<List<int>> {
  /// Borrows parent byte sink.
  _BorrowedSink(this.parent);
  final DocumentByteSink parent;

  /// Forwards bounded chunk.
  @override
  void add(List<int> data) => parent.add(data);

  /// Retains parent sink ownership.
  @override
  void close() {}
}

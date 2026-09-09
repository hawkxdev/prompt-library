/// Raycast document decoding.
library;

import 'library_document.dart';
import 'library_json_codec.dart';

/// Holds exact imported text.
final class RaycastSnippet {
  /// Creates decoded text value.
  RaycastSnippet._(this.title, this.body, this.keyword, this.originalTitle);
  final String title;
  final String body;
  final String? keyword;
  final String originalTitle;
}

/// Holds immutable source row.
final class RaycastRow {
  /// Freezes source diagnostics.
  RaycastRow._(this.index, this.snippet, this.failure, Iterable<String> unknown)
    : unknownFields = List.unmodifiable(unknown);
  final int index;
  final RaycastSnippet? snippet;
  final DocumentFailure? failure;
  final List<String> unknownFields;

  /// Detects possible literal templates.
  bool get hasPlaceholderSyntax =>
      snippet != null && RegExp(r'\{[^{}]*\}').hasMatch(snippet!.body);
}

/// Holds immutable decoded rows.
final class RaycastDocument {
  /// Freezes decoded source rows.
  RaycastDocument._(Iterable<RaycastRow> rows) : rows = List.unmodifiable(rows);
  final List<RaycastRow> rows;
}

/// Decodes supported Raycast fields.
final class RaycastSnippetDecoder {
  /// Creates strictly bounded decoder.
  RaycastSnippetDecoder({DocumentLimits? limits})
    : _codec = LibraryJsonCodec(limits: limits);
  final LibraryJsonCodec _codec;

  /// Reads source without mutation.
  RaycastDocument decode(List<int> bytes) {
    final value = _codec.decodeValue(bytes);
    if (value is! List) {
      throw const DocumentFailure(DocumentFailureCode.invalidShape);
    }
    return RaycastDocument._([
      for (var i = 0; i < value.length; i++) _row(value[i], i),
    ]);
  }

  /// Classifies one decoded row.
  RaycastRow _row(Object? value, int index) {
    if (value is! Map) {
      return RaycastRow._(
        index,
        null,
        DocumentFailure(DocumentFailureCode.invalidShape, rowIndex: index),
        [],
      );
    }
    final unknown =
        value.keys
            .cast<String>()
            .where((key) => !const {'name', 'text', 'keyword'}.contains(key))
            .toList()
          ..sort();
    if (!value.containsKey('name') || !value.containsKey('text')) {
      return RaycastRow._(
        index,
        null,
        DocumentFailure(DocumentFailureCode.missingField, rowIndex: index),
        unknown,
      );
    }
    final name = value['name'];
    final text = value['text'];
    final keyword = value['keyword'];
    if (name is! String ||
        name.trim().isEmpty ||
        text is! String ||
        text.trim().isEmpty ||
        (value.containsKey('keyword') && keyword is! String)) {
      return RaycastRow._(
        index,
        null,
        DocumentFailure(DocumentFailureCode.invalidValue, rowIndex: index),
        unknown,
      );
    }
    return RaycastRow._(
      index,
      RaycastSnippet._(name.trim(), text, keyword as String?, name),
      null,
      unknown,
    );
  }
}

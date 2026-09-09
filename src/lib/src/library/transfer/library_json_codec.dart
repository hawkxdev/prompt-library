/// Strict document JSON boundary.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'library_document.dart';

/// Encodes validated portable documents.
final class LibraryJsonCodec {
  /// Creates bounded codec.
  LibraryJsonCodec({DocumentLimits? limits})
    : limits = limits ?? DocumentLimits();
  final DocumentLimits limits;

  /// Reads validated document.
  LibraryDocument decode(List<int> bytes) =>
      LibraryDocument.fromValue(decodeValue(bytes));

  /// Reads guarded JSON value.
  Object? decodeValue(List<int> bytes) {
    final text = _text(bytes);
    _JsonGuard(text, limits).check();
    try {
      return jsonDecode(text);
    } on FormatException {
      throw const DocumentFailure(DocumentFailureCode.invalidJson);
    }
  }

  /// Writes canonical bounded bytes.
  Uint8List encode(LibraryDocument document) {
    final sink = DocumentByteSink(limits);
    final encoder = JsonUtf8Encoder().startChunkedConversion(sink);
    encoder.add(document.toValue());
    encoder.close();
    final encoded = sink.takeBytes();
    if (encoded.length >= limits.maxBytes) {
      throw const DocumentFailure(DocumentFailureCode.limitExceeded);
    }
    final result = Uint8List(encoded.length + 1)
      ..setRange(0, encoded.length, encoded);
    result.last = 10;
    _JsonGuard(utf8.decode(result), limits).check();
    return result.asUnmodifiableView();
  }

  /// Decodes strictly bounded bytes.
  String _text(List<int> bytes) {
    if (bytes.length > limits.maxBytes) {
      throw const DocumentFailure(DocumentFailureCode.limitExceeded);
    }
    if (bytes.any((byte) => byte < 0 || byte > 255)) {
      throw const DocumentFailure(DocumentFailureCode.invalidUtf8);
    }
    try {
      return utf8.decode(bytes);
    } on FormatException {
      throw const DocumentFailure(DocumentFailureCode.invalidUtf8);
    }
  }
}

/// Checks lexical resource boundaries.
final class _JsonGuard {
  /// Creates scoped lexical guard.
  _JsonGuard(this.text, this.limits);
  final String text;
  final DocumentLimits limits;
  int index = 0;

  /// Checks one complete value.
  void check() {
    try {
      _value(0);
      _space();
      if (index != text.length) _invalid();
    } on FormatException {
      _invalid();
    }
  }

  /// Scans one JSON value.
  void _value(int depth) {
    _space();
    if (index >= text.length) _invalid();
    final code = text.codeUnitAt(index);
    if (code == 123 || code == 91) {
      if (depth >= limits.maxDepth) {
        throw DocumentFailure(DocumentFailureCode.limitExceeded, offset: index);
      }
      index++;
      if (code == 123) {
        _object(depth + 1);
      } else {
        _array(depth + 1);
      }
    } else if (code == 34) {
      _string();
    } else {
      final start = index;
      while (index < text.length && !_delimiter(text.codeUnitAt(index))) {
        index++;
      }
      if (index == start) _invalid();
      final value = jsonDecode(text.substring(start, index));
      if (value is Map || value is List || value is String) _invalid();
    }
  }

  /// Scans unique object keys.
  void _object(int depth) {
    final keys = <String>{};
    _space();
    if (_take(125)) return;
    while (true) {
      _space();
      if (index >= text.length || text.codeUnitAt(index) != 34) _invalid();
      final key = _string();
      if (!keys.add(key)) {
        throw DocumentFailure(DocumentFailureCode.duplicateKey, offset: index);
      }
      if (keys.length > limits.maxObjectKeys) {
        throw DocumentFailure(DocumentFailureCode.limitExceeded, offset: index);
      }
      _space();
      if (!_take(58)) _invalid();
      _value(depth);
      _space();
      if (_take(125)) return;
      if (!_take(44)) _invalid();
    }
  }

  /// Scans ordered array members.
  void _array(int depth) {
    _space();
    if (_take(93)) return;
    while (true) {
      _value(depth);
      _space();
      if (_take(93)) return;
      if (!_take(44)) _invalid();
    }
  }

  /// Decodes one lexical string.
  String _string() {
    final start = index++;
    while (index < text.length) {
      final code = text.codeUnitAt(index++);
      if (code == 92) {
        index++;
      } else if (code == 34) {
        final value = jsonDecode(text.substring(start, index)) as String;
        validateDocumentUnicode(value);
        return value;
      }
    }
    _invalid();
  }

  /// Consumes JSON whitespace only.
  void _space() {
    while (index < text.length) {
      final code = text.codeUnitAt(index);
      if (code != 32 && code != 9 && code != 10 && code != 13) return;
      index++;
    }
  }

  /// Consumes exact next delimiter.
  bool _take(int code) {
    if (index >= text.length || text.codeUnitAt(index) != code) return false;
    index++;
    return true;
  }

  /// Identifies scalar token boundary.
  bool _delimiter(int code) =>
      code == 32 ||
      code == 9 ||
      code == 10 ||
      code == 13 ||
      code == 44 ||
      code == 93 ||
      code == 125;

  /// Rejects syntax without content.
  Never _invalid() =>
      throw DocumentFailure(DocumentFailureCode.invalidJson, offset: index);
}

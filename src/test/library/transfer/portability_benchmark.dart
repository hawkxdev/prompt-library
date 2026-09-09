/// Synthetic portability resource measurement.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:prompt_library/src/library/models/entry.dart';
import 'package:prompt_library/src/library/models/library_snapshot.dart';
import 'package:prompt_library/src/library/transfer/library_document.dart';
import 'package:prompt_library/src/library/transfer/library_json_codec.dart';

/// Creates synthetic library document.
LibraryDocument document(String body) => LibraryDocument(
  snapshot: LibrarySnapshot(
    entries: [
      Entry(
        id: 'benchmark',
        title: 'Synthetic',
        body: body,
        keyword: '',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    ],
  ),
  exportedAt: DateTime.utc(2026),
);

/// Measures bounded document processing.
void main() {
  final codec = LibraryJsonCodec();
  final limit = DocumentLimits().maxBytes;
  final overhead = codec.encode(document('x')).length - 1;
  final input = document('x' * (limit - overhead));
  final watch = Stopwatch()..start();
  final bytes = codec.encode(input);
  final encodeMs = watch.elapsedMilliseconds;
  watch.reset();
  final decoded = codec.decode(bytes);
  final decodeMs = watch.elapsedMilliseconds;
  if (bytes.length != limit || decoded.snapshot != input.snapshot) {
    throw StateError('roundtrip failed');
  }
  final over = Uint8List(limit + 1)..setRange(0, limit, bytes);
  watch.reset();
  var refused = false;
  try {
    codec.decode(over);
  } on DocumentFailure catch (e) {
    refused = e.code == DocumentFailureCode.limitExceeded;
  }
  if (!refused) {
    throw StateError('oversize accepted');
  }
  stdout.writeln(
    jsonEncode({
      'inputBytes': bytes.length,
      'encodeMs': encodeMs,
      'decodeMs': decodeMs,
      'oversizeRejectMicros': watch.elapsedMicroseconds,
      'currentRssBytes': ProcessInfo.currentRss,
      'maxRssBytes': ProcessInfo.maxRss,
      'roundtrip': true,
      'oversizeRejected': refused,
    }),
  );
}

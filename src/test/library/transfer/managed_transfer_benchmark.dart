/// Measures event loop access during document preparation.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:prompt_library/src/library/models/library_snapshot.dart';
import 'package:prompt_library/src/library/presentation/library_controller.dart';
import 'package:prompt_library/src/library/presentation/library_document_files.dart';
import 'package:prompt_library/src/library/presentation/transfer/library_transfer_controller.dart';
import 'package:prompt_library/src/library/transfer/library_document.dart';
import 'package:prompt_library/src/library/transfer/library_json_codec.dart';

import '../../support/library_test_support.dart';

/// Measures the default controller at the document size boundary.
Future<void> main() async {
  final repository = TestLibraryRepository();
  final library = LibraryController(repository: repository);
  final files = TestDocumentFiles();
  final controller = LibraryTransferController(
    repository: repository,
    library: library,
    files: files,
    now: () => DateTime.utc(2026),
  );
  final codec = LibraryJsonCodec();
  final limit = DocumentLimits().maxBytes;
  final entry = testEntry('benchmark', body: 'x');
  final overhead =
      codec
          .encode(
            LibraryDocument(
              snapshot: LibrarySnapshot(entries: [entry]),
              exportedAt: DateTime.utc(2026),
            ),
          )
          .length -
      1;
  repository.emit(
    LibrarySnapshot(entries: [entry.copyWith(body: 'x' * (limit - overhead))]),
  );
  var ticks = 0;
  final timer = Timer.periodic(const Duration(milliseconds: 1), (_) => ticks++);
  final watch = Stopwatch()..start();
  await controller.prepareExport(DocumentExportKind.json);
  watch.stop();
  timer.cancel();
  stdout.writeln(
    jsonEncode({
      'documentBytes': limit,
      'elapsedMilliseconds': watch.elapsedMilliseconds,
      'eventLoopTicks': ticks,
      'state': controller.state.runtimeType.toString(),
      'maxRssBytes': ProcessInfo.maxRss,
    }),
  );
  await controller.dispose();
  await library.dispose();
  await repository.close();
}

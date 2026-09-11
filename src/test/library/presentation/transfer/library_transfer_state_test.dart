/// Transfer operation state tests.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/library/presentation/library_document_files.dart';
import 'package:prompt_library/src/library/presentation/transfer/library_transfer_state.dart';
import 'package:prompt_library/src/library/transfer/library_document.dart';
import 'package:prompt_library/src/library/transfer/library_transfer_plan.dart';

void main() {
  group('LibraryTransferIdle', () {
    test('is a value object', () {
      expect(const LibraryTransferIdle(), const LibraryTransferIdle());
      expect(
        const LibraryTransferIdle().hashCode,
        const LibraryTransferIdle().hashCode,
      );
    });
  });

  group('LibraryTransferExportReady', () {
    test('distinguishes kind, name, and notification path', () {
      const ready = LibraryTransferExportReady(
        kind: DocumentExportKind.json,
        fileName: 'prompt-library-2026-09-11.json',
      );
      final notified = ready.copyWith(savedPath: '/tmp/out.json');

      expect(ready, ready.copyWith());
      expect(notified, isNot(ready));
      expect(
        LibraryTransferExportReady(
          kind: DocumentExportKind.markdown,
          fileName: ready.fileName,
        ),
        isNot(ready),
      );
    });
  });

  group('LibraryTransferImportDone', () {
    test('compares outcome maps by content and warns independently', () {
      const done = LibraryTransferImportDone(
        outcomeCounts: {
          ImportRowOutcome.selected: 2,
          ImportRowOutcome.duplicate: 1,
        },
        warningRowCount: 1,
      );
      final same = LibraryTransferImportDone(
        outcomeCounts: {
          ImportRowOutcome.selected: 2,
          ImportRowOutcome.duplicate: 1,
        },
        warningRowCount: 1,
      );
      final otherCounts = LibraryTransferImportDone(
        outcomeCounts: {
          ImportRowOutcome.selected: 3,
          ImportRowOutcome.duplicate: 1,
        },
        warningRowCount: 1,
      );
      final otherWarnings = LibraryTransferImportDone(
        outcomeCounts: {
          ImportRowOutcome.selected: 2,
          ImportRowOutcome.duplicate: 1,
        },
        warningRowCount: 2,
      );

      expect(done, same);
      expect(done.hashCode, same.hashCode);
      expect(done, isNot(otherCounts));
      expect(done, isNot(otherWarnings));
    });
  });

  group('LibraryTransferUnsupportedFile and LibraryTransferFailed', () {
    test('compares failures by stable diagnostic identity', () {
      const first = DocumentFailure(DocumentFailureCode.invalidShape);
      const second = DocumentFailure(DocumentFailureCode.invalidShape);
      const other = DocumentFailure(DocumentFailureCode.invalidJson);

      expect(
        LibraryTransferUnsupportedFile(failure: first),
        LibraryTransferUnsupportedFile(failure: second),
      );
      expect(
        LibraryTransferUnsupportedFile(failure: first).hashCode,
        LibraryTransferUnsupportedFile(failure: second).hashCode,
      );
      expect(
        LibraryTransferUnsupportedFile(failure: first),
        isNot(LibraryTransferUnsupportedFile(failure: other)),
      );
      expect(
        const LibraryTransferFailed(code: DocumentFileFailureCode.readFailed),
        const LibraryTransferFailed(code: DocumentFileFailureCode.readFailed),
      );
      expect(
        const LibraryTransferFailed(code: DocumentFileFailureCode.readFailed),
        isNot(
          const LibraryTransferFailed(
            code: DocumentFileFailureCode.writeFailed,
          ),
        ),
      );
    });
  });

  group('sealed phase hierarchy', () {
    test('freezes import outcome maps against mutation', () {
      const done = LibraryTransferImportDone(
        outcomeCounts: {ImportRowOutcome.selected: 1},
        warningRowCount: 0,
      );

      expect(
        () => done.outcomeCounts[ImportRowOutcome.selected] = 5,
        throwsUnsupportedError,
      );
    });
  });
}

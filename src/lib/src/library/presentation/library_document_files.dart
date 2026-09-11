/// Library document file boundary.
library;

import 'dart:typed_data';

/// Kind of exported document.
enum DocumentExportKind {
  /// Canonical JSON backup document.
  json,

  /// Readable Markdown export.
  markdown,
}

/// Reason a document file operation failed.
enum DocumentFileFailureCode {
  /// Input exceeded the document byte budget.
  limitExceeded,

  /// Reading the picked file failed.
  readFailed,

  /// Export arguments or file type were rejected.
  invalidArguments,

  /// The target file already exists and was not overwritten.
  existingFile,

  /// Writing the target file failed.
  writeFailed,

  /// Written bytes did not match the requested bytes.
  verifyFailed,

  /// The native boundary returned an unrecognized outcome.
  unknownOutcome,
}

/// Result of picking one input document.
sealed class DocumentPickResult {
  /// Creates a pick outcome.
  const DocumentPickResult();
}

/// A document was picked and fully read.
final class DocumentPicked extends DocumentPickResult {
  /// Creates a picked document.
  const DocumentPicked({required this.fileName, required this.bytes});

  /// Original file name as chosen by the user.
  final String fileName;

  /// Immutable document bytes.
  final Uint8List bytes;

  /// Checks value equality.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DocumentPicked &&
          other.fileName == fileName &&
          _bytesEqual(other.bytes, bytes));

  /// Computes hash code.
  @override
  int get hashCode => Object.hash(fileName, Object.hashAll(bytes));
}

/// The user cancelled the picker.
final class DocumentPickCancelled extends DocumentPickResult {
  /// Creates a cancelled outcome.
  const DocumentPickCancelled();
}

/// No document boundary is available on this platform.
final class DocumentPickUnavailable extends DocumentPickResult {
  /// Creates an unavailable outcome.
  const DocumentPickUnavailable();
}

/// The pick or read failed.
final class DocumentPickFailure extends DocumentPickResult {
  /// Creates a failed outcome.
  const DocumentPickFailure({required this.code});

  /// Stable failure reason.
  final DocumentFileFailureCode code;

  /// Checks value equality.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DocumentPickFailure && other.code == code);

  /// Computes hash code.
  @override
  int get hashCode => Object.hash(runtimeType, code);
}

/// Result of exporting prepared bytes.
sealed class DocumentExportResult {
  /// Creates an export outcome.
  const DocumentExportResult();
}

/// Bytes were saved and verified at the chosen path.
final class DocumentSaved extends DocumentExportResult {
  /// Creates a saved outcome.
  const DocumentSaved({required this.path});

  /// Absolute path of the verified file.
  final String path;

  /// Checks value equality.
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is DocumentSaved && other.path == path);

  /// Computes hash code.
  @override
  int get hashCode => Object.hash(runtimeType, path);
}

/// The user cancelled the save dialog.
final class DocumentExportCancelled extends DocumentExportResult {
  /// Creates a cancelled outcome.
  const DocumentExportCancelled();
}

/// Native export is not available on this platform.
final class DocumentExportUnavailable extends DocumentExportResult {
  /// Creates an unavailable outcome.
  const DocumentExportUnavailable();
}

/// The export failed.
final class DocumentExportFailure extends DocumentExportResult {
  /// Creates a failed outcome.
  const DocumentExportFailure({required this.code});

  /// Stable failure reason.
  final DocumentFileFailureCode code;

  /// Checks value equality.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DocumentExportFailure && other.code == code);

  /// Computes hash code.
  @override
  int get hashCode => Object.hash(runtimeType, code);
}

/// Compares byte lists by content.
bool _bytesEqual(Uint8List a, Uint8List b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Library document file boundary.
abstract interface class LibraryDocumentFiles {
  /// Picks and reads one input JSON document.
  Future<DocumentPickResult> pickDocument();

  /// Exports prepared bytes under the suggested name.
  Future<DocumentExportResult> exportDocument({
    required DocumentExportKind kind,
    required String suggestedName,
    required Uint8List bytes,
  });
}

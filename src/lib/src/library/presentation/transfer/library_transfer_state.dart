/// Immutable transfer operation states.
library;

import '../../models/library_failure.dart';
import '../../transfer/library_document.dart';
import '../../transfer/library_transfer_plan.dart';
import '../library_document_files.dart';

/// Phases of the managed transfer operation.
///
/// Illegal combinations are inexpressible: every phase is a distinct final
/// class, and exhaustive switches over the hierarchy need no default branch.
sealed class LibraryTransferState {
  /// Creates a transfer state.
  const LibraryTransferState();
}

/// No operation is in progress.
final class LibraryTransferIdle extends LibraryTransferState {
  /// Creates the idle state.
  const LibraryTransferIdle();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is LibraryTransferIdle;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'LibraryTransferIdle()';
}

/// Prepared export bytes await the native save flow.
final class LibraryTransferExportReady extends LibraryTransferState {
  /// Creates the export-ready state.
  const LibraryTransferExportReady({
    required this.kind,
    required this.fileName,
    this.savedPath,
  });

  /// Prepared document kind.
  final DocumentExportKind kind;

  /// Default file name presented to the save flow.
  final String fileName;

  /// Informational path of the last successful save; the file is not
  /// readable through it after security-scoped access ends.
  final String? savedPath;

  /// Copies the notification path.
  LibraryTransferExportReady copyWith({String? savedPath}) {
    return LibraryTransferExportReady(
      kind: kind,
      fileName: fileName,
      savedPath: savedPath ?? this.savedPath,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LibraryTransferExportReady &&
          other.kind == kind &&
          other.fileName == fileName &&
          other.savedPath == savedPath;

  @override
  int get hashCode => Object.hash(runtimeType, kind, fileName, savedPath);

  @override
  String toString() =>
      'LibraryTransferExportReady(kind: $kind, fileName: $fileName,'
      ' savedPath: $savedPath)';
}

/// Full restore preview over every entity collection.
final class LibraryTransferRestoreReview extends LibraryTransferState {
  /// Creates the restore-review state.
  const LibraryTransferRestoreReview({required this.plan});

  /// Compared snapshots with per-entity differences.
  final LibraryRestorePlan plan;

  @override
  bool operator ==(Object other) =>
      other is LibraryTransferRestoreReview && other.plan == plan;

  @override
  int get hashCode => Object.hash(runtimeType, plan);

  @override
  String toString() => 'LibraryTransferRestoreReview(plan: $plan)';
}

/// Raycast import preview with per-row outcomes.
final class LibraryTransferRaycastReview extends LibraryTransferState {
  /// Creates the Raycast-review state.
  const LibraryTransferRaycastReview({required this.plan});

  /// Classified rows against the captured snapshot.
  final RaycastImportPlan plan;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LibraryTransferRaycastReview && other.plan == plan;

  @override
  int get hashCode => Object.hash(runtimeType, plan);

  @override
  String toString() => 'LibraryTransferRaycastReview(plan: $plan)';
}

/// A verified external copy of the current library is required.
final class LibraryTransferBackupRequired extends LibraryTransferState {
  /// Creates the backup-required state.
  const LibraryTransferBackupRequired({required this.backupName});

  /// Default name of the external backup copy.
  final String backupName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LibraryTransferBackupRequired && other.backupName == backupName;

  @override
  int get hashCode => Object.hash(runtimeType, backupName);

  @override
  String toString() => 'LibraryTransferBackupRequired(backupName: $backupName)';
}

/// The external copy was saved and awaits re-reading.
final class LibraryTransferBackupSaved extends LibraryTransferState {
  /// Creates the backup-saved state.
  const LibraryTransferBackupSaved({
    required this.backupName,
    required this.savedPath,
  });

  /// Name of the saved external copy.
  final String backupName;

  /// Informational path reported by the system flow.
  final String savedPath;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LibraryTransferBackupSaved &&
          other.backupName == backupName &&
          other.savedPath == savedPath;

  @override
  int get hashCode => Object.hash(runtimeType, backupName, savedPath);

  @override
  String toString() =>
      'LibraryTransferBackupSaved(backupName: $backupName,'
      ' savedPath: $savedPath)';
}

/// The re-read copy matches; the operation awaits explicit confirmation.
final class LibraryTransferBackupVerified extends LibraryTransferState {
  /// Creates the backup-verified state.
  const LibraryTransferBackupVerified({required this.backupName});

  /// Name of the verified external copy; null when the current library is
  /// empty and the HLD waives the copy.
  final String? backupName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LibraryTransferBackupVerified && other.backupName == backupName;

  @override
  int get hashCode => Object.hash(runtimeType, backupName);

  @override
  String toString() => 'LibraryTransferBackupVerified(backupName: $backupName)';
}

/// The library changed after the review; a new preview and copy are required.
final class LibraryTransferStale extends LibraryTransferState {
  /// Creates the stale state.
  const LibraryTransferStale();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is LibraryTransferStale;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'LibraryTransferStale()';
}

/// The application is inside the atomic repository transaction.
final class LibraryTransferApplying extends LibraryTransferState {
  /// Creates the applying state.
  const LibraryTransferApplying();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is LibraryTransferApplying;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'LibraryTransferApplying()';
}

/// The restore replaced the library.
final class LibraryTransferRestoreDone extends LibraryTransferState {
  /// Creates the restore-done state.
  const LibraryTransferRestoreDone({
    required this.entriesChanged,
    required this.categoriesChanged,
    required this.tagsChanged,
    required this.backupName,
  });

  /// Number of entries added, removed, or modified.
  final int entriesChanged;

  /// Number of categories added, removed, or modified.
  final int categoriesChanged;

  /// Number of tags added, removed, or modified.
  final int tagsChanged;

  /// Name of the verified external copy kept outside the app container.
  final String backupName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LibraryTransferRestoreDone &&
          other.entriesChanged == entriesChanged &&
          other.categoriesChanged == categoriesChanged &&
          other.tagsChanged == tagsChanged &&
          other.backupName == backupName;

  @override
  int get hashCode => Object.hash(
    runtimeType,
    entriesChanged,
    categoriesChanged,
    tagsChanged,
    backupName,
  );

  @override
  String toString() =>
      'LibraryTransferRestoreDone(entries: $entriesChanged,'
      ' categories: $categoriesChanged, tags: $tagsChanged,'
      ' backupName: $backupName)';
}

/// The Raycast import applied with mutually exclusive row outcomes.
final class LibraryTransferImportDone extends LibraryTransferState {
  /// Creates the import-done state.
  const LibraryTransferImportDone({
    required this.outcomeCounts,
    required this.warningRowCount,
  });

  /// Counts per row outcome; added plus every skipped kind equals the row
  /// count of the source file.
  final Map<ImportRowOutcome, int> outcomeCounts;

  /// Rows with unknown fields or placeholder-like text; warning rows may
  /// intersect any outcome and are not part of the outcome sum.
  final int warningRowCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LibraryTransferImportDone &&
          _mapEquals(other.outcomeCounts, outcomeCounts) &&
          other.warningRowCount == warningRowCount;

  @override
  int get hashCode => Object.hash(
    runtimeType,
    Object.hashAll(
      outcomeCounts.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
    warningRowCount,
  );

  @override
  String toString() =>
      'LibraryTransferImportDone(outcomeCounts: $outcomeCounts,'
      ' warningRowCount: $warningRowCount)';
}

/// The picked file is not a supported transfer document.
final class LibraryTransferUnsupportedFile extends LibraryTransferState {
  /// Creates the unsupported-file state.
  const LibraryTransferUnsupportedFile({required this.failure});

  /// Stable content-level reason; never carries document content.
  final DocumentFailure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LibraryTransferUnsupportedFile &&
          _failureEquals(other.failure, failure);

  @override
  int get hashCode => Object.hash(runtimeType, failure.code, failure.field);

  @override
  String toString() => 'LibraryTransferUnsupportedFile(failure: $failure)';
}

/// A file-boundary operation failed.
final class LibraryTransferFailed extends LibraryTransferState {
  /// Creates the failed state.
  const LibraryTransferFailed({this.code, this.failure, this.libraryFailure});

  /// Boundary failure reason, when the boundary reported one.
  final DocumentFileFailureCode? code;

  /// Content failure reason, when preparation rejected the document.
  final DocumentFailure? failure;

  /// Repository failure of the atomic application; the review plan stays
  /// alive when this is set.
  final LibraryFailure? libraryFailure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LibraryTransferFailed &&
          other.code == code &&
          _failureEquals(other.failure, failure) &&
          other.libraryFailure == libraryFailure;

  @override
  int get hashCode => Object.hash(
    runtimeType,
    code,
    failure?.code,
    failure?.field,
    libraryFailure,
  );

  @override
  String toString() => 'LibraryTransferFailed(code: $code, failure: $failure)';
}

/// Compares failures by stable diagnostic identity, not by instance.
bool _failureEquals(DocumentFailure? a, DocumentFailure? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  return a.code == b.code &&
      a.rowIndex == b.rowIndex &&
      a.offset == b.offset &&
      a.field == b.field &&
      a.collection == b.collection;
}

/// Compares outcome count maps.
bool _mapEquals(Map<ImportRowOutcome, int> a, Map<ImportRowOutcome, int> b) {
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (b[key] != a[key]) return false;
  }
  return true;
}

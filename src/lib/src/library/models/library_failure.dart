/// Library failure models.
library;

/// Input validation failure reasons.
enum LibraryInputFailureReason {
  /// Empty title error.
  emptyTitle,

  /// Empty body error.
  emptyBody,

  /// Invalid keyword error.
  invalidKeyword,

  /// Unknown category error.
  unknownCategory,

  /// Unknown tag error.
  unknownTag,

  /// Empty category name error.
  emptyCategoryName,

  /// Empty tag name error.
  emptyTagName,

  /// Empty name error.
  emptyName,
}

/// Database failure error codes.
enum LibraryDatabaseFailureCode {
  /// Unknown database error.
  unknown,

  /// Constraint violation error.
  constraintViolation,

  /// Read failure error.
  readFailed,

  /// Write failure error.
  writeFailed,

  /// Transaction failure error.
  transactionFailed,

  /// Closed connection error.
  connectionClosed,

  /// Corrupt database error.
  corrupt,
}

/// Library operation failure.
sealed class LibraryFailure implements Exception {
  /// Creates library failure.
  const LibraryFailure();

  /// Duplicate category name error.
  const factory LibraryFailure.duplicateCategoryName() =
      DuplicateCategoryNameLibraryFailure;

  /// Duplicate tag name error.
  const factory LibraryFailure.duplicateTagName() =
      DuplicateTagNameLibraryFailure;

  /// Entry not found error.
  const factory LibraryFailure.entryNotFound({required String id}) =
      EntryNotFoundLibraryFailure;

  /// Category not found error.
  const factory LibraryFailure.categoryNotFound({required String id}) =
      CategoryNotFoundLibraryFailure;

  /// Tag not found error.
  const factory LibraryFailure.tagNotFound({required String id}) =
      TagNotFoundLibraryFailure;

  /// Invalid input error.
  const factory LibraryFailure.invalidInput(LibraryInputFailureReason reason) =
      InvalidInputLibraryFailure;

  /// Invalid category reorder error.
  const factory LibraryFailure.invalidCategoryReorder({
    int? expectedCount,
    int? actualCount,
  }) = InvalidCategoryReorderLibraryFailure;

  /// Database failure error.
  const factory LibraryFailure.databaseFailure({
    required LibraryDatabaseFailureCode code,
  }) = DatabaseFailureLibraryFailure;
}

/// Duplicate category name failure.
final class DuplicateCategoryNameLibraryFailure extends LibraryFailure {
  /// Creates duplicate category failure.
  const DuplicateCategoryNameLibraryFailure();

  /// Checks value equality.
  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DuplicateCategoryNameLibraryFailure;

  /// Computes hash code.
  @override
  int get hashCode => runtimeType.hashCode;

  /// Returns string representation.
  @override
  String toString() => 'LibraryFailure.duplicateCategoryName()';
}

/// Duplicate tag name failure.
final class DuplicateTagNameLibraryFailure extends LibraryFailure {
  /// Creates duplicate tag failure.
  const DuplicateTagNameLibraryFailure();

  /// Checks value equality.
  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DuplicateTagNameLibraryFailure;

  /// Computes hash code.
  @override
  int get hashCode => runtimeType.hashCode;

  /// Returns string representation.
  @override
  String toString() => 'LibraryFailure.duplicateTagName()';
}

/// Entry not found failure.
final class EntryNotFoundLibraryFailure extends LibraryFailure {
  /// Target entry identifier.
  final String id;

  /// Creates missing entry failure.
  const EntryNotFoundLibraryFailure({required this.id});

  /// Checks value equality.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EntryNotFoundLibraryFailure && other.id == id);

  /// Computes hash code.
  @override
  int get hashCode => Object.hash(runtimeType, id);

  /// Returns string representation.
  @override
  String toString() => 'LibraryFailure.entryNotFound(id: $id)';
}

/// Category not found failure.
final class CategoryNotFoundLibraryFailure extends LibraryFailure {
  /// Target category identifier.
  final String id;

  /// Creates missing category failure.
  const CategoryNotFoundLibraryFailure({required this.id});

  /// Checks value equality.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryNotFoundLibraryFailure && other.id == id);

  /// Computes hash code.
  @override
  int get hashCode => Object.hash(runtimeType, id);

  /// Returns string representation.
  @override
  String toString() => 'LibraryFailure.categoryNotFound(id: $id)';
}

/// Tag not found failure.
final class TagNotFoundLibraryFailure extends LibraryFailure {
  /// Target tag identifier.
  final String id;

  /// Creates missing tag failure.
  const TagNotFoundLibraryFailure({required this.id});

  /// Checks value equality.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TagNotFoundLibraryFailure && other.id == id);

  /// Computes hash code.
  @override
  int get hashCode => Object.hash(runtimeType, id);

  /// Returns string representation.
  @override
  String toString() => 'LibraryFailure.tagNotFound(id: $id)';
}

/// Invalid input failure.
final class InvalidInputLibraryFailure extends LibraryFailure {
  /// Input failure reason.
  final LibraryInputFailureReason reason;

  /// Creates invalid input failure.
  const InvalidInputLibraryFailure(this.reason);

  /// Checks value equality.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InvalidInputLibraryFailure && other.reason == reason);

  /// Computes hash code.
  @override
  int get hashCode => Object.hash(runtimeType, reason);

  /// Returns string representation.
  @override
  String toString() => 'LibraryFailure.invalidInput(reason: ${reason.name})';
}

/// Invalid category reorder failure.
final class InvalidCategoryReorderLibraryFailure extends LibraryFailure {
  /// Expected category count.
  final int? expectedCount;

  /// Actual category count.
  final int? actualCount;

  /// Creates reorder failure.
  const InvalidCategoryReorderLibraryFailure({
    this.expectedCount,
    this.actualCount,
  });

  /// Checks value equality.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InvalidCategoryReorderLibraryFailure &&
          other.expectedCount == expectedCount &&
          other.actualCount == actualCount);

  /// Computes hash code.
  @override
  int get hashCode => Object.hash(runtimeType, expectedCount, actualCount);

  /// Returns string representation.
  @override
  String toString() =>
      'LibraryFailure.invalidCategoryReorder(expectedCount: $expectedCount, actualCount: $actualCount)';
}

/// Database failure.
final class DatabaseFailureLibraryFailure extends LibraryFailure {
  /// Database error code.
  final LibraryDatabaseFailureCode code;

  /// Creates database failure.
  const DatabaseFailureLibraryFailure({required this.code});

  /// Checks value equality.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DatabaseFailureLibraryFailure && other.code == code);

  /// Computes hash code.
  @override
  int get hashCode => Object.hash(runtimeType, code);

  /// Returns string representation.
  @override
  String toString() => 'LibraryFailure.databaseFailure(code: ${code.name})';
}

/// Entry update command model.
library;

/// Keyword change intent for an update command.
sealed class KeywordUpdate {
  /// Creates keyword intent.
  const KeywordUpdate();
}

/// Keeps the stored keyword untouched.
final class KeepExistingKeyword extends KeywordUpdate {
  /// Creates keep intent.
  const KeepExistingKeyword();

  /// Checks value equality.
  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is KeepExistingKeyword;

  /// Computes hash code.
  @override
  int get hashCode => runtimeType.hashCode;

  /// Returns string representation.
  @override
  String toString() => 'KeywordUpdate.keepExisting()';
}

/// Replaces the stored keyword with a normalized value.
final class ReplaceKeyword extends KeywordUpdate {
  /// Creates replace intent.
  const ReplaceKeyword(this.value);

  /// Requested keyword; blank values normalize to null at the repository.
  final String? value;

  /// Checks value equality.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReplaceKeyword && other.value == value);

  /// Computes hash code.
  @override
  int get hashCode => Object.hash(runtimeType, value);

  /// Returns string representation.
  @override
  String toString() => 'KeywordUpdate.replace()';
}

/// Entry update command.
final class EntryUpdate {
  /// Entry prompt title.
  final String title;

  /// Entry prompt body.
  final String body;

  /// Keyword change intent.
  final KeywordUpdate keyword;

  /// Optional category identifier.
  final String? categoryId;

  /// Associated tag identifiers.
  final List<String> tagIds;

  /// Favorite status flag.
  final bool isFavorite;

  /// Archived status flag.
  final bool isArchived;

  /// Creates entry update command.
  EntryUpdate({
    required this.title,
    required this.body,
    this.keyword = const KeepExistingKeyword(),
    this.categoryId,
    Iterable<String> tagIds = const [],
    this.isFavorite = false,
    this.isArchived = false,
  }) : tagIds = List.unmodifiable(tagIds.toSet().toList()..sort());

  /// Checks value equality.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EntryUpdate &&
          other.title == title &&
          other.body == body &&
          other.keyword == keyword &&
          other.categoryId == categoryId &&
          _listEquals(other.tagIds, tagIds) &&
          other.isFavorite == isFavorite &&
          other.isArchived == isArchived);

  /// Computes hash code.
  @override
  int get hashCode => Object.hash(
    title,
    body,
    keyword,
    categoryId,
    Object.hashAll(tagIds),
    isFavorite,
    isArchived,
  );
}

/// Compares string lists.
bool _listEquals(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Entry input model.
library;

/// Default copy sentinel.
const Object _sentinel = Object();

/// Validated entry payload.
final class EntryInput {
  /// Entry prompt title.
  final String title;

  /// Entry prompt body.
  final String body;

  /// Optional search keyword.
  final String? keyword;

  /// Optional category identifier.
  final String? categoryId;

  /// Associated tag identifiers.
  final List<String> tagIds;

  /// Favorite status flag.
  final bool isFavorite;

  /// Archived status flag.
  final bool isArchived;

  /// Creates entry input.
  EntryInput({
    required this.title,
    required this.body,
    this.keyword,
    this.categoryId,
    Iterable<String> tagIds = const [],
    this.isFavorite = false,
    this.isArchived = false,
  }) : tagIds = List.unmodifiable(tagIds.toSet().toList()..sort());

  /// Validates entry payload.
  factory EntryInput.validate({
    required String title,
    required String body,
    String? keyword,
    String? categoryId,
    Iterable<String> tagIds = const [],
    bool isFavorite = false,
    bool isArchived = false,
  }) {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError('title');
    }
    if (body.trim().isEmpty) {
      throw ArgumentError('body');
    }
    final trimmedKeyword = keyword?.trim();
    final effectiveKeyword =
        (trimmedKeyword != null && trimmedKeyword.isNotEmpty)
        ? trimmedKeyword
        : null;
    return EntryInput(
      title: trimmedTitle,
      body: body,
      keyword: effectiveKeyword,
      categoryId: categoryId,
      tagIds: tagIds,
      isFavorite: isFavorite,
      isArchived: isArchived,
    );
  }

  /// Creates updated copy.
  EntryInput copyWith({
    String? title,
    String? body,
    Object? keyword = _sentinel,
    Object? categoryId = _sentinel,
    Iterable<String>? tagIds,
    bool? isFavorite,
    bool? isArchived,
  }) {
    return EntryInput(
      title: title ?? this.title,
      body: body ?? this.body,
      keyword: identical(keyword, _sentinel)
          ? this.keyword
          : keyword as String?,
      categoryId: identical(categoryId, _sentinel)
          ? this.categoryId
          : categoryId as String?,
      tagIds: tagIds ?? this.tagIds,
      isFavorite: isFavorite ?? this.isFavorite,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  /// Checks value equality.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EntryInput &&
        other.title == title &&
        other.body == body &&
        other.keyword == keyword &&
        other.categoryId == categoryId &&
        _listEquals(other.tagIds, tagIds) &&
        other.isFavorite == isFavorite &&
        other.isArchived == isArchived;
  }

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

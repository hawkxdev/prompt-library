/// Entry domain entity.
library;

/// Default copy sentinel.
const Object _sentinel = Object();

/// Entry entity model.
final class Entry {
  /// Unique entity identifier.
  final String id;

  /// Entry prompt title.
  final String title;

  /// Entry prompt body.
  final String body;

  /// Quick search keyword.
  final String? keyword;

  /// Optional category identifier.
  final String? categoryId;

  /// Associated tag identifiers.
  final List<String> tagIds;

  /// Favorite status flag.
  final bool isFavorite;

  /// Archived status flag.
  final bool isArchived;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Last update timestamp.
  final DateTime updatedAt;

  /// Last copied timestamp.
  final DateTime? lastCopiedAt;

  /// Creates entry entity.
  Entry({
    required this.id,
    required this.title,
    required this.body,
    this.keyword,
    this.categoryId,
    Iterable<String> tagIds = const [],
    this.isFavorite = false,
    this.isArchived = false,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? lastCopiedAt,
  }) : tagIds = List.unmodifiable(tagIds.toSet().toList()..sort()),
       createdAt = createdAt.toUtc(),
       updatedAt = updatedAt.toUtc(),
       lastCopiedAt = lastCopiedAt?.toUtc();

  /// Creates updated copy.
  Entry copyWith({
    String? id,
    String? title,
    String? body,
    Object? keyword = _sentinel,
    Object? categoryId = _sentinel,
    Iterable<String>? tagIds,
    bool? isFavorite,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? lastCopiedAt = _sentinel,
  }) {
    return Entry(
      id: id ?? this.id,
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastCopiedAt: identical(lastCopiedAt, _sentinel)
          ? this.lastCopiedAt
          : (lastCopiedAt == null ? null : (lastCopiedAt as DateTime).toUtc()),
    );
  }

  /// Checks value equality.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Entry &&
        other.id == id &&
        other.title == title &&
        other.body == body &&
        other.keyword == keyword &&
        other.categoryId == categoryId &&
        _listEquals(other.tagIds, tagIds) &&
        other.isFavorite == isFavorite &&
        other.isArchived == isArchived &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.lastCopiedAt == lastCopiedAt;
  }

  /// Computes hash code.
  @override
  int get hashCode => Object.hash(
    id,
    title,
    body,
    keyword,
    categoryId,
    Object.hashAll(tagIds),
    isFavorite,
    isArchived,
    createdAt,
    updatedAt,
    lastCopiedAt,
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

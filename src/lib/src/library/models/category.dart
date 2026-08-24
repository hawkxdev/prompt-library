/// Category domain entity.
library;

/// Category entity model.
final class Category {
  /// Unique entity identifier.
  final String id;

  /// Display name.
  final String name;

  /// Normalized lookup name.
  final String normalizedName;

  /// Display sort order.
  final int sortOrder;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Creates category entity.
  Category({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.sortOrder,
    required DateTime createdAt,
  }) : createdAt = createdAt.toUtc();

  /// Creates updated copy.
  Category copyWith({
    String? id,
    String? name,
    String? normalizedName,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Checks value equality.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Category &&
        other.id == id &&
        other.name == name &&
        other.normalizedName == normalizedName &&
        other.sortOrder == sortOrder &&
        other.createdAt == createdAt;
  }

  /// Computes hash code.
  @override
  int get hashCode =>
      Object.hash(id, name, normalizedName, sortOrder, createdAt);
}

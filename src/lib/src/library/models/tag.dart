/// Tag domain entity.
library;

/// Tag entity model.
final class Tag {
  /// Unique entity identifier.
  final String id;

  /// Display name.
  final String name;

  /// Normalized lookup name.
  final String normalizedName;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Creates tag entity.
  Tag({
    required this.id,
    required this.name,
    required this.normalizedName,
    required DateTime createdAt,
  }) : createdAt = createdAt.toUtc();

  /// Creates updated copy.
  Tag copyWith({
    String? id,
    String? name,
    String? normalizedName,
    DateTime? createdAt,
  }) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Checks value equality.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Tag &&
        other.id == id &&
        other.name == name &&
        other.normalizedName == normalizedName &&
        other.createdAt == createdAt;
  }

  /// Computes hash code.
  @override
  int get hashCode => Object.hash(id, name, normalizedName, createdAt);
}

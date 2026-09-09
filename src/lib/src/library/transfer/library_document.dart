/// Portable library documents.
library;

import 'dart:typed_data';

import '../models/category.dart';
import '../models/entry.dart';
import '../models/library_snapshot.dart';
import '../models/normalization.dart';
import '../models/tag.dart';

/// Classifies safe document failures.
enum DocumentFailureCode {
  invalidUtf8,
  invalidJson,
  duplicateKey,
  limitExceeded,
  invalidUnicode,
  invalidShape,
  missingField,
  unsupportedField,
  unsupportedFormat,
  unsupportedVersion,
  invalidValue,
  invalidDate,
  duplicateId,
  duplicateName,
  duplicateLink,
  danglingReference,
}

/// Reports content free failure.
final class DocumentFailure implements Exception {
  /// Creates safe failure.
  const DocumentFailure(
    this.code, {
    this.rowIndex,
    this.offset,
    this.field,
    this.collection,
  });
  final DocumentFailureCode code;
  final int? rowIndex;
  final int? offset;
  final String? field;
  final String? collection;

  /// Describes safe diagnostic metadata.
  @override
  String toString() =>
      'DocumentFailure(${code.name}, row=$rowIndex, offset=$offset)';
}

/// Bounds portable document resources.
final class DocumentLimits {
  /// Validates resource configuration.
  DocumentLimits({
    this.maxBytes = 32 * 1024 * 1024,
    this.maxDepth = 32,
    this.maxObjectKeys = 4096,
  }) {
    if (maxBytes < 1 || maxDepth < 1 || maxObjectKeys < 1) {
      throw ArgumentError('Document limits must be positive');
    }
  }
  final int maxBytes;
  final int maxDepth;
  final int maxObjectKeys;
}

/// Collects bounded immutable bytes.
final class DocumentByteSink implements Sink<List<int>> {
  /// Creates bounded collector.
  DocumentByteSink(this.limits);
  final DocumentLimits limits;
  final BytesBuilder _builder = BytesBuilder();
  int _length = 0;
  bool _closed = false;

  /// Accepts one bounded chunk.
  @override
  void add(List<int> data) {
    if (_closed) throw StateError('Document sink is closed');
    if (data.length > limits.maxBytes - _length) {
      throw const DocumentFailure(DocumentFailureCode.limitExceeded);
    }
    _builder.add(data);
    _length += data.length;
  }

  /// Stops accepting chunks.
  @override
  void close() {
    _closed = true;
  }

  /// Returns immutable accumulated bytes.
  Uint8List takeBytes() {
    _closed = true;
    return _builder.takeBytes().asUnmodifiableView();
  }
}

/// Holds validated portable data.
final class LibraryDocument {
  /// Validates supplied snapshot.
  LibraryDocument({required this.snapshot, required DateTime exportedAt})
    : exportedAt = exportedAt.toUtc() {
    documentDate(this.exportedAt);
    validateLibrarySnapshot(snapshot);
  }

  /// Validates decoded document.
  factory LibraryDocument.fromValue(Object? value) {
    final root = _map(value, const {
      'format',
      'formatVersion',
      'exportedAt',
      'entries',
      'categories',
      'tags',
    });
    if (root['format'] != format) {
      throw const DocumentFailure(DocumentFailureCode.unsupportedFormat);
    }
    if (root['formatVersion'] is! int || root['formatVersion'] != version) {
      throw const DocumentFailure(DocumentFailureCode.unsupportedVersion);
    }
    final exported = parseDocumentDate(root['exportedAt']);
    _validateSnapshotValue(root);
    final categories = _list(root['categories']).map((value) {
      final row = value as Map;
      return Category(
        id: row['id'] as String,
        name: row['name'] as String,
        normalizedName: row['normalizedName'] as String,
        sortOrder: row['sortOrder'] as int,
        createdAt: parseDocumentDate(row['createdAt']),
      );
    });
    final tags = _list(root['tags']).map((value) {
      final row = value as Map;
      return Tag(
        id: row['id'] as String,
        name: row['name'] as String,
        normalizedName: row['normalizedName'] as String,
        createdAt: parseDocumentDate(row['createdAt']),
      );
    });
    final entries = _list(root['entries']).map((value) {
      final row = value as Map;
      return Entry(
        id: row['id'] as String,
        title: row['title'] as String,
        body: row['body'] as String,
        keyword: row['keyword'] as String?,
        categoryId: row['categoryId'] as String?,
        tagIds: (row['tagIds'] as List).cast<String>(),
        isFavorite: row['isFavorite'] as bool,
        isArchived: row['isArchived'] as bool,
        createdAt: parseDocumentDate(row['createdAt']),
        updatedAt: parseDocumentDate(row['updatedAt']),
        lastCopiedAt: row['lastCopiedAt'] == null
            ? null
            : parseDocumentDate(row['lastCopiedAt']),
      );
    });
    return LibraryDocument(
      snapshot: LibrarySnapshot(
        entries: entries,
        categories: categories,
        tags: tags,
      ),
      exportedAt: exported,
    );
  }

  static const String format = 'dev.hawkx.promptlibrary.library';
  static const int version = 1;
  final LibrarySnapshot snapshot;
  final DateTime exportedAt;

  /// Builds canonical document value.
  Map<String, Object?> toValue() => {
    'format': format,
    'formatVersion': version,
    'exportedAt': documentDate(exportedAt),
    ...librarySnapshotValue(snapshot),
  };
}

/// Rejects unpaired surrogate values.
void validateDocumentUnicode(String value) {
  for (var i = 0; i < value.length; i++) {
    final unit = value.codeUnitAt(i);
    if (unit >= 0xd800 && unit <= 0xdbff) {
      if (++i >= value.length ||
          value.codeUnitAt(i) < 0xdc00 ||
          value.codeUnitAt(i) > 0xdfff) {
        throw const DocumentFailure(DocumentFailureCode.invalidUnicode);
      }
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      throw const DocumentFailure(DocumentFailureCode.invalidUnicode);
    }
  }
}

/// Formats canonical UTC seconds.
String documentDate(DateTime date) {
  final utc = date.toUtc();
  if (utc.year < 1 ||
      utc.year > 9999 ||
      utc.millisecond != 0 ||
      utc.microsecond != 0) {
    throw const DocumentFailure(DocumentFailureCode.invalidDate);
  }
  return utc.toIso8601String().replaceFirst('.000Z', 'Z');
}

/// Parses exact calendar seconds.
DateTime parseDocumentDate(Object? value) {
  if (value is! String ||
      !RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$').hasMatch(value)) {
    throw const DocumentFailure(DocumentFailureCode.invalidDate);
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null || documentDate(parsed) != value) {
    throw const DocumentFailure(DocumentFailureCode.invalidDate);
  }
  return parsed;
}

/// Validates supplied library entities.
void validateLibrarySnapshot(LibrarySnapshot snapshot) {
  _validateSnapshotValue(librarySnapshotValue(snapshot));
}

/// Serializes complete canonical entities.
Map<String, Object?> librarySnapshotValue(LibrarySnapshot snapshot) {
  final entries = snapshot.entries.toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  final categories = snapshot.categories.toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  final tags = snapshot.tags.toList()..sort((a, b) => a.id.compareTo(b.id));
  return {
    'entries': [
      for (final e in entries)
        {
          'id': e.id,
          'title': e.title,
          'body': e.body,
          'keyword': e.keyword,
          'categoryId': e.categoryId,
          'tagIds': e.tagIds.toList()..sort(),
          'isFavorite': e.isFavorite,
          'isArchived': e.isArchived,
          'createdAt': documentDate(e.createdAt),
          'updatedAt': documentDate(e.updatedAt),
          'lastCopiedAt': e.lastCopiedAt == null
              ? null
              : documentDate(e.lastCopiedAt!),
        },
    ],
    'categories': [
      for (final c in categories)
        {
          'id': c.id,
          'name': c.name,
          'normalizedName': c.normalizedName,
          'sortOrder': c.sortOrder,
          'createdAt': documentDate(c.createdAt),
        },
    ],
    'tags': [
      for (final t in tags)
        {
          'id': t.id,
          'name': t.name,
          'normalizedName': t.normalizedName,
          'createdAt': documentDate(t.createdAt),
        },
    ],
  };
}

/// Checks raw entities before construction.
void _validateSnapshotValue(Map root) {
  final categoryIds = <String>{};
  final tagIds = <String>{};
  final entryIds = <String>{};
  final categoryNames = <String>{};
  final tagNames = <String>{};
  _eachRow(
    root,
    'categories',
    const {'id', 'name', 'normalizedName', 'sortOrder', 'createdAt'},
    (row) {
      _unique(
        categoryIds,
        _field(row, 'id', _string),
        DocumentFailureCode.duplicateId,
      );
      _taxonomy(row, categoryNames);
      _field(row, 'sortOrder', (value) {
        if (value is! int) {
          throw const DocumentFailure(DocumentFailureCode.invalidValue);
        }
        return value;
      });
    },
  );
  _eachRow(root, 'tags', const {'id', 'name', 'normalizedName', 'createdAt'}, (
    row,
  ) {
    _unique(
      tagIds,
      _field(row, 'id', _string),
      DocumentFailureCode.duplicateId,
    );
    _taxonomy(row, tagNames);
  });
  _eachRow(
    root,
    'entries',
    const {
      'id',
      'title',
      'body',
      'keyword',
      'categoryId',
      'tagIds',
      'isFavorite',
      'isArchived',
      'createdAt',
      'updatedAt',
      'lastCopiedAt',
    },
    (row) {
      _unique(
        entryIds,
        _field(row, 'id', _string),
        DocumentFailureCode.duplicateId,
      );
      for (final key in ['title', 'body']) {
        _field(row, key, (value) => _string(value, nonBlank: true));
      }
      if (row['keyword'] != null) {
        _field(row, 'keyword', (value) => _string(value, allowEmpty: true));
      }
      if (row['categoryId'] != null) {
        final id = _field(row, 'categoryId', _string);
        if (!categoryIds.contains(id)) {
          throw const DocumentFailure(
            DocumentFailureCode.danglingReference,
            field: 'categoryId',
          );
        }
      }
      for (final key in ['isFavorite', 'isArchived']) {
        _field(row, key, (value) {
          if (value is! bool) {
            throw const DocumentFailure(DocumentFailureCode.invalidValue);
          }
          return value;
        });
      }
      for (final key in ['createdAt', 'updatedAt']) {
        _field(row, key, parseDocumentDate);
      }
      if (row['lastCopiedAt'] != null) {
        _field(row, 'lastCopiedAt', parseDocumentDate);
      }
      _field(row, 'tagIds', (value) {
        final links = <String>{};
        for (final link in _list(value)) {
          final id = _string(link);
          _unique(links, id, DocumentFailureCode.duplicateLink);
          if (!tagIds.contains(id)) {
            throw const DocumentFailure(DocumentFailureCode.danglingReference);
          }
        }
        return links;
      });
    },
  );
}

/// Annotates raw row diagnostics.
void _eachRow(
  Map root,
  String collection,
  Set<String> keys,
  void Function(Map) validate,
) {
  final rows = _field(root, collection, _list);
  for (var i = 0; i < rows.length; i++) {
    try {
      validate(_map(rows[i], keys));
    } on DocumentFailure catch (error) {
      throw DocumentFailure(
        error.code,
        rowIndex: i,
        offset: error.offset,
        field: error.field,
        collection: collection,
      );
    }
  }
}

/// Annotates known schema fields.
T _field<T>(Map row, String field, T Function(Object?) validate) {
  try {
    return validate(row[field]);
  } on DocumentFailure catch (error) {
    throw DocumentFailure(
      error.code,
      rowIndex: error.rowIndex,
      offset: error.offset,
      field: field,
      collection: error.collection,
    );
  }
}

/// Validates taxonomy name contract.
void _taxonomy(Map row, Set<String> names) {
  final name = _field(row, 'name', (value) => _string(value, nonBlank: true));
  final normalized = _field(
    row,
    'normalizedName',
    (value) => _string(value, nonBlank: true),
  );
  if (normalizeMetadataName(name) != normalized) {
    throw const DocumentFailure(
      DocumentFailureCode.invalidValue,
      field: 'normalizedName',
    );
  }
  _unique(names, normalized, DocumentFailureCode.duplicateName);
  _field(row, 'createdAt', parseDocumentDate);
}

/// Validates required object keys.
Map _map(Object? value, Set<String> keys) {
  if (value is! Map) {
    throw const DocumentFailure(DocumentFailureCode.invalidShape);
  }
  for (final key in value.keys) {
    if (key is! String) {
      throw const DocumentFailure(DocumentFailureCode.invalidShape);
    }
    validateDocumentUnicode(key);
    if (!keys.contains(key)) {
      throw const DocumentFailure(DocumentFailureCode.unsupportedField);
    }
  }
  for (final key in keys) {
    if (!value.containsKey(key)) {
      throw DocumentFailure(DocumentFailureCode.missingField, field: key);
    }
  }
  return value;
}

/// Requires ordered input collection.
List _list(Object? value) {
  if (value is! List) {
    throw const DocumentFailure(DocumentFailureCode.invalidShape);
  }
  return value;
}

/// Validates exact string values.
String _string(
  Object? value, {
  bool allowEmpty = false,
  bool nonBlank = false,
}) {
  if (value is! String ||
      (!allowEmpty && value.isEmpty) ||
      (nonBlank && value.trim().isEmpty)) {
    throw const DocumentFailure(DocumentFailureCode.invalidValue);
  }
  validateDocumentUnicode(value);
  return value;
}

/// Rejects repeated set member.
void _unique(Set<String> seen, String value, DocumentFailureCode code) {
  if (!seen.add(value)) throw DocumentFailure(code);
}

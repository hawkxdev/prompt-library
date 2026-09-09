/// Portable document fixtures.
library;

import 'package:prompt_library/src/library/transfer/library_document.dart';

/// Builds complete raw document.
Map<String, Object?> rawDocument() => {
  'format': 'dev.hawkx.promptlibrary.library',
  'formatVersion': 1,
  'exportedAt': '2026-09-08T12:00:00Z',
  'entries': <Map<String, Object?>>[
    {
      'id': 'entry-1',
      'title': 'Title',
      'body': '  Я 🦊\r\n```\n~~~\nend  ',
      'keyword': '  alias  ',
      'categoryId': 'cat-1',
      'tagIds': ['tag-1'],
      'isFavorite': true,
      'isArchived': true,
      'createdAt': '2026-01-01T00:00:00Z',
      'updatedAt': '2026-09-07T01:02:03Z',
      'lastCopiedAt': '2026-09-08T01:02:03Z',
    },
  ],
  'categories': [
    {
      'id': 'cat-1',
      'name': 'Категория',
      'normalizedName': 'категория',
      'sortOrder': -1,
      'createdAt': '2026-01-01T00:00:00Z',
    },
    {
      'id': 'unused',
      'name': 'Unused',
      'normalizedName': 'unused',
      'sortOrder': 0,
      'createdAt': '2026-01-01T00:00:00Z',
    },
  ],
  'tags': [
    {
      'id': 'tag-1',
      'name': 'Tag',
      'normalizedName': 'tag',
      'createdAt': '2026-01-01T00:00:00Z',
    },
    {
      'id': 'unused',
      'name': 'Unused',
      'normalizedName': 'unused',
      'createdAt': '2026-01-01T00:00:00Z',
    },
  ],
};

/// Selects first raw entry.
Map<String, Object?> rawEntry(Map<String, Object?> root) =>
    (root['entries']! as List).first as Map<String, Object?>;

/// Builds validated fixture.
LibraryDocument documentFixture() => LibraryDocument.fromValue(rawDocument());

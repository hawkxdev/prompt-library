/// Architectural boundary tests.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/library/data/library_repository.dart';
import 'package:prompt_library/src/library/models/category.dart';
import 'package:prompt_library/src/library/models/entry.dart';
import 'package:prompt_library/src/library/models/entry_input.dart';
import 'package:prompt_library/src/library/models/library_snapshot.dart';
import 'package:prompt_library/src/library/models/tag.dart';

/// Boundary test repository.
final class _FakeLibraryRepository implements LibraryRepository {
  @override
  Stream<LibrarySnapshot> watchSnapshot() => const Stream.empty();

  @override
  Future<LibrarySnapshot> getSnapshot() async => const LibrarySnapshot.empty();

  @override
  Future<Entry> createEntry(EntryInput input) => throw UnimplementedError();

  @override
  Future<Entry> updateEntry(String id, EntryInput input) =>
      throw UnimplementedError();

  @override
  Future<void> deleteEntry(String id) => throw UnimplementedError();

  @override
  Future<void> markCopied(String id) => throw UnimplementedError();

  @override
  Future<void> setFavorite(String id, {required bool isFavorite}) =>
      throw UnimplementedError();

  @override
  Future<void> setArchived(String id, {required bool isArchived}) =>
      throw UnimplementedError();

  @override
  Future<Category> createCategory(String name) => throw UnimplementedError();

  @override
  Future<Category> renameCategory(String id, String newName) =>
      throw UnimplementedError();

  @override
  Future<void> deleteCategory(String id) => throw UnimplementedError();

  @override
  Future<void> reorderCategories(List<String> orderedCategoryIds) =>
      throw UnimplementedError();

  @override
  Future<Tag> createTag(String name) => throw UnimplementedError();

  @override
  Future<Tag> renameTag(String id, String newName) =>
      throw UnimplementedError();

  @override
  Future<void> deleteTag(String id) => throw UnimplementedError();
}

/// Finds application root directory.
Directory _findAppRoot() {
  var dir = Directory.current;
  if (File('${dir.path}/pubspec.yaml').existsSync() &&
      File('${dir.path}/lib/src/library/models/entry.dart').existsSync()) {
    return dir;
  }
  final sub = Directory('${dir.path}/apps/prompt_library');
  if (sub.existsSync() && File('${sub.path}/pubspec.yaml').existsSync()) {
    return sub;
  }
  return dir;
}

void main() {
  group('Architectural Boundaries', () {
    final appRoot = _findAppRoot();

    const expectedModelFiles = [
      'lib/src/library/models/category.dart',
      'lib/src/library/models/entry.dart',
      'lib/src/library/models/entry_input.dart',
      'lib/src/library/models/library_failure.dart',
      'lib/src/library/models/library_snapshot.dart',
      'lib/src/library/models/normalization.dart',
      'lib/src/library/models/tag.dart',
    ];

    const expectedRepositoryFile =
        'lib/src/library/data/library_repository.dart';

    final allIsolatedFiles = [...expectedModelFiles, expectedRepositoryFile];

    // === File existence ===
    group('File existence', () {
      for (final relativePath in expectedModelFiles) {
        test('model file exists: $relativePath', () {
          final file = File('${appRoot.path}/$relativePath');
          expect(
            file.existsSync(),
            isTrue,
            reason: 'Expected $relativePath to exist',
          );
        });
      }

      test('repository interface file exists: $expectedRepositoryFile', () {
        final file = File('${appRoot.path}/$expectedRepositoryFile');
        expect(
          file.existsSync(),
          isTrue,
          reason: 'Expected $expectedRepositoryFile to exist',
        );
      });
    });

    // === Import isolation ===
    group('Import isolation', () {
      const forbiddenPatterns = [
        'package:drift',
        'package:flutter/',
        'dart:io',
      ];

      for (final relativePath in allIsolatedFiles) {
        for (final forbidden in forbiddenPatterns) {
          test('$relativePath does not import $forbidden', () {
            final file = File('${appRoot.path}/$relativePath');
            expect(
              file.existsSync(),
              isTrue,
              reason: 'File $relativePath must exist to check imports',
            );
            final content = file.readAsStringSync();
            final importRegex = RegExp('import\\s+[\'"].*?$forbidden.*?[\'"]');
            expect(
              importRegex.hasMatch(content),
              isFalse,
              reason:
                  'File $relativePath contains forbidden import matching $forbidden',
            );
          });
        }
      }
    });

    // === Compile time API contract ===
    group('LibraryRepository compile-time API contract', () {
      test('fake satisfies LibraryRepository interface', () {
        final LibraryRepository repo = _FakeLibraryRepository();
        expect(repo, isA<LibraryRepository>());
        expect(repo.watchSnapshot(), isA<Stream<LibrarySnapshot>>());
        expect(repo.getSnapshot(), isA<Future<LibrarySnapshot>>());
      });
    });
  });
}

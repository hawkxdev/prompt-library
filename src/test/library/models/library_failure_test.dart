/// Library failure model tests.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/library/models/library_failure.dart';

void main() {
  group('LibraryFailure', () {
    const sampleOpaqueId1 = 'entry-id-123';
    const sampleOpaqueId2 = 'entry-id-456';
    const sensitivePromptBody =
        'My highly confidential prompt body with API key sk-12345';
    const sensitiveCategoryName = 'Confidential Category Name';
    const sensitiveTagName = 'Confidential Tag Name';
    const sensitiveSearchQuery = 'confidential search query';

    group('duplicateCategoryName', () {
      test('instantiates without payload and implements Exception', () {
        const failure = LibraryFailure.duplicateCategoryName();
        expect(failure, isA<LibraryFailure>());
        expect(failure, isA<Exception>());
        expect(failure, isA<DuplicateCategoryNameLibraryFailure>());
      });

      test('supports direct subclass constructor', () {
        const failure = DuplicateCategoryNameLibraryFailure();
        expect(failure, isA<LibraryFailure>());
      });

      test('supports value equality and hashCode consistency', () {
        const failure1 = LibraryFailure.duplicateCategoryName();
        const failure2 = DuplicateCategoryNameLibraryFailure();
        const different = LibraryFailure.duplicateTagName();

        expect(failure1, equals(failure2));
        expect(failure1.hashCode, equals(failure2.hashCode));
        expect(failure1, isNot(equals(different)));
      });

      test('toString provides clean representation without sensitive data', () {
        const failure = LibraryFailure.duplicateCategoryName();
        final str = failure.toString();

        expect(str, contains('duplicateCategoryName'));
        expect(str, isNot(contains(sensitiveCategoryName)));
        expect(str, isNot(contains(sensitivePromptBody)));
      });
    });

    group('duplicateTagName', () {
      test('instantiates without payload and implements Exception', () {
        const failure = LibraryFailure.duplicateTagName();
        expect(failure, isA<LibraryFailure>());
        expect(failure, isA<Exception>());
        expect(failure, isA<DuplicateTagNameLibraryFailure>());
      });

      test('supports direct subclass constructor', () {
        const failure = DuplicateTagNameLibraryFailure();
        expect(failure, isA<LibraryFailure>());
      });

      test('supports value equality and hashCode consistency', () {
        const failure1 = LibraryFailure.duplicateTagName();
        const failure2 = DuplicateTagNameLibraryFailure();
        const different = LibraryFailure.duplicateCategoryName();

        expect(failure1, equals(failure2));
        expect(failure1.hashCode, equals(failure2.hashCode));
        expect(failure1, isNot(equals(different)));
      });

      test('toString provides clean representation without sensitive data', () {
        const failure = LibraryFailure.duplicateTagName();
        final str = failure.toString();

        expect(str, contains('duplicateTagName'));
        expect(str, isNot(contains(sensitiveTagName)));
        expect(str, isNot(contains(sensitivePromptBody)));
      });
    });

    group('entryNotFound', () {
      test('instantiates with opaque id', () {
        const failure = LibraryFailure.entryNotFound(id: sampleOpaqueId1);
        expect(failure, isA<LibraryFailure>());
        expect(failure, isA<EntryNotFoundLibraryFailure>());
        expect(
          (failure as EntryNotFoundLibraryFailure).id,
          equals(sampleOpaqueId1),
        );
      });

      test('supports direct subclass constructor', () {
        const failure = EntryNotFoundLibraryFailure(id: sampleOpaqueId1);
        expect(failure.id, equals(sampleOpaqueId1));
      });

      test('supports value equality and hashCode consistency', () {
        const failure1 = LibraryFailure.entryNotFound(id: sampleOpaqueId1);
        const failure2 = EntryNotFoundLibraryFailure(id: sampleOpaqueId1);
        const failureDifferentId = LibraryFailure.entryNotFound(
          id: sampleOpaqueId2,
        );
        const differentType = LibraryFailure.categoryNotFound(
          id: sampleOpaqueId1,
        );

        expect(failure1, equals(failure2));
        expect(failure1.hashCode, equals(failure2.hashCode));
        expect(failure1, isNot(equals(failureDifferentId)));
        expect(failure1, isNot(equals(differentType)));
      });

      test('toString includes opaque id and contains no user content', () {
        const failure = LibraryFailure.entryNotFound(id: sampleOpaqueId1);
        final str = failure.toString();

        expect(str, contains('entryNotFound'));
        expect(str, contains(sampleOpaqueId1));
        expect(str, isNot(contains(sensitivePromptBody)));
        expect(str, isNot(contains(sensitiveSearchQuery)));
      });
    });

    group('categoryNotFound', () {
      test('instantiates with opaque id', () {
        const failure = LibraryFailure.categoryNotFound(id: sampleOpaqueId1);
        expect(failure, isA<LibraryFailure>());
        expect(failure, isA<CategoryNotFoundLibraryFailure>());
        expect(
          (failure as CategoryNotFoundLibraryFailure).id,
          equals(sampleOpaqueId1),
        );
      });

      test('supports direct subclass constructor', () {
        const failure = CategoryNotFoundLibraryFailure(id: sampleOpaqueId1);
        expect(failure.id, equals(sampleOpaqueId1));
      });

      test('supports value equality and hashCode consistency', () {
        const failure1 = LibraryFailure.categoryNotFound(id: sampleOpaqueId1);
        const failure2 = CategoryNotFoundLibraryFailure(id: sampleOpaqueId1);
        const failureDifferentId = LibraryFailure.categoryNotFound(
          id: sampleOpaqueId2,
        );
        const differentType = LibraryFailure.tagNotFound(id: sampleOpaqueId1);

        expect(failure1, equals(failure2));
        expect(failure1.hashCode, equals(failure2.hashCode));
        expect(failure1, isNot(equals(failureDifferentId)));
        expect(failure1, isNot(equals(differentType)));
      });

      test('toString includes opaque id and contains no user content', () {
        const failure = LibraryFailure.categoryNotFound(id: sampleOpaqueId1);
        final str = failure.toString();

        expect(str, contains('categoryNotFound'));
        expect(str, contains(sampleOpaqueId1));
        expect(str, isNot(contains(sensitiveCategoryName)));
      });
    });

    group('tagNotFound', () {
      test('instantiates with opaque id', () {
        const failure = LibraryFailure.tagNotFound(id: sampleOpaqueId1);
        expect(failure, isA<LibraryFailure>());
        expect(failure, isA<TagNotFoundLibraryFailure>());
        expect(
          (failure as TagNotFoundLibraryFailure).id,
          equals(sampleOpaqueId1),
        );
      });

      test('supports direct subclass constructor', () {
        const failure = TagNotFoundLibraryFailure(id: sampleOpaqueId1);
        expect(failure.id, equals(sampleOpaqueId1));
      });

      test('supports value equality and hashCode consistency', () {
        const failure1 = LibraryFailure.tagNotFound(id: sampleOpaqueId1);
        const failure2 = TagNotFoundLibraryFailure(id: sampleOpaqueId1);
        const failureDifferentId = LibraryFailure.tagNotFound(
          id: sampleOpaqueId2,
        );
        const differentType = LibraryFailure.entryNotFound(id: sampleOpaqueId1);

        expect(failure1, equals(failure2));
        expect(failure1.hashCode, equals(failure2.hashCode));
        expect(failure1, isNot(equals(failureDifferentId)));
        expect(failure1, isNot(equals(differentType)));
      });

      test('toString includes opaque id and contains no user content', () {
        const failure = LibraryFailure.tagNotFound(id: sampleOpaqueId1);
        final str = failure.toString();

        expect(str, contains('tagNotFound'));
        expect(str, contains(sampleOpaqueId1));
        expect(str, isNot(contains(sensitiveTagName)));
      });
    });

    group('invalidInput', () {
      test('instantiates with every LibraryInputFailureReason value', () {
        for (final reason in LibraryInputFailureReason.values) {
          final failure = LibraryFailure.invalidInput(reason);
          expect(failure, isA<LibraryFailure>());
          expect(failure, isA<InvalidInputLibraryFailure>());
          expect(
            (failure as InvalidInputLibraryFailure).reason,
            equals(reason),
          );
        }
      });

      test('supports direct subclass constructor', () {
        const failure = InvalidInputLibraryFailure(
          LibraryInputFailureReason.emptyTitle,
        );
        expect(failure.reason, equals(LibraryInputFailureReason.emptyTitle));
      });

      test('supports value equality and hashCode consistency', () {
        const failure1 = LibraryFailure.invalidInput(
          LibraryInputFailureReason.emptyTitle,
        );
        const failure2 = InvalidInputLibraryFailure(
          LibraryInputFailureReason.emptyTitle,
        );
        const differentReason = LibraryFailure.invalidInput(
          LibraryInputFailureReason.emptyBody,
        );

        expect(failure1, equals(failure2));
        expect(failure1.hashCode, equals(failure2.hashCode));
        expect(failure1, isNot(equals(differentReason)));
      });

      test('toString includes reason name and never leaks user text', () {
        for (final reason in LibraryInputFailureReason.values) {
          final failure = LibraryFailure.invalidInput(reason);
          final str = failure.toString();

          expect(str, contains('invalidInput'));
          expect(str, contains(reason.name));
          expect(str, isNot(contains(sensitivePromptBody)));
          expect(str, isNot(contains(sensitiveSearchQuery)));
          expect(str, isNot(contains(sensitiveCategoryName)));
          expect(str, isNot(contains(sensitiveTagName)));
        }
      });

      test('supports emptyCategoryName failure reason specifically', () {
        const failure = LibraryFailure.invalidInput(
          LibraryInputFailureReason.emptyCategoryName,
        );
        expect(
          (failure as InvalidInputLibraryFailure).reason,
          equals(LibraryInputFailureReason.emptyCategoryName),
        );
        expect(
          failure.toString(),
          'LibraryFailure.invalidInput(reason: emptyCategoryName)',
        );
      });

      test('supports emptyTagName failure reason specifically', () {
        const failure = LibraryFailure.invalidInput(
          LibraryInputFailureReason.emptyTagName,
        );
        expect(
          (failure as InvalidInputLibraryFailure).reason,
          equals(LibraryInputFailureReason.emptyTagName),
        );
        expect(
          failure.toString(),
          'LibraryFailure.invalidInput(reason: emptyTagName)',
        );
      });
    });

    group('invalidCategoryReorder', () {
      test('instantiates with safe count metadata or defaults', () {
        const failureWithCounts = LibraryFailure.invalidCategoryReorder(
          expectedCount: 5,
          actualCount: 3,
        );
        expect(failureWithCounts, isA<LibraryFailure>());
        expect(failureWithCounts, isA<InvalidCategoryReorderLibraryFailure>());
        final reorderFailure =
            failureWithCounts as InvalidCategoryReorderLibraryFailure;
        expect(reorderFailure.expectedCount, equals(5));
        expect(reorderFailure.actualCount, equals(3));

        const failureWithoutCounts = LibraryFailure.invalidCategoryReorder();
        final reorderWithoutCounts =
            failureWithoutCounts as InvalidCategoryReorderLibraryFailure;
        expect(reorderWithoutCounts.expectedCount, isNull);
        expect(reorderWithoutCounts.actualCount, isNull);
      });

      test('supports direct subclass constructor', () {
        const failure = InvalidCategoryReorderLibraryFailure(
          expectedCount: 10,
          actualCount: 9,
        );
        expect(failure.expectedCount, equals(10));
        expect(failure.actualCount, equals(9));
      });

      test('supports value equality and hashCode consistency', () {
        const failure1 = LibraryFailure.invalidCategoryReorder(
          expectedCount: 5,
          actualCount: 3,
        );
        const failure2 = InvalidCategoryReorderLibraryFailure(
          expectedCount: 5,
          actualCount: 3,
        );
        const failureDifferentCount = LibraryFailure.invalidCategoryReorder(
          expectedCount: 5,
          actualCount: 4,
        );
        const failureNulls = LibraryFailure.invalidCategoryReorder();

        expect(failure1, equals(failure2));
        expect(failure1.hashCode, equals(failure2.hashCode));
        expect(failure1, isNot(equals(failureDifferentCount)));
        expect(failure1, isNot(equals(failureNulls)));
      });

      test(
        'toString includes counts safely and never leaks category names',
        () {
          const failure = LibraryFailure.invalidCategoryReorder(
            expectedCount: 5,
            actualCount: 3,
          );
          final str = failure.toString();

          expect(str, contains('invalidCategoryReorder'));
          expect(str, contains('5'));
          expect(str, contains('3'));
          expect(str, isNot(contains(sensitiveCategoryName)));
        },
      );
    });

    group('databaseFailure', () {
      test('instantiates with every LibraryDatabaseFailureCode value', () {
        for (final code in LibraryDatabaseFailureCode.values) {
          final failure = LibraryFailure.databaseFailure(code: code);
          expect(failure, isA<LibraryFailure>());
          expect(failure, isA<DatabaseFailureLibraryFailure>());
          expect((failure as DatabaseFailureLibraryFailure).code, equals(code));
        }
      });

      test('supports direct subclass constructor', () {
        const failure = DatabaseFailureLibraryFailure(
          code: LibraryDatabaseFailureCode.transactionFailed,
        );
        expect(
          failure.code,
          equals(LibraryDatabaseFailureCode.transactionFailed),
        );
      });

      test('supports value equality and hashCode consistency', () {
        const failure1 = LibraryFailure.databaseFailure(
          code: LibraryDatabaseFailureCode.transactionFailed,
        );
        const failure2 = DatabaseFailureLibraryFailure(
          code: LibraryDatabaseFailureCode.transactionFailed,
        );
        const differentCode = LibraryFailure.databaseFailure(
          code: LibraryDatabaseFailureCode.readFailed,
        );

        expect(failure1, equals(failure2));
        expect(failure1.hashCode, equals(failure2.hashCode));
        expect(failure1, isNot(equals(differentCode)));
      });

      test(
        'toString includes code and never contains raw SQL or user data',
        () {
          for (final code in LibraryDatabaseFailureCode.values) {
            final failure = LibraryFailure.databaseFailure(code: code);
            final str = failure.toString();

            expect(str, contains('databaseFailure'));
            expect(str, contains(code.name));
            expect(str, isNot(contains('SELECT')));
            expect(str, isNot(contains('INSERT')));
            expect(str, isNot(contains(sensitivePromptBody)));
          }
        },
      );
    });

    group('staleSnapshot', () {
      test('toString provides clean representation without sensitive data', () {
        const failure = LibraryFailure.staleSnapshot();
        final str = failure.toString();

        expect(str, 'LibraryFailure.staleSnapshot()');
        expect(str, isNot(contains(sensitivePromptBody)));
        expect(failure, const LibraryFailure.staleSnapshot());
        expect(failure, isNot(const LibraryFailure.duplicateCategoryName()));
      });
    });

    group('exhaustive pattern matching', () {
      test('sealed hierarchy allows exhaustive switch statement', () {
        final failures = <LibraryFailure>[
          const LibraryFailure.duplicateCategoryName(),
          const LibraryFailure.duplicateTagName(),
          const LibraryFailure.entryNotFound(id: 'e1'),
          const LibraryFailure.categoryNotFound(id: 'c1'),
          const LibraryFailure.tagNotFound(id: 't1'),
          const LibraryFailure.invalidInput(
            LibraryInputFailureReason.emptyTitle,
          ),
          const LibraryFailure.invalidCategoryReorder(
            expectedCount: 2,
            actualCount: 1,
          ),
          const LibraryFailure.databaseFailure(
            code: LibraryDatabaseFailureCode.corrupt,
          ),
          const LibraryFailure.staleSnapshot(),
        ];

        final labels = failures
            .map(
              (f) => switch (f) {
                DuplicateCategoryNameLibraryFailure() => 'duplicate_category',
                DuplicateTagNameLibraryFailure() => 'duplicate_tag',
                EntryNotFoundLibraryFailure(:final id) => 'entry_not_found_$id',
                CategoryNotFoundLibraryFailure(:final id) =>
                  'category_not_found_$id',
                TagNotFoundLibraryFailure(:final id) => 'tag_not_found_$id',
                InvalidInputLibraryFailure(:final reason) =>
                  'invalid_input_${reason.name}',
                InvalidCategoryReorderLibraryFailure(
                  :final expectedCount,
                  :final actualCount,
                ) =>
                  'reorder_${expectedCount}_$actualCount',
                DatabaseFailureLibraryFailure(:final code) => 'db_${code.name}',
                StaleSnapshotLibraryFailure() => 'stale_snapshot',
              },
            )
            .toList();

        expect(
          labels,
          equals([
            'duplicate_category',
            'duplicate_tag',
            'entry_not_found_e1',
            'category_not_found_c1',
            'tag_not_found_t1',
            'invalid_input_emptyTitle',
            'reorder_2_1',
            'db_corrupt',
            'stale_snapshot',
          ]),
        );
      });
    });
  });
}

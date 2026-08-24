/// Entry input model tests.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/library/models/entry_input.dart';

void main() {
  // === Validation tests ===
  group('EntryInput.validate', () {
    test('trims title and rejects empty or whitespace-only title', () {
      final input = EntryInput.validate(
        title: '  System Architect Prompt  \n\t',
        body: 'Valid prompt body',
      );
      expect(input.title, 'System Architect Prompt');

      expect(
        () => EntryInput.validate(title: '', body: 'Valid body'),
        throwsA(
          isA<ArgumentError>().having((e) => e.message, 'message', 'title'),
        ),
      );

      expect(
        () => EntryInput.validate(title: '   \t\n  ', body: 'Valid body'),
        throwsA(
          isA<ArgumentError>().having((e) => e.message, 'message', 'title'),
        ),
      );
    });

    test('validates non-empty body and preserves it byte-for-byte', () {
      const verbatimBody =
          '  \r\n\t# System Prompt\r\n\r\n- Step 1: Analyze\r\n- Step 2: Act\t\n  ';
      final input = EntryInput.validate(
        title: 'Valid Title',
        body: verbatimBody,
      );

      expect(input.body, verbatimBody);
      expect(input.body.startsWith('  \r\n\t# System Prompt'), isTrue);
      expect(input.body.endsWith('\t\n  '), isTrue);

      expect(
        () => EntryInput.validate(title: 'Valid Title', body: ''),
        throwsA(
          isA<ArgumentError>().having((e) => e.message, 'message', 'body'),
        ),
      );

      expect(
        () => EntryInput.validate(title: 'Valid Title', body: '   \r\n\t  '),
        throwsA(
          isA<ArgumentError>().having((e) => e.message, 'message', 'body'),
        ),
      );
    });

    test('trims keyword and sets blank or whitespace keyword to null', () {
      final inputWithKeyword = EntryInput.validate(
        title: 'Title',
        body: 'Body',
        keyword: '  sys-prompt  ',
      );
      expect(inputWithKeyword.keyword, 'sys-prompt');

      final inputWithEmptyKeyword = EntryInput.validate(
        title: 'Title',
        body: 'Body',
        keyword: '',
      );
      expect(inputWithEmptyKeyword.keyword, isNull);

      final inputWithWhitespaceKeyword = EntryInput.validate(
        title: 'Title',
        body: 'Body',
        keyword: '   \t\n ',
      );
      expect(inputWithWhitespaceKeyword.keyword, isNull);

      final inputWithNullKeyword = EntryInput.validate(
        title: 'Title',
        body: 'Body',
        keyword: null,
      );
      expect(inputWithNullKeyword.keyword, isNull);
    });

    test('preserves categoryId as opaque and unchanged', () {
      final inputWithCategory = EntryInput.validate(
        title: 'Title',
        body: 'Body',
        categoryId: '  cat-opaque-id-123  ',
      );
      expect(inputWithCategory.categoryId, '  cat-opaque-id-123  ');

      final inputWithNullCategory = EntryInput.validate(
        title: 'Title',
        body: 'Body',
        categoryId: null,
      );
      expect(inputWithNullCategory.categoryId, isNull);
    });

    test('deduplicates, sorts, and freezes tagIds into unmodifiable list', () {
      final input = EntryInput.validate(
        title: 'Title',
        body: 'Body',
        tagIds: ['tag-z', 'tag-a', 'tag-m', 'tag-a', 'tag-z'],
      );

      expect(input.tagIds, ['tag-a', 'tag-m', 'tag-z']);
      expect(() => input.tagIds.add('tag-new'), throwsUnsupportedError);
      expect(() => input.tagIds.clear(), throwsUnsupportedError);
    });

    test(
      'defaults favorite and archive to false and respects explicit flags',
      () {
        final defaultInput = EntryInput.validate(title: 'Title', body: 'Body');
        expect(defaultInput.isFavorite, isFalse);
        expect(defaultInput.isArchived, isFalse);
        expect(defaultInput.tagIds, isEmpty);
        expect(defaultInput.keyword, isNull);
        expect(defaultInput.categoryId, isNull);

        final explicitInput = EntryInput.validate(
          title: 'Title',
          body: 'Body',
          isFavorite: true,
          isArchived: true,
        );
        expect(explicitInput.isFavorite, isTrue);
        expect(explicitInput.isArchived, isTrue);
      },
    );

    test('validation exception does not leak user content in message', () {
      try {
        EntryInput.validate(title: '   ', body: 'super-secret-user-content');
        fail('Expected ArgumentError');
      } on ArgumentError catch (e) {
        expect(e.message, 'title');
        expect(e.toString().contains('super-secret-user-content'), isFalse);
      }

      try {
        EntryInput.validate(title: 'super-secret-title', body: '   \n\t  ');
        fail('Expected ArgumentError');
      } on ArgumentError catch (e) {
        expect(e.message, 'body');
        expect(e.toString().contains('super-secret-title'), isFalse);
      }
    });
  });

  // === Equality and immutability tests ===
  group('EntryInput value equality and immutability', () {
    test('supports value equality and hashCode consistency', () {
      final a = EntryInput(
        title: 'Title',
        body: 'Body',
        keyword: 'key',
        categoryId: 'cat-1',
        tagIds: ['tag-b', 'tag-a'],
        isFavorite: true,
        isArchived: false,
      );
      final b = EntryInput(
        title: 'Title',
        body: 'Body',
        keyword: 'key',
        categoryId: 'cat-1',
        tagIds: ['tag-a', 'tag-b'],
        isFavorite: true,
        isArchived: false,
      );
      final different = EntryInput(
        title: 'Title',
        body: 'Body',
        keyword: 'key',
        categoryId: 'cat-1',
        tagIds: ['tag-a', 'tag-c'],
        isFavorite: true,
        isArchived: false,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(different)));
    });

    test('supports copyWith with optional and nullable fields', () {
      final original = EntryInput(
        title: 'Title',
        body: 'Body',
        keyword: 'key',
        categoryId: 'cat-1',
        tagIds: ['tag-1'],
        isFavorite: false,
        isArchived: false,
      );

      final modified = original.copyWith(
        title: 'New Title',
        body: 'New Body',
        keyword: null,
        categoryId: null,
        tagIds: ['tag-2'],
        isFavorite: true,
        isArchived: true,
      );

      expect(modified.title, 'New Title');
      expect(modified.body, 'New Body');
      expect(modified.keyword, isNull);
      expect(modified.categoryId, isNull);
      expect(modified.tagIds, ['tag-2']);
      expect(modified.isFavorite, isTrue);
      expect(modified.isArchived, isTrue);

      final unchanged = original.copyWith();
      expect(unchanged, equals(original));
      expect(unchanged.keyword, 'key');
      expect(unchanged.categoryId, 'cat-1');
    });
  });
}

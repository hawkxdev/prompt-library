/// Normalization helper tests.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_library/src/library/models/normalization.dart';

void main() {
  // === Search query normalization ===
  group('normalizeSearchQuery', () {
    test('converts Latin uppercase to lowercase', () {
      expect(normalizeSearchQuery('Prompt MASTER'), 'prompt master');
    });

    test('converts Cyrillic uppercase to lowercase', () {
      expect(normalizeSearchQuery('Категория ПРОМПТ'), 'категория промпт');
    });

    test('converts mixed Latin and Cyrillic text to lowercase', () {
      expect(normalizeSearchQuery('Prompt v1 ТЕСТ'), 'prompt v1 тест');
    });

    test('trims leading and trailing spaces', () {
      expect(normalizeSearchQuery('   search query   '), 'search query');
    });

    test('trims tabs, newlines, and mixed outer whitespace', () {
      expect(
        normalizeSearchQuery('\t\r\n  multiline query  \n\t'),
        'multiline query',
      );
    });

    test('returns empty string for empty input', () {
      expect(normalizeSearchQuery(''), '');
    });

    test('returns empty string for whitespace-only input', () {
      expect(normalizeSearchQuery('  \t\r\n  '), '');
    });

    test('preserves internal repeated spaces and tabs', () {
      expect(
        normalizeSearchQuery('  first   middle\t\tlast  '),
        'first   middle\t\tlast',
      );
    });
  });

  // === Metadata name normalization ===
  group('normalizeMetadataName', () {
    test('converts Latin uppercase to lowercase', () {
      expect(normalizeMetadataName('Category NAME'), 'category name');
    });

    test('converts Cyrillic uppercase to lowercase', () {
      expect(normalizeMetadataName('Тег ДЛЯ Работы'), 'тег для работы');
    });

    test('converts mixed Latin and Cyrillic text to lowercase', () {
      expect(normalizeMetadataName('AI Промпты'), 'ai промпты');
    });

    test('trims leading and trailing spaces', () {
      expect(normalizeMetadataName('   tag name   '), 'tag name');
    });

    test('trims tabs, newlines, and mixed outer whitespace', () {
      expect(
        normalizeMetadataName('\n\t  category name  \r\n'),
        'category name',
      );
    });

    test('returns empty string for empty input', () {
      expect(normalizeMetadataName(''), '');
    });

    test('returns empty string for whitespace-only input', () {
      expect(normalizeMetadataName(' \t \n '), '');
    });

    test('preserves internal repeated spaces and tabs', () {
      expect(
        normalizeMetadataName('  deep   nested\t\tname  '),
        'deep   nested\t\tname',
      );
    });
  });
}

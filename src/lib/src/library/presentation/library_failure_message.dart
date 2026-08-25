/// Library failure presentation.
library;

import '../models/library_failure.dart';

/// Returns non-sensitive failure text.
String messageForLibraryFailure(LibraryFailure failure) {
  return switch (failure) {
    DuplicateCategoryNameLibraryFailure() =>
      'A category with this name already exists.',
    DuplicateTagNameLibraryFailure() => 'A tag with this name already exists.',
    EntryNotFoundLibraryFailure() => 'This prompt no longer exists.',
    CategoryNotFoundLibraryFailure() => 'This category no longer exists.',
    TagNotFoundLibraryFailure() => 'This tag no longer exists.',
    InvalidInputLibraryFailure() => 'Check the entered values and try again.',
    InvalidCategoryReorderLibraryFailure() =>
      'The category order could not be saved.',
    DatabaseFailureLibraryFailure() =>
      'The library could not save this change.',
  };
}

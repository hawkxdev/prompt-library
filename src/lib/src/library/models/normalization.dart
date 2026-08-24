/// Normalization helpers.
library;

/// Normalizes search queries.
String normalizeSearchQuery(String input) {
  return input.trim().toLowerCase();
}

/// Normalizes metadata names.
String normalizeMetadataName(String input) {
  return input.trim().toLowerCase();
}

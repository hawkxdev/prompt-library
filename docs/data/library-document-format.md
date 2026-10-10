# Portable library document format

Version 1: `dev.hawkx.promptlibrary.library`. This is a whole-library contract: JSON provides exact restoration, while Markdown provides a readable export. Application settings, drafts and interface state are excluded.

The JSON root requires `format`, `formatVersion`, `exportedAt`, `entries`, `categories` and `tags`. Nullable fields must be present with null when no data exists. Unknown native-format fields are forbidden.

An entry contains `id`, `title`, `body`, `keyword`, `categoryId`, `tagIds`, `isFavorite`, `isArchived`, `createdAt`, `updatedAt` and `lastCopiedAt`. A category contains `id`, `name`, `normalizedName`, `sortOrder` and `createdAt`; a tag contains `id`, `name`, `normalizedName` and `createdAt`.

Body and keyword text are preserved exactly. Dates use `YYYY-MM-DDTHH:mm:ssZ`, years 0001–9999, without fractional seconds or normalization of impossible dates. Identifiers are opaque, unique within each entity type and never normalized. References must exist; repeated tagIds are forbidden. normalizedName equals the trimmed, lowercased name and is unique separately within categories and tags. sortOrder is a signed 64-bit integer; negative values and ties are preserved.

## Fields and types

Every listed field is required; additional native document fields are forbidden. An absent nullable field is not null. Strings are not coerced to numbers or booleans.

| Entity | Fields | Type and constraints |
|---|---|---|
| Root | format | Exact string dev.hawkx.promptlibrary.library |
| Root | formatVersion | Integer 1; 1.0 and true are invalid |
| Root | exportedAt | Canonical UTC date supplied by the caller |
| Root | entries, categories, tags | Arrays, including empty arrays |
| Entry | id | Nonempty opaque string, unique among entries |
| Entry | title, body | Strings nonempty after trimming; the native format stores the original characters |
| Entry | keyword | String or null, without trimming; empty and whitespace strings differ from null |
| Entry | categoryId | Existing category ID or null |
| Entry | tagIds | Array of existing tag IDs without duplicates |
| Entry | isFavorite, isArchived | Boolean |
| Entry | createdAt, updatedAt | Canonical UTC dates |
| Entry | lastCopiedAt | Canonical UTC date or null |
| Category | id, name, normalizedName | Nonempty ID; name nonempty after trimming; normalized name |
| Category | sortOrder | Signed 64-bit integer; ties and negative values are valid |
| Category | createdAt | Canonical UTC date |
| Tag | id, name, normalizedName | Nonempty ID; name nonempty after trimming; normalized name |
| Tag | createdAt | Canonical UTC date |

Identifiers are neither checked against a UUID regular expression nor trimmed. The same ID may appear in different entity types. normalizedName uniqueness is checked separately for categories and tags using normalizeMetadataName: trimming and Dart lowercase. No additional date-ordering constraints are imposed. Archived entries and unused categories and tags are included.

## Strict parsing

LibraryJsonCodec accepts bytes, checks size before decoding, uses strict UTF-8 and performs a bounded lexical pass before the standard JSON decoder. One leading UTF-8 BOM is accepted on input and counts toward size; output has no BOM. Duplicate keys are forbidden within each object, including equivalent spellings such as a literal key and its Unicode escape. The same key in different objects is valid. A string resembling JSON does not become document structure.

UTF-16 pairing is checked in every string and key: an escaped lone surrogate is not replaced with U+FFFD. Invalid UTF-8, syntax, duplicate keys, unknown versions, invalid types, duplicate IDs or links, dangling references and incorrect normalization reject the entire native document. Models are created only after raw strings and references have been validated.

Dates use YYYY-MM-DDTHH:mm:ssZ, years 0001–9999. Impossible calendar days, 24:00, leap seconds, time-zone offsets, local times, lowercase z and any fractional seconds are rejected. DateTime.parse normalizes some impossible dates, so parsing verifies the canonical round-trip representation. Export also refuses unsupported DateTime precision or years rather than producing a file that cannot be restored.

## Resource limits

Default DocumentLimits: 33 554 432 input or output bytes, container depth 32 and 4096 keys per JSON object. Every limit is positive and can be reduced for tests. A root object or array has depth 1. JSON output size includes the final LF. JSON limits apply to input and canonical output. Markdown is limited by output bytes; there is no Markdown import codec.

The streaming builder stops accumulating when a limit is exceeded and returns no partial result. These are document limits, not a storage entry limit or a guarantee of low memory usage: snapshots and decoded objects also consume memory. Measurement of the user library and iPhone behavior belongs to end-to-end acceptance.

Measurement on macOS, 08.09.2026: synthetic JSON of exactly 33 554 432 bytes, export 335 ms, parsing 238 ms, process peak RSS 488 407 040 bytes. Exceeding the limit by one byte was rejected before decoding. Reproduction: [portability_benchmark.dart](../../src/test/library/transfer/portability_benchmark.dart). This is a local measurement, not evidence that this volume is acceptable on iPhone.

## Canonical JSON

Output is UTF-8 without BOM, compact JSON and one final LF. Key order follows the contract table. Entity arrays are sorted by exact ID, as are tagIds. This is serialization order, not user-list sorting. The same snapshot and exportedAt produce identical bytes regardless of input collection order. The returned Uint8List is immutable.

Synthetic example:

```json
{"format":"dev.hawkx.promptlibrary.library","formatVersion":1,"exportedAt":"2026-09-08T12:00:00Z","entries":[{"id":"example","title":"Example","body":"  Текст\r\nnext  ","keyword":"  alias  ","categoryId":null,"tagIds":[],"isFavorite":false,"isArchived":false,"createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-01T00:00:00Z","lastCopiedAt":null}],"categories":[],"tags":[]}
```

## Markdown

LibraryMarkdownExport creates one document with fixed headings. Metadata, including archived state, categories, tags and dates, is represented as escaped JSON inside fences. A user title never becomes a Markdown heading or a fence language string.

Body text is inserted exactly at zero indentation. The backtick fence length is max(3, the longest backtick run in the body + 1). If the body does not end in LF, a structural LF is added before the closing fence, including after a trailing lone CR. This keeps the fence on a separate line in viewers that ignore a lone CR. The boundary is a wrapper, not a change to stored body text; internal line endings and spaces are not transformed. Byte-exact restoration from rendered Markdown is not promised; use JSON for restoration.

## Raycast

RaycastSnippetDecoder accepts a JSON array. name and text are required strings nonempty after trimming. name becomes a trimmed title, while originalTitle is retained for displaying the transformation. text and a present string keyword are preserved exactly. An absent keyword becomes null; explicit null is not a string and makes that row invalid. An invalid row has a DocumentFailure with its source index; other rows remain available for review. Invalid JSON, duplicate keys or invalid Unicode reject the entire document.

Unknown fields are listed by name in deterministic sorted order. Importing only supported fields requires explicit consent by source index; without it, the row has the unsupportedFields outcome. hasPlaceholderSyntax warns about a possible brace-based form; it does not recognize the Raycast language, and substitutions are never executed. Keyword does not implement system text expansion.

## Preview plans

RaycastImportPlan is a pure computation and performs no inserts. RaycastSelection stores immutable excludedIndices, addAsNewIndices and acceptedUnknownFieldIndices sets; indices outside the document are rejected. Selection is recomputed in source-row order on every call.

Outcome order is invalid, userSkipped, unsupportedFields, duplicate, conflict, selected. An exact duplicate is defined by a Dart record with three components: title.trim(), exact body and exact keyword. No concatenation delimiter is used. Every existing entry, including archived entries, participates in comparison. A conflict arises when title.trim() or an exact nonempty keyword matches different content. Null, empty and whitespace strings do not themselves create keyword conflicts; they remain distinct exact-key values.

addAsNewIndices resolves a conflict, but not an exact duplicate. Only selected rows reserve keys for subsequent rows. Excluding the first representative allows a later one to become selected. validCount counts structurally valid rows; predictedAdded and predictedSkipped are mutually exclusive and sum to the input size. warningRowCount is independent and may overlap any outcome. A prediction is not a report of completed writes.

LibraryRestorePlan compares two complete valid snapshots by ID and every field. differences lists have stable ID order, an added/removed/modified/unchanged type, changed-field lists and immutable before/after values. They include lastCopiedAt, links, archived state and unused taxonomy. The expected snapshot is retained for the next layer; this layer neither performs a transactional freshness check nor applies changes.

## Failures and boundaries

DocumentFailure contains a stable enum code and optional rowIndex, offset, field and collection. A raw native-document row is associated with its collection, index and known field where available. A lexical offset is measured in UTF-16 string units after UTF-8 decoding. Exception text prints only the code and numeric positions, never entry content or arbitrary keys.

Codes: invalidUtf8, invalidJson, duplicateKey, limitExceeded, invalidUnicode, invalidShape, missingField, unsupportedField, unsupportedFormat, unsupportedVersion, invalidValue, invalidDate, duplicateId, duplicateName, duplicateLink, danglingReference. Preview data may contain user text and must not enter caller logs.

These modules do not use Flutter, Drift, files, platform channels, clocks or UUID generation. They neither persist data nor display screens. Preserving an untouched keyword during subsequent editing belongs to EntryUpdate and caller integration, not to this codec alone.

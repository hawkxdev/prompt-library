# Library transfer architecture

Library transfer provides a portable JSON backup, whole-library restoration, readable Markdown export and reviewed Raycast snippet import. These operations use local files and the existing Drift repository. Cloud synchronization, encrypted Raycast configuration files, automatic backups and execution of Raycast placeholders are outside this contract.

## Layers

| Layer | Responsibility | Source |
|---|---|---|
| Portable documents | Strict JSON validation, canonical serialization, Markdown export and Raycast row parsing | `src/lib/src/library/transfer/` |
| Preview plans | Immutable comparison of full snapshots and per-row import decisions | `src/lib/src/library/transfer/library_transfer_plan.dart` |
| Persistence | Consistent snapshots, transactional freshness checks, atomic replacement and import | `src/lib/src/library/data/` |
| Operation and interface | Preparation, review, backup verification, maintenance barriers, application and result | `src/lib/src/library/presentation/transfer/` |
| Document boundary | File selection and typed native export outcomes | `src/lib/src/platform/documents/` |
| Apple adapters | macOS save panel and iOS document export lifecycle | `src/macos/Runner/DocumentExportPlugin.swift`, `src/ios/Runner/DocumentExportPlugin.swift` |
| Composition | Creates the platform implementations and owns ordered teardown | `src/lib/src/app/composition_root.dart` |

The [document format](../data/library-document-format.md) owns fields, exact-text rules, validation errors and resource limits. Document code does not depend on Flutter, Drift, files or platform channels. Export uses a complete repository snapshot, including archived entries and unused taxonomy, rather than the visible filtered list. Format version and database schema version are separate.

## Restore and import

Native JSON restores a complete snapshot. It either initializes an empty library or explicitly replaces a nonempty one; merging native backups is not supported. Review must expose added, removed, modified and unchanged entities with every relevant field. Nonempty replacement requires an external JSON backup that the application reopens, decodes and compares with the original snapshot. Cancellation, unreadable or mismatched backup data prevents replacement. The backup is not automatically deleted or confined to application storage.

Before applying, the repository compares the complete current snapshot with the expected one inside the same transaction. Any difference, including copy metadata, invalidates review. All four library tables are replaced atomically with IDs, dates, links and flags preserved; a mid-transaction failure rolls back the operation.

Raycast import adds explicitly selected rows. It never silently overwrites a conflicting entry. Exact duplicates are skipped with a reason; conflicts require a deliberate add-as-new choice, and unknown fields require consent to import only supported fields. Invalid rows remain visible for review, while invalid document syntax rejects the entire input. Outcome counts account for every source row; warnings are independent of those outcomes. Newly imported entries receive new IDs and import timestamps, no category or tags, false favorite/archive flags and null copy timestamps.

An unchanged keyword remains exact when another entry field is edited. Intentional keyword editing follows the editor's normalization contract. No imported flag or origin-specific update policy is required. Body text and placeholders remain literal.

## Operation ownership

One transfer controller owns the input bytes, expected snapshot, row selection, backup verification and operation result. The library maintenance barrier prevents new mutations and copy cycles, lets admitted cycles finish their metadata writes, then takes the final snapshot. The repository's transactional guard also protects against callers outside the interface.

After successful replacement, stale search, filters, selection, mobile mode and scroll state reset to the restored library. Raycast import does not perform that replacement reset. During shutdown, refuse new transfer work, invalidate late system replies and wait for admitted operations before disposing controllers and the database. Closing a route does not cancel an active SQL transaction.

## Native document flows

Import reads one selected JSON file into operation-owned bytes; it does not retain arbitrary external paths. macOS export uses a save panel and non-overwriting creation, verifies the new bytes before success and removes a partial file only when ownership is established. A preflight existence check alone does not provide overwrite protection.

iOS exports a temporary copy through the system document picker. The adapter owns the active dialog, operation identity and source file. Late callbacks must not complete a newer operation; cleanup waits until the system releases the file. UIKit presentation is asynchronous, so a synchronous presentation check is not proof of later acceptance, and a timeout must not remove a file still in use. Reading a returned URL requires balanced security-scoped access.

Outcomes distinguish cancellation, unavailability, failure and completed export. A system callback is not a promise of cloud delivery. Existing verified backups are not targets for a new export. JSON cannot supply arbitrary save paths, persistent bookmarks or broader disk access.

## Verification boundary

Use the [portability verification contract](../testing/library-portability.md) for automated, native and live acceptance. A 32 MiB document limit is not a measured device capacity. A passing codec or synthetic journey does not prove physical device responsiveness, provider behavior or completed cross-device acceptance.

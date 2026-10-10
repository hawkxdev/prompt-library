# Portability verification contract

This is the repository-accessible contract for whole-library transfer acceptance. Read the [format](../data/library-document-format.md), [architecture](../architecture/library-transfer.md), [development guide](../development.md) and assigned task first. The file-backed journey, guarded platform journey and limit-document generator are provided on `feature/library-portability-repo2`, separately from `main`. Their paths below refer to that continuation branch. This document does not certify a fresh passing run or complete live device acceptance.

## Automated layers

| Layer | Entry | What it can establish |
|---|---|---|
| Codecs and plans | `src/test/library/transfer/` | Strict input validation, exact export, row outcomes and immutable previews |
| Repository | `src/test/library/data/drift_library_repository_test.dart` | Full-snapshot freshness, atomic replacement/import and rollback |
| Controller and callers | `src/test/library/presentation/transfer/` and affected desktop/mobile tests | Backup gates, cancellation, maintenance, view reset and keyword editing intent |
| File-backed journey | `src/test/acceptance/library_portability_test.dart` | Transfer through production controllers across two temporary databases, including reopening |
| Guarded platform journey | `src/integration_test/library_portability_journey_test.dart` | Platform execution of the temporary file-backed journey, with a guard against application-support paths |
| Native adapters | macOS/iOS `RunnerTests` and channel integration tests | Native registration, lifecycle and file-flow contracts |

The host journey must cover A -> B export/restoration, B -> A replacement of nonempty data, complete preview differences, exact keyword preservation after title-only edits, verified external backup, cancellation followed by a refused apply, restoration of the previous backup and rollback after a forced mid-transaction failure. Markdown verification compares each original body with its fenced export.

Repeat distinguishing mutations for these assertions: trim a transferred padded keyword, including a separate check of reopened-state equality; disable the failing transaction trigger; alter an expected Markdown body; allow apply after cancellation without merely provoking a state-cast error; direct the platform database path into application support so the guard fails before opening it; and remove the guard so its self-check fails. Use an isolated copy, restore exact source bytes and rerun the final checks. A failure at setup or at a different assertion does not establish the claimed protection.

## Independent state comparison

For live transfers, compare database state independently of the codec being verified. Stop the application before taking a consistent copy. Include WAL/SHM companions when present and checkpoint only a copy. Check integrity and schema version, then compare deterministic rows from `categories`, `tags`, `entries` and `entry_tags`, ordered by every primary-key column.

Text serialization must distinguish SQL NULL from an empty string; bare `hex()` cannot do that. Use an explicit null marker plus hexadecimal text, and quoted numeric values. Prove the comparison with synthetic controls that distinguish null/empty keyword, ignore link insertion order and repeat identically. A `.backup` file may have different physical bytes with the same logical state; a raw-file hash alone cannot compare these two states. Keep database copies and text-bearing dumps private.

## Remaining live acceptance

The following 16 items remain required. A checkmark needs actual version-bound evidence; creating this document or passing one automated layer closes none of them.

1. **macOS input review:** restore a synthetic edge-case document behind a verified backup, then separately import a permitted real Raycast export, genuine exported keyword examples and a clearly labeled synthetic row-outcome fixture. Record and independently reconcile valid, selected, duplicate, conflict, invalid, unknown-field and warning counts. Repeat the real import and show that it adds nothing. Require explicit unknown-field consent; synthetic cases do not expand claims about genuine Raycast exports.
2. **Exact text and keyword:** compare every imported row with its input, including null, empty, padded and ordinary keyword values. Preserve CRLF, Unicode, archive state, unused taxonomy and literal placeholders.
3. **macOS exports:** export the resulting library as JSON and Markdown. Record its actual document size and relation to the 32 MiB limit.
4. **macOS offline flow:** with the owner's network actually disabled and no active agents, export locally and restore with a verified backup. Compare complete state before and after; do not infer offline operation from configuration alone.
5. **macOS accessibility:** with VoiceOver actually enabled, verify entry to transfer, the screen, review, result and announcements. Capture the accessibility tree in that state and distinguish inspection from what the owner heard.
6. **Physical iPhone preparation:** inspect current library state, preserve a verified copy, verify a fresh signed Release artifact and profile, then install only under the device assignment and after a direct warning. Do not retry a refused installation or delete an app/container automatically.
7. **macOS -> iPhone:** move the JSON export through an authorized local transfer, enter airplane mode, restore, terminate and restart the app, then compare copied database state independently. Empty restoration needs no external backup; a nonempty receiver still requires verified replacement protection.
8. **iPhone -> macOS:** while offline, change only titles on entries with empty and padded keyword values. Export locally, transfer after connectivity returns, replace the macOS library behind a verified backup, restart and compare complete states and exact keywords.
9. **Unavailable cloud input:** while offline, select an input that exists only in iCloud Drive. Record the actual picker/application outcome and establish unchanged library state. Do not claim accepted cloud-provider operation.
10. **Limit and recovery:** use the repository generator for a representative document of exactly 33 554 432 bytes with 2048 entries, categories and tags. Preserve a verified copy of the real library, replace it with the limit document, then restore the real library through the application's required verified backup of the nonempty limit library. Record time and responsiveness for each step, and compare final state with the initial copy. System termination, a hung interface or insufficient backup space stops dependent acceptance; direct database writes to recover a device require a separate decision.
11. **iPhone accessibility:** verify VoiceOver and maximum text size throughout transfer, then restore the previous setting.
12. **iPad compatibility:** restore into an empty iPad simulator library and export through the real system flow. Treat this as compatibility, then remove only task-owned synthetic and real input data from the simulator.
13. **Result record:** record measurements, build modes, revisions and whether each observation was directly observed or reported by the owner. Keep iOS 15 runtime, working cloud/third-party providers, physical iPad, distribution and live macOS large-text verification explicitly unverified unless separately proven. Publish only an authorized sanitized result; raw evidence remains private.
14. **Application guide:** describe confirmed transfer surfaces, genuine Raycast fields and actual limits without converting synthetic or historical results into broader compatibility claims.
15. **Final checks:** run the complete assigned local gate and distinguishing mutations on the result tree. It includes formatting, analysis, the full Flutter suite, host portability tests, macOS Debug and native tests, macOS channel and portability integration tests, macOS Release, iOS Debug without signing, iOS native tests, and iPhone-simulator portability and channel integration tests. Read native counts from fresh `.xcresult` bundles and record every exit code, skip and failure. Device signing remains a separate artifact gate.
16. **Independent acceptance:** complete the assigned independent review, resolve confirmed findings and have the lead accept the exact result revision before declaring the portability work complete. Integration and publication retain their separate authority.

## Prerequisites and boundaries

Use the real Apple runtime and toolchain for platform claims. Select currently available simulators rather than copying a historical identifier. Physical iPhone actions, network changes, VoiceOver activation, system consent and password dialogs require the owner's involvement where the task says so. Each synthetic-input session and device installation requires its warning; missing owner action blocks dependent steps.

Real exports, library copies and input-acquisition tools stay local. Repository-based synthetic checks do not require that private material, while real-data scenarios require separately approved and received inputs. Maintain safe baselines and record what remains untested. No App Store/TestFlight release, notarization, physical iPad acceptance or data-recovery write is authorized by this contract alone.

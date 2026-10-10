# Prompt Library

Prompt Library is a private local-first Flutter application for storing prompts and reusable text. The first product slice targets macOS, while the same codebase remains compilable for iOS.

## Status

The application provides a durable local library, a complete macOS-first management surface, a sandbox-compatible quick-access workflow, and a tap-first iPhone surface. It supports persistent prompt CRUD, normalized search and filtering, keyboard and pointer selection, exact clipboard copy, favorites, reversible archive/restore, confirmed deletion, category and tag management, adaptive layouts, retained typed failures, deterministic lifecycle ownership, a configurable global shortcut, compact keyboard search, cancel, and best-effort focus restoration. On iPhone the same object graph renders a search-first list where one tap copies the exact body with best-effort haptic feedback, a separate disclosure opens a scroll-safe detail route, and a filter sheet selects All, Favorites, Recent or Archived plus category and tag filters. Users can create entries from the list and edit them from detail through a full-screen keyboard-safe route that shares draft, validation, category/tag assignment and mutation guards with the macOS editor. Dirty drafts require confirmation before leaving, and Save and Cancel remain in the app bar while the fields scroll under keyboard, landscape and large-text constraints. A refused save states its reason on the field that blocks it: the field carries the message, is marked invalid for assistive technology and takes focus, which brings it into view; a persistence failure keeps the summary below the form and announces itself as a live region. The mobile detail route also toggles favorite and archive state and deletes an entry after explicit confirmation, and the same three actions are reachable from the list itself: a long press on a row opens a menu anchored to that row, deletion still requires the confirmation dialog, and assistive technology reaches the same three actions as custom semantic actions on the row node. System sharing runs on iOS through that boundary: the Share control presents the system sheet anchored to itself and reports one of four stable outcomes, while every other platform keeps the explicitly unavailable capability. A selected activity is never reported as delivery. Local integrated release acceptance passes for macOS Release and the shared iOS compile gate; iPhone simulator smokes cover retrieval, exact clipboard round-trip, detail navigation, both orientations, real-keyboard creation and editing. A physical iPhone on iOS 26.6.1 additionally covers editing through the interface, byte-exact clipboard round-trip into another app, the system share sheet dismissed and with an activity selected, process restart from the app switcher, operation with the network actually off, VoiceOver on the retrieval, detail and editor surfaces, real touch targets and the maximum accessibility text size. The owner additionally confirmed on the device that a long press opens the row menu, that deletion still asks for confirmation, and that VoiceOver announces the same three row actions. An iPad simulator covers compatibility layout and the anchored share popover without claiming an optimized iPad interface. Both the macOS toolbar and the iPhone search row open the shared Transfer library route, which provides export to JSON and Markdown, replacement restore behind a verified external backup copy, Raycast import with per-row review, and a view reset after a completed replacement. Distribution signing, notarization, App Store processing, TestFlight, storefront installation and the iOS 15 minimum runtime remain unverified and were not performed.

## Tech Stack

- [Flutter 3.47.0](https://docs.flutter.dev/)
- [Dart 3.13.0](https://dart.dev/)
- [Drift 2.34.3](https://drift.simonbinder.eu/)
- [SQLite](https://www.sqlite.org/)

## Prerequisites

- macOS with Xcode 27.0
- Flutter 3.47.0 on the stable channel
- Dart 3.13.0
- Installed macOS and iOS platform components

## Setup

```bash
git clone https://github.com/hawkxdev/prompt-library.git
cd prompt-library/src
flutter pub get
```

## Run on macOS

```bash
flutter run -d macos
```

## Quick Access on macOS

The default global shortcut is `Control+Option+Space` (`⌃⌥Space`). From another application it opens the existing Prompt Library window in compact mode with search focused. Use `↑` and `↓` to select, `Enter` to copy the exact body and return focus, or `Escape` to close without copying.

Open **Global shortcut** from the keyboard button beside full-library search to choose Space or A-Z plus Command, Shift, Option, and Control modifiers. A failed replacement leaves the previous shortcut active. The sandboxed workflow does not require Accessibility permission or entitlement.

## Library Transfer

The macOS toolbar beside search and the iPhone search row both expose **Transfer library**. The shared route offers three operations, and the operation state belongs to the application composition: closing the route does not cancel a running operation, and reopening shows its current step.

- **Export JSON / Export Markdown** prepares a document of the whole library and hands it to the native save flow with a suggested per-day file name. On macOS the file is written through the managed export operation; on iPhone the system share and export flows are used.
- **Import from file** picks one JSON document. A Prompt Library document opens a full replacement review with per-entity add, remove and modify rows showing every field before and after. A Raycast snippet export opens an import review with per-row choices, conflict handling and unknown-field consent.
- A replacement first requires an external backup copy of the current library, saved through the native flow and verified by re-opening that file; the application applies changes only after the copy reads back exactly. An empty current library waives the copy. Application is atomic under a maintenance barrier, and if the library changed during the operation the review is invalidated and a new review is required.
- After a completed replacement the view resets to the default filter, the search field clears, the mobile mode returns to All, and the selection resolves to the first visible entry of the restored library. A Raycast import adds entries without resetting the view. The exact keyword value of every entry, including padded and empty ones, survives restore and later edits unchanged unless the keyword field itself is edited.

A copy contains entries with their exact title, body and keyword text, categories and tags with their assignments, favorite and archived flags, and usage timestamps. A copy never contains search state, selection, editor drafts, the global shortcut or platform settings.

Limitations: every document is limited to 32 MiB; exported JSON and Markdown are unencrypted and contain the plain texts of the library; iCloud and third-party storage providers are not integrated, and destinations are whatever the native file flows offer. An operation requested while the application is closing is refused with a visible notice and is not started.

## Optional MCP Diagnostics

`lib/main_mcp.dart` starts a developer-facing diagnostic variant of the same application surface for MCP-driven inspection. It is guarded to Debug builds and terminates with exit code 64 in any other build mode, while the production entry point `lib/main.dart` remains unchanged.

The diagnostic composition seeds synthetic entries, categories and tags into an in-memory Drift database, so no persistent store is created and the production database is never read or written. The process also exposes a `prompt_library_identity` tool that reports the application ID, diagnostic mode and schema version for client verification.

From the project root, run the guarded diagnostic wrapper:

```bash
scripts/run-prompt-library-mcp.sh
```

The fixed DDS port `8181` is the attach point for an external MCP inspector client connecting to `localhost:8181`. Project-local MCP server configuration and its provenance-checking wrapper live in the project root. The command disables VM service authentication; use it only on localhost for a bounded diagnostic session and stop the process afterward.

## Quality Checks

```bash
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter build macos --debug
xcodebuild test -workspace macos/Runner.xcworkspace -scheme Runner -configuration Debug -destination 'platform=macOS'
flutter test integration_test/macos_channel_handshake_test.dart -d macos
flutter build macos --release
flutter build ios --debug --no-codesign
```

## Project Structure

- `lib/src/app/` contains the production composition root and application surface.
- `lib/src/library/models/` contains immutable domain models.
- `lib/src/library/data/` contains the Drift database and repository.
- `lib/src/library/presentation/` contains pure Dart state plus full-library widgets, dialogs, shortcuts, clipboard, tactile feedback, system sharing and failure boundaries.
- `lib/src/library/presentation/mobile/` contains the iPhone surface: mode projection, coalesced copy and share actions, list, filter sheet, detail route and the full-screen entry editor.
- `lib/src/platform/ios/` contains the system sharing adapter behind the sharing boundary.
- `lib/src/platform/macos/` contains the typed native port, quick controller/state, quick UI and shortcut settings.
- `macos/Runner/` contains the Carbon registrar and one main-actor window/channel lifecycle service.
- `drift_schemas/` contains the versioned schema baseline.
- `test/library/` contains model, persistence, controller and full-library widget contracts.
- `test/library/presentation/mobile/` contains mobile mode projection unit tests and the iPhone retrieval widget contracts.
- `test/app/` verifies real Drift composition and teardown.
- `test/acceptance/` verifies the complete persistent release journey over real on-disk Drift and production controllers.
- `test/platform/macos/` and `macos/RunnerTests/` verify Dart, channel, widget, Carbon and native lifecycle contracts.
- `integration_test/` verifies the running Dart-to-Swift production channel handshake.

## Author

[hawkxdev](https://github.com/hawkxdev)

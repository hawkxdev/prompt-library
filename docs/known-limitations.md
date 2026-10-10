# Known limitations

## Product and verification boundaries

- JSON and Markdown exports are unencrypted and contain library text. Protect exported files and keep real libraries out of repository fixtures, reports and screenshots.
- Transfer documents are limited to 32 MiB. This limit does not guarantee acceptable memory usage or responsiveness on every device.
- Native backups replace a library; merging two native backups is not supported. Markdown is a readable export, not a restoration input.
- Cloud synchronization, encrypted Raycast configuration import and execution of Raycast placeholders are not implemented.
- iCloud and third-party file providers are not accepted working surfaces. Local file behavior does not establish their availability or delivery guarantees.
- iPad is a compatibility target, not an optimized interface. Physical iPad, iOS 15 runtime and distribution through App Store, TestFlight or notarization remain unverified.
- Complete live cross-device portability acceptance remains open. See the [verification contract](testing/library-portability.md).

## Reported macOS defects

These findings remain open. Reproduce them on the current revision before accepting a fix; their recorded behavior is not a new runtime test.

| Finding | Reported reproduction | Relevant source |
|---|---|---|
| Detail actions overflow at large text size | A 720×800 macOS window and text scale 3.1 overflow the Edit/Copy row by 51 pixels | [library_detail.dart](../src/lib/src/library/presentation/library_detail.dart) |
| Exception during termination | Cmd+Q reports an unrecognized selector from the termination override after local cleanup | [AppDelegate.swift](../src/macos/Runner/AppDelegate.swift) |

The termination override currently calls `super.applicationWillTerminate(notification)`. Verify the installed Flutter delegate's selector support and add a distinguishing native test when changing that path. Do not treat the absence of a crash report as proof that no exception occurred.

Deferred defects are separate from the portability acceptance task unless explicitly assigned. Documentation preparation does not fix or accept them.

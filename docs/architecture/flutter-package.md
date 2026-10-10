# Flutter package placement

`src/` is one complete Flutter package. Its `pubspec.yaml`, dependency lock, `lib/`, `test/`, `integration_test/`, `ios/` and `macos/` retain their relative layout. Run Flutter and Xcode commands from this package directory.

This placement preserves package imports and Xcode's internal relative paths. Moving repository documentation is not a reason to change bundle identifiers, deployment targets, signing, capabilities, database schema or dependency locks.

Root `tests/` contains Python checks for utilities in `scripts/`. Flutter tests stay inside the package so that normal Flutter commands and imports continue to work. New feature requirements belong in `specs/`; shared documentation starts at the [documentation index](../knowledge-index.md).

Development checks and native boundaries are described in the [development guide](../development.md). Live library testing, physical device installation and distribution require their own assignment. Isolated build checks must not replace a working signed artifact.

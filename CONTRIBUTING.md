# Contributing to PromptLibrary

PromptLibrary is a local library for prompts and reusable text on macOS and iPhone. Contributions should improve a clear user scenario while preserving exact text and protecting existing library data.

## Start here

Read [AGENTS.md](AGENTS.md), the [application guide](src/README.md) and the [documentation index](docs/knowledge-index.md). The public [development skill](.agents/skills/project-development/SKILL.md) describes package and verification boundaries; the [portability skill](.agents/skills/library-portability/SKILL.md) covers import, export and restore work. Private operational files are not contribution prerequisites.

Check existing issues and pull requests before starting. For changes to the data format, database schema, architecture or platform capabilities, propose the scope in an issue first. Keep a pull request focused on one outcome and explain the behavior, reason and verification.

## Report a problem

Include the platform, application revision, reproducible steps, expected behavior and actual result. Use a minimal synthetic example. Remove library text, credentials and personal paths from logs, screenshots and attachments. Read [known limitations](docs/known-limitations.md) before reporting a duplicate; you can also open an issue to ask a project question.

## Local checks

Use macOS, Xcode and the Flutter toolchain described in [src/README.md](src/README.md#prerequisites). Run Python utility checks from the root:

```bash
python3 -m unittest discover -s tests -v
```

Run formatting, analysis and Flutter tests from `src/` with the environment filter in [AGENTS.md](AGENTS.md#commands-and-evidence). The [development guide](docs/development.md#command-environment) gives the complete commands. Add focused checks for changed behavior and report failures, skips and untested layers. Checks run locally; GitHub Actions is disabled.

## Data and platform boundaries

Use temporary databases and synthetic fixtures for tests and demonstrations. Normal application runs use persistent data. Real-library replacement, physical device installation, signing and distribution require their own assignment. A passing Dart test does not establish native dialogs, physical device behavior or completed portability acceptance.

Write project artifacts in English and preserve exact technical tokens and test data. Submit only material you can license under the project's [MIT License](LICENSE), and retain third-party notices.

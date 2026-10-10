# Project documentation

This index is the repository-accessible entry to project knowledge. Shared instructions live in [AGENTS.md](../AGENTS.md), while user behavior and normal commands live in the [application guide](../src/README.md). Public skills supply project-specific procedures; the owner's private navigation and continuity are not required to use this index.

| Topic | Owner |
|---|---|
| Local development and verification | [project-development](../.agents/skills/project-development/SKILL.md) |
| Transfer changes and verification | [library-portability](../.agents/skills/library-portability/SKILL.md) |
| JSON, Markdown and Raycast input | [Portable document format](data/library-document-format.md) |
| Flutter package placement | [Package layout](architecture/flutter-package.md) |
| Transfer layers and data-loss protection | [Transfer architecture](architecture/library-transfer.md) |
| Commands, native results and data boundaries | [Development guide](development.md) |
| Requirements and unfinished work | [Requirements navigation](../specs/README.md) |
| Automated and live portability acceptance | [Portability verification](testing/library-portability.md) |
| Deferred defects and unverified surfaces | [Known limitations](known-limitations.md) |

This index lists the selected public documentation, not an export of the internal development archive. Original plans, agent requests, review reports, research artifacts, incident histories and accounting remain local. Public requirements and technical explanations must be usable without those records, private helpers or machine paths.

The README's public interface previews use two selected assets: `media/macos-library.jpg` and `media/macos-transfer.jpg`. Both are real macOS Debug captures using synthetic in-memory data. Private build, fixture and verification evidence is excluded.

## Documentation boundary

The public documentation consists of this index, the portable document format, the two architecture guides, the development guide, portability verification and known limitations, plus the two named preview images. New public documents or media require explicit content classification and an update to this index. Do not reintroduce an internal archive by broadly allowing an entire documentation directory.

Write public project prose in English. Exact format examples may include Unicode test text. An old passing run or a reorganized repository does not verify the current tree; acceptance needs the assigned criteria and actual result evidence. Keep original local evidence intact when preparing a sanitized explanation.

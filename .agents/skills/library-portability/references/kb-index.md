# Portability sources

Read paths relative to the repository root. `docs/knowledge-index.md` links back to this skill and identifies the separate requirement owners.

| Need | Source | Read before |
|---|---|---|
| JSON, Markdown and Raycast semantics | `docs/data/library-document-format.md` | Every transfer change or verification |
| Development environment and checks | `.agents/skills/project-development/SKILL.md`, `src/README.md` | Running checks |
| Feature behavior and architecture | `docs/architecture/library-transfer.md` | Changing transfer behavior |
| Live and cross-device acceptance | `specs/README.md`, `docs/testing/library-portability.md` | An assigned acceptance task |
| Deferred defects and unverified surfaces | `docs/known-limitations.md` | Deciding whether a finding belongs to the task |

This skill owns contract-sensitive verification routing. Shared behavior and acceptance criteria remain at these sources; it does not require access to the internal planning or review archive. Historical success does not establish a passing current result.

# Development sources

Read paths relative to the repository root. Shared rules live in `AGENTS.md`; documentation navigation and this skill's backlink live in `docs/knowledge-index.md`.

| Need | Source | Read before |
|---|---|---|
| Product surface, commands and platform limits | `README.md`, `src/README.md` | Any engineering task |
| Package placement and path invariants | `docs/architecture/flutter-package.md` | Moving files or changing build paths |
| Native commands and data boundaries | `docs/development.md` | Platform checks or persistent application work |
| Assigned requirements and unfinished work | `specs/README.md`, the assigned repository-accessible contract | Implementation or verification |
| Transfer behavior | `.agents/skills/library-portability/SKILL.md` | Import, export, restore or transfer UI work |

These sources contain the detailed contract. This skill owns how to apply the package and verification boundaries, not the requirements or their completion state.

---
name: library-portability
description: >
  WHEN: change or verify PromptLibrary JSON export, Markdown export, Raycast import,
  whole-library restore or transfer screens, проверь/проверяй перенос библиотеки,
  исправь/исправляй импорт и экспорт PromptLibrary. WHEN NOT: general package checks
  (project-development), cloud synchronization, unrelated formats or distribution.
allowed-tools: [Read, Grep, Glob, Bash, Edit, Write]
---

# PromptLibrary portability

## Scope

Own the project-specific procedure for transfer changes and verification. Read `references/kb-index.md`, the format and assigned requirements first. Public architecture and verification documents own behavior and criteria; internal plans are not prerequisites. Do not change contracts by inference.

## Degrees of Freedom: LOW

## Entry

Resolve the requested layer from context: codecs, plans, persistence, controller, UI or native file flow. Read `AGENTS.md` and the public development procedure. Without a task, ask which behavior to inspect. Missing real data blocks its dependent scenario, not synthetic checks.

## Procedure

Create a checklist first: `contract` · `affected layers` · `failure and preservation cases` · `evidence`.

1. Read `docs/data/library-document-format.md` fully and the assigned public requirements and callers before changing semantics. Preserve exact body and keyword, identity, dates, relationships, archive state and unused taxonomy. Keep missing, null, empty and padded values distinct as specified.
2. Trace `src/lib/src/library/transfer/`, persistence, presentation and any affected Apple adapter. Preview plans do not apply changes. Replacement resets the view; Raycast import adds entries without that reset. Cover the affected callers.
3. Verify relevant rejection and preservation cases with synthetic inputs: strict JSON and Unicode, duplicate keys and links, resource limits, Markdown fence and line-ending handling, Raycast row outcomes and unknown-field consent. For replacement, verify backup cancellation, verified external backup, stale review refusal, transaction rollback and state after reopening. Use file-backed temporary databases when durability is the claim; never point a test at application-support data.
4. Run the affected codec and plan tests in `src/test/library/transfer/`, controller tests in `src/test/library/presentation/transfer/` and caller tests selected by the change. The file-backed journey is `src/test/acceptance/library_portability_test.dart`; the guarded platform journey is `src/integration_test/library_portability_journey_test.dart`. Use the development procedure for execution. Report which layer each result proves and the tested revision; a passing synthetic journey does not complete live cross-device acceptance.

## Contract-sensitive cases

Restore from JSON, not Markdown. Byte and structure limits do not guarantee acceptable device memory. Raycast placeholders remain literal. Predicted counts do not prove insertion, and synthetic cases do not establish what real Raycast exports contain.

Real-data and device acceptance requires its assignment and verified backups. Do not upload library text, database copies or private tools as fixtures. Report failures without entry contents. A format or data-loss policy change beyond the task needs an explicit decision before dependent edits.

## Upkeep

Correct semantics at the document contract and caller behavior at its implementation and evidence owner. Update this routing and the documentation index when locations change. Keep private input acquisition and historical measurements out of this skill.

## Harness enhancements

Use a supported skill loader or read this file and its reference. Maintain the checklist with an available tool or visible progress text. Platform checks need Apple runtimes and tools; unavailable hardware remains unverified rather than proved by mocks.

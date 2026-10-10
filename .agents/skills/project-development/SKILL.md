---
name: project-development
description: >
  WHEN: implement or review PromptLibrary changes, run its local checks, verify Flutter
  package placement, реализуй/реализовывай изменения PromptLibrary, проверь/проверяй
  локальные проверки проекта. WHEN NOT: transfer document contracts (library-portability),
  unrelated repositories, distribution or device installation without an assignment.
allowed-tools: [Read, Grep, Glob, Bash, Edit, Write]
---

# PromptLibrary development

## Scope

Own the project-specific engineering procedure for the Flutter package and repository utilities. Read `references/kb-index.md` and its entry sources before work. Requirements and verification evidence remain in their documentation owners; this skill does not own task selection or release authority.

## Degrees of Freedom: MEDIUM

## Entry

Read root `AGENTS.md`, `README.md`, `src/README.md` and the assigned requirements. Infer changed behavior and allowed paths from current context. Without a task, establish the package and check context, then ask for the intended change. Private operational files are not prerequisites.

## Procedure

Create a checklist first: `assignment` · `package and data boundary` · `implementation` · `verification and report`.

1. Identify the checkout, result revision and existing changes. Match the requested outcome to the actual requirement owner. Retain unfinished portability work separately from `main`; an organizational change does not accept it.
2. Keep Flutter imports, `pubspec.yaml`, tests and Apple targets together under `src/`. Root `tests/` covers Python utility wrappers. Use temporary databases for synthetic experiments; production composition opens a persistent application-support library. Preserve package identity, dependency locks and signing configuration unless the assignment explicitly changes them.
3. Make the bounded change in its actual layer: Flutter application code in `src/lib/`, Flutter tests in `src/test/` or `src/integration_test/`, native code and XCTest under the appropriate Apple target, utilities in `scripts/`. Use `library-portability` before changing transfer semantics. Keep generated build outputs distinct from a working signed artifact.
4. Select checks from the root and application README for the changed layer. Execute Flutter and Xcode commands from `src/` with the environment filter in `AGENTS.md`; execute Python tooling checks from the root. Read each exit status and complete output. Report the result revision, observed behavior, failures, skipped checks and remaining native or device uncertainty. Update the affected documentation owner when its facts change.

## Native and data boundaries

A Dart test does not verify Swift or system dialogs. Obtain native counts from the assigned result bundle with `xcresulttool`. Production composition may reach a real library; the portability integration journey uses guarded temporary files.

Persistent app launches, real-library replacement, device installation and distribution require their corresponding assignment. Installation needs a freshly verified signed Release artifact and current profile covering the device; a no-codesign build or historical success cannot supply that proof.

## Upkeep

Keep commands and behavior at the linked README or requirement owner. Correct project-specific routing here when paths change, update the documentation index, and report unavailable prerequisites. Do not copy a second task ledger or general engineering methodology into this skill.

## Harness enhancements

Load this skill through the client if supported; otherwise read this file and its reference directly. Use an available checklist or print its items and progress. Native checks require macOS and Xcode; missing tools leave their checks unverified and do not authorize another execution route.

# AGENTS.md: PromptLibrary

## Entry and ownership

This root is the complete project boundary and has one Git root. Read `README.md`, `docs/knowledge-index.md`, `specs/README.md` and the assigned requirement owners before substantive work. Use `.agents/skills/project-development/SKILL.md` for local engineering and checks; use `.agents/skills/library-portability/SKILL.md` for transfer changes and verification. Read each selected skill's linked owners and references. Reuse completed reads.

The owner's local lead loads `private/skills/project-brain/SKILL.md` and its references first, then `private/memory/handoff.md` and the assignment. Repository-only participants use the public sources above and must not depend on that private context. Missing private inputs block only the operations requiring them; historical handoffs do not authorize resuming held work.

The selected process is repository based with direct local harness execution. Run implementation, tests, linters and builds locally. Do not launch or restore GitHub Actions execution. Keep product acceptance, organizational verification, Git delivery, device installation and distribution separate.

## Layout

`src/` is the intact Flutter package, including its `test/`, `integration_test/`, iOS and macOS targets. Root `tests/` holds Python tooling checks; `scripts/` holds project utilities. Requirements navigation is in `specs/README.md`; documentation navigation is in `docs/knowledge-index.md`. `.agents/skills/` is a real directory containing public project skills and separately excluded private local skills.

Private files are physically owned by `private/`: local skills in `private/skills/`, their provenance in `private/skills.manifest`, continuity in `private/memory/` and OMP configuration in `private/omp/`. Standard discovery paths may be ignored relative links to these owners; `.agents/skills/` itself remains a real directory with real public skill directories. Keep the private files and adapters available locally, but exclude both from GitHub and application packages. Update private files at their physical owner rather than replacing an adapter. Ignoring a tracked file does not remove it from the index or published history.

`docs/` contains only the selected public documents listed in `docs/knowledge-index.md`. Internal plans, agent requests, review reports, research artifacts, incident histories and accounting originals remain local. Public skills and shared requirements must not depend on that internal archive. Classify each new document before Git delivery rather than treating the directory name as publication approval.

## Project invariants

- Do not create nested Git repositories, gitlinks or submodules.
- Preserve unrelated dirty work, local data, original refs and unfinished branches. Do not switch another active checkout or overwrite its changes.
- Keep the unfinished portability acceptance on its separate branch. Organizational work neither accepts that product work nor authorizes its live acceptance.
- Do not change package imports, bundle identifiers, minimum targets, signing, capabilities, database schema or dependency locks as a relocation side effect.
- Private canonical knowledge, its helpers and provenance are local only and never enter project Git delivery. Retained local expertise is restored separately from clone; do not remove required local coverage just because it is ignored.
- External projections and remotes need their own exact audience and delivery contract. `private/` and runtime data do not enter any remote or application package.
- Time logs and aggregates change only on an explicit accounting instruction; organizational work grants none.
- A brief commit belongs to the root repository and uses lowercase throughout. Separate unrelated topics; inspect staged hunks and verify intermediate commits in isolation.

## Commands and evidence

Run Flutter and Xcode commands from `src/` through `env -u DEEPSEEK_API_KEY -u EXA_API_KEY -u GITHUB_PAT_TOKEN -u ORCA_AGENT_HOOK_TOKEN -u ORCA_AGENT_LAUNCH_TOKEN`. Use the commands in `src/README.md` and the assigned plan. Run tooling checks from the root with `python3 -m unittest discover -s tests -v`.

For native test counts use `xcodebuild test -resultBundlePath <path>` and `xcrun xcresulttool get test-results summary --path <path>`. Do not count interleaved stdout lines. Record exit codes after the final relevant change; inherited passing results describe their tested revision only.

Builds used for organizational checks use isolated outputs and never replace a working signed artifact. Do not launch an installed app with the real library or install on a physical device without the corresponding assignment. An iOS device artifact needs a fresh signed Release build, `codesign -dv` identity and an embedded profile before installation. A no-codesign gate artifact is not installable; do not use `flutter install` or a run session as a shortcut.

Before deleting generated build material, prove it contains no sole copy of required secrets or data. MCP registrations run external binaries only through project wrappers verifying binary provenance and target process identity. Preserve their guards when relocating paths.

## Knowledge and delivery

Write all project artifacts in English: documentation, requirements, plans, reports, handoffs, skills, issues, PRs, comments, commit messages, code comments and docstrings. Preserve exact technical identifiers, source quotations, test data and bilingual skill discovery triggers. A possible future open-source release does not authorize changing visibility, selecting a license or publishing private material.

Keep detailed product state, decisions and evidence in their existing documentation owners. The public entry is `docs/knowledge-index.md`; the private brain owns the local lead's navigation. Public project skills add concrete project procedures and must work from repository-accessible sources without private skills, helpers or knowledge stores. Update corresponding existing prompts when instructions or workflows change, preserving other writers. No AI attribution is added to commits. Keep paragraphs on one line and avoid authored em dashes.

Before publication inspect the actual outgoing tree, current triggers and applicable protection. Publication and integration use the current assignment and its exact accepted revision; passing local checks do not grant another operation.

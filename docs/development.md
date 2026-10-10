# Development and checks

Start with [AGENTS.md](../AGENTS.md), the [package layout](architecture/flutter-package.md), the [application guide](../src/README.md) and the assigned requirements. The public [project-development skill](../.agents/skills/project-development/SKILL.md) routes project-specific engineering checks. A repository-only participant does not need the owner's private tools, handoffs or operational archives.

## Command environment

Run Python utility checks from the repository root:

```bash
python3 -m unittest discover -s tests -v
```

Run Flutter and Xcode commands from `src/`, using the environment filter in `AGENTS.md`. A shell function works in both Bash and Zsh; do not store a command prefix in a string and rely on shell word splitting. Use one shell session for these snippets or define the function in each separate shell invocation.

```bash
cd src
F() {
  env -u DEEPSEEK_API_KEY -u EXA_API_KEY -u GITHUB_PAT_TOKEN -u ORCA_AGENT_HOOK_TOKEN -u ORCA_AGENT_LAUNCH_TOKEN "$@"
}
F dart format --output=none --set-exit-if-changed lib test integration_test
F flutter analyze
F flutter test
```

Choose narrower tests for an affected layer before the assigned broader gate. Complete output and exit status determine the result; a filtered output excerpt does not replace them. Record the tested revision, relevant working changes, failures, skips and unrun checks.

The optional Inspector wrapper resolves its default binary under the developer's home directory. Set `PROMPT_LIBRARY_MCP_SERVER` to select another installation. The wrapper still requires the pinned binary checksum and the diagnostic application's identity before starting the server; no Inspector binary or private MCP registration is supplied by this repository.

## Native results and builds

Native test counts come from `.xcresult` summaries. Use an assigned isolated package copy when protecting a working artifact, fresh result-bundle paths and an actually available simulator. Set `TASK_IOS_SIMULATOR` to its identifier before the iOS commands below, with `F` defined in the same shell.

```bash
TASK_RESULTS="$(mktemp -d)"
F flutter build macos --debug
F xcodebuild test -workspace macos/Runner.xcworkspace -scheme Runner -configuration Debug -destination 'platform=macOS' -resultBundlePath "$TASK_RESULTS/macos.xcresult"
F xcrun xcresulttool get test-results summary --path "$TASK_RESULTS/macos.xcresult"
F xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug -destination "platform=iOS Simulator,id=$TASK_IOS_SIMULATOR" -resultBundlePath "$TASK_RESULTS/ios.xcresult"
F xcrun xcresulttool get test-results summary --path "$TASK_RESULTS/ios.xcresult"
```

Use the platform channel and portability integration tests selected by the assignment. macOS Release and iOS Debug without signing are separate build checks. Keep generated outputs isolated from a working signed device artifact.

A Dart test establishes its Dart contract. It does not prove Swift behavior, a system dialog or a physical device. Record native failures and skips from the result bundle; compare any required baseline on the actual result revision rather than copying historical counts.

## Persistent data and devices

Normal production composition opens an application-support database. Synthetic tests use temporary file-backed or in-memory databases. Never run a mutated guard or an unapproved integration path against a real library.

Launching an installed persistent application, replacing real data, installing on physical hardware and distribution require their corresponding assignment. Before device installation, obtain a fresh signed Release build and inspect its identity, embedded profile, validity and device coverage. A no-codesign build is not installable. Do not use `flutter install` or an on-device debug run as a shortcut.

## Transfer work

Read the [format contract](data/library-document-format.md), [transfer architecture](architecture/library-transfer.md) and [portability verification contract](testing/library-portability.md). The [library-portability skill](../.agents/skills/library-portability/SKILL.md) identifies affected layers and tests. Platform-specific prerequisites stay explicit; unavailable hardware is not replaced by a mock-based acceptance claim.

Checks run locally. Do not enable GitHub Actions to obtain a passing status. Git delivery, product acceptance, device installation and distribution remain separate operations.

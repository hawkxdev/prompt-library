#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root/app"

exec env \
  -u DEEPSEEK_API_KEY \
  -u EXA_API_KEY \
  -u GITHUB_PAT_TOKEN \
  -u ORCA_AGENT_HOOK_TOKEN \
  -u ORCA_AGENT_LAUNCH_TOKEN \
  flutter run \
  -d macos \
  -t lib/main_mcp.dart \
  --debug \
  --dds-port=8181 \
  --disable-service-auth-codes

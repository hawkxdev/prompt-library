#!/usr/bin/env bash

set -euo pipefail

workspace_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$workspace_root/apps/prompt_library"

exec flutter run \
  -d macos \
  -t lib/main_mcp.dart \
  --debug \
  --dds-port=8181 \
  --disable-service-auth-codes

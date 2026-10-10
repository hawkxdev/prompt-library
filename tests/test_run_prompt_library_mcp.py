"""PromptLibrary MCP app launcher tests."""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

PROJECT_ROOT = Path(__file__).parents[1]
LAUNCHER = PROJECT_ROOT / "scripts" / "run-prompt-library-mcp.sh"
SECRET_NAMES = (
    "DEEPSEEK_API_KEY",
    "EXA_API_KEY",
    "GITHUB_PAT_TOKEN",
    "ORCA_AGENT_HOOK_TOKEN",
    "ORCA_AGENT_LAUNCH_TOKEN",
)


class PromptLibraryMcpLauncherTest(unittest.TestCase):
    def test_uses_only_the_fixed_dds_port(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            capture = temp_path / "arguments.txt"
            secret_capture = temp_path / "secrets.txt"
            flutter = temp_path / "flutter"
            flutter.write_text(
                "#!/usr/bin/env bash\n"
                'printf \'%s\\n\' "$@" > "$CAPTURE_PATH"\n'
                "env | grep -E '^(DEEPSEEK_API_KEY|EXA_API_KEY|GITHUB_PAT_TOKEN|ORCA_AGENT_HOOK_TOKEN|ORCA_AGENT_LAUNCH_TOKEN)=' > \"$SECRET_CAPTURE_PATH\" || true\n",
            )
            flutter.chmod(0o755)
            env = {
                **os.environ,
                "PATH": f"{temp_path}:{os.environ['PATH']}",
                "CAPTURE_PATH": str(capture),
                "SECRET_CAPTURE_PATH": str(secret_capture),
                **{name: f"test-{name.lower()}" for name in SECRET_NAMES},
            }

            subprocess.run(
                [str(LAUNCHER)],
                cwd=PROJECT_ROOT,
                env=env,
                check=True,
            )

            arguments = capture.read_text().splitlines()
            self.assertIn("--dds-port=8181", arguments)
            self.assertNotIn("--host-vmservice-port=8182", arguments)
            self.assertEqual(
                arguments[:5],
                [
                    "run",
                    "-d",
                    "macos",
                    "-t",
                    "lib/main_mcp.dart",
                ],
            )
            self.assertEqual(secret_capture.read_text(), "")


if __name__ == "__main__":
    unittest.main()

"""PromptLibrary MCP app launcher tests."""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

WORKSPACE_ROOT = Path(__file__).parents[2]
LAUNCHER = WORKSPACE_ROOT / "tools" / "run-prompt-library-mcp.sh"


class PromptLibraryMcpLauncherTest(unittest.TestCase):
    def test_uses_only_the_fixed_dds_port(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            capture = temp_path / "arguments.txt"
            flutter = temp_path / "flutter"
            flutter.write_text(
                "#!/usr/bin/env bash\nprintf '%s\\n' \"$@\" > \"$CAPTURE_PATH\"\n",
            )
            flutter.chmod(0o755)
            env = {
                **os.environ,
                "PATH": f"{temp_path}:{os.environ['PATH']}",
                "CAPTURE_PATH": str(capture),
            }

            subprocess.run(
                [str(LAUNCHER)],
                cwd=WORKSPACE_ROOT,
                env=env,
                check=True,
            )

            arguments = capture.read_text().splitlines()
            self.assertIn("--dds-port=8181", arguments)
            self.assertNotIn("--host-vmservice-port=8182", arguments)
            self.assertEqual(arguments[:5], [
                "run",
                "-d",
                "macos",
                "-t",
                "lib/main_mcp.dart",
            ])


if __name__ == "__main__":
    unittest.main()

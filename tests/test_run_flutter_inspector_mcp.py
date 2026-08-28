"""Flutter Inspector launcher tests."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

MODULE_PATH = Path(__file__).parents[1] / "run_flutter_inspector_mcp.py"


def _load_module():
    spec = importlib.util.spec_from_file_location(
        "run_flutter_inspector_mcp",
        MODULE_PATH,
    )
    if spec is None or spec.loader is None:
        raise RuntimeError("Unable to load launcher module")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class _VmHandler(BaseHTTPRequestHandler):
    application_id = "dev.hawkx.promptlibrary"
    mode = "mcp-diagnostic"

    def do_GET(self) -> None:
        if self.path == "/getVM":
            result = {
                "pid": 4242,
                "isolates": [{"id": "isolates/1", "name": "main"}],
            }
        elif self.path.startswith("/getIsolate?"):
            result = {
                "extensionRPCs": [
                    "ext.mcp.toolkit.prompt_library_identity",
                ],
            }
        elif self.path.startswith(
            "/ext.mcp.toolkit.prompt_library_identity?",
        ):
            result = {
                "applicationId": self.application_id,
                "mode": self.mode,
                "schemaVersion": 1,
            }
        else:
            self.send_error(404)
            return

        payload = json.dumps({"jsonrpc": "2.0", "result": result}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, format: str, *args: object) -> None:
        return


class FlutterInspectorLauncherTest(unittest.TestCase):
    def setUp(self) -> None:
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), _VmHandler)
        self.thread = threading.Thread(
            target=self.server.serve_forever,
            daemon=True,
        )
        self.thread.start()
        self.addCleanup(self.server.server_close)
        self.addCleanup(self.server.shutdown)

    @property
    def port(self) -> int:
        return self.server.server_address[1]
    @property
    def module(self):
        self.assertTrue(MODULE_PATH.exists(), "Launcher module is missing")
        if not hasattr(self, "_module"):
            self._module = _load_module()
        return self._module

    def test_accepts_prompt_library_identity(self) -> None:
        identity = self.module.verify_target("127.0.0.1", self.port)

        self.assertEqual(identity["pid"], 4242)
        self.assertEqual(identity["applicationId"], "dev.hawkx.promptlibrary")
        self.assertEqual(identity["mode"], "mcp-diagnostic")

    def test_rejects_wrong_application_identity(self) -> None:
        original = _VmHandler.application_id
        _VmHandler.application_id = "dev.example.other"
        self.addCleanup(setattr, _VmHandler, "application_id", original)

        with self.assertRaisesRegex(
            self.module.VerificationError,
            "Unexpected application identity",
        ):
            self.module.verify_target("127.0.0.1", self.port)

    def test_rejects_binary_checksum_mismatch(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            binary = Path(temp_dir) / "flutter_inspector_mcp"
            binary.write_bytes(b"binary")

            with self.assertRaisesRegex(
                self.module.VerificationError,
                "checksum mismatch",
            ):
                self.module.verify_binary(binary, "0" * 64)

    def test_launches_verified_binary_with_original_arguments(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            binary = Path(temp_dir) / "flutter_inspector_mcp"
            binary.write_bytes(b"verified-binary")
            expected_hash = hashlib.sha256(binary.read_bytes()).hexdigest()
            execution: list[object] = []

            self.module.launch(
                binary=binary,
                expected_sha256=expected_hash,
                host="127.0.0.1",
                port=self.port,
                server_args=["--no-resources", "--images"],
                exec_fn=lambda path, args: execution.extend([path, args]),
            )

            self.assertEqual(execution[0], str(binary))
            self.assertEqual(
                execution[1],
                [str(binary), "--no-resources", "--images"],
            )


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Launch a verified Flutter Inspector server."""

from __future__ import annotations

import hashlib
import json
import os
import sys
from pathlib import Path
from typing import Callable, NoReturn
from urllib.parse import quote
from urllib.request import urlopen

EXPECTED_APPLICATION_ID = "dev.hawkx.promptlibrary"
EXPECTED_MODE = "mcp-diagnostic"
EXPECTED_SCHEMA_VERSION = 1
EXPECTED_EXTENSION = "ext.mcp.toolkit.prompt_library_identity"
EXPECTED_BINARY_SHA256 = (
    "4af66e03af6357b2ea80c81a3c420fa5ad62035966e0a7219709dd3634e0a026"
)
DEFAULT_BINARY = (
    Path.home()
    / "Development/tools/mcp_flutter/mcp_server_dart/build/flutter_inspector_mcp"
)


class VerificationError(RuntimeError):
    """Report target verification failures."""


def _request_json(host: str, port: int, path: str) -> dict[str, object]:
    url = f"http://{host}:{port}{path}"
    try:
        with urlopen(url, timeout=2) as response:
            payload = json.load(response)
    except Exception as error:
        raise VerificationError(f"Unable to query Dart VM at {url}: {error}") from error

    if "error" in payload:
        raise VerificationError(f"Dart VM rejected {path}: {payload['error']}")
    result = payload.get("result")
    if not isinstance(result, dict):
        raise VerificationError(f"Dart VM returned malformed result for {path}")
    return result


def verify_target(host: str, port: int) -> dict[str, object]:
    """Verify the connected VM belongs to PromptLibrary diagnostics."""
    vm = _request_json(host, port, "/getVM")
    isolates = vm.get("isolates")
    if not isinstance(isolates, list):
        raise VerificationError("Dart VM did not return isolates")

    for isolate_ref in isolates:
        if not isinstance(isolate_ref, dict):
            continue
        isolate_id = isolate_ref.get("id")
        if not isinstance(isolate_id, str):
            continue
        isolate = _request_json(
            host,
            port,
            f"/getIsolate?isolateId={quote(isolate_id, safe='')}",
        )
        extensions = isolate.get("extensionRPCs")
        if not isinstance(extensions, list) or EXPECTED_EXTENSION not in extensions:
            continue
        identity = _request_json(
            host,
            port,
            f"/{EXPECTED_EXTENSION}?isolateId={quote(isolate_id, safe='')}",
        )
        expected = {
            "applicationId": EXPECTED_APPLICATION_ID,
            "mode": EXPECTED_MODE,
            "schemaVersion": EXPECTED_SCHEMA_VERSION,
        }
        actual = {key: identity.get(key) for key in expected}
        if actual != expected:
            raise VerificationError(
                f"Unexpected application identity: expected {expected}, got {actual}",
            )
        return {
            "pid": vm.get("pid"),
            "isolateId": isolate_id,
            **actual,
        }

    raise VerificationError(
        f"Missing project identity extension {EXPECTED_EXTENSION}",
    )


def verify_binary(binary: Path, expected_sha256: str) -> None:
    """Verify the server binary checksum."""
    if not binary.is_file():
        raise VerificationError(f"Flutter Inspector binary not found: {binary}")
    actual = hashlib.sha256(binary.read_bytes()).hexdigest()
    if actual != expected_sha256:
        raise VerificationError(
            f"Flutter Inspector checksum mismatch: expected {expected_sha256}, got {actual}",
        )


def _server_address(server_args: list[str]) -> tuple[str, int]:
    host = "localhost"
    port = 8181
    for index, argument in enumerate(server_args):
        if argument.startswith("--dart-vm-host="):
            host = argument.split("=", 1)[1]
        elif argument == "--dart-vm-host" and index + 1 < len(server_args):
            host = server_args[index + 1]
        elif argument.startswith("--dart-vm-port="):
            port = int(argument.split("=", 1)[1])
        elif argument == "--dart-vm-port" and index + 1 < len(server_args):
            port = int(server_args[index + 1])
    return host, port


def launch(
    *,
    binary: Path,
    expected_sha256: str,
    host: str,
    port: int,
    server_args: list[str],
    exec_fn: Callable[[str, list[str]], object] = os.execv,
) -> None:
    """Verify the target and replace this process with the MCP server."""
    verify_binary(binary, expected_sha256)
    verify_target(host, port)
    exec_fn(str(binary), [str(binary), *server_args])


def main() -> int | NoReturn:
    """Run the verified MCP server."""
    server_args = sys.argv[1:]
    host, port = _server_address(server_args)
    binary = Path(os.environ.get("PROMPT_LIBRARY_MCP_SERVER", DEFAULT_BINARY))
    try:
        launch(
            binary=binary,
            expected_sha256=EXPECTED_BINARY_SHA256,
            host=host,
            port=port,
            server_args=server_args,
        )
    except VerificationError as error:
        print(f"flutter-inspector guard: {error}", file=sys.stderr)
        return 78
    raise AssertionError("os.execv returned unexpectedly")


if __name__ == "__main__":
    raise SystemExit(main())

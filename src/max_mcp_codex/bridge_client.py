from __future__ import annotations

import json
import os
import urllib.error
import urllib.request
from typing import Any


class BridgeError(RuntimeError):
    """Raised when the 3ds Max bridge cannot complete an operation."""


class MaxBridgeClient:
    """Small JSON-RPC client for the localhost Max bridge.

    The transport is intentionally isolated from MCP tool definitions so the
    bridge can later move from HTTP to named pipes without changing the tools.
    """

    def __init__(self, endpoint: str | None = None, timeout: float = 15.0) -> None:
        self.endpoint = endpoint or os.getenv(
            "MAX_MCP_BRIDGE_URL", "http://127.0.0.1:9766/rpc"
        )
        self.timeout = timeout

    def call(self, method: str, params: dict[str, Any] | None = None) -> dict[str, Any]:
        payload = json.dumps(
            {"jsonrpc": "2.0", "id": 1, "method": method, "params": params or {}},
            separators=(",", ":"),
        ).encode("utf-8")
        request = urllib.request.Request(
            self.endpoint,
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=self.timeout) as response:
                body = json.loads(response.read().decode("utf-8"))
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
            raise BridgeError(
                "3ds Max bridge is unavailable. Start the bridge inside 3ds Max "
                f"and check {self.endpoint}."
            ) from exc

        if "error" in body:
            raise BridgeError(str(body["error"]))
        result = body.get("result")
        if not isinstance(result, dict):
            raise BridgeError("Bridge returned an invalid result envelope.")
        return result

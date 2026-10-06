from __future__ import annotations

from typing import Any

from mcp.server.fastmcp import FastMCP

from .bridge_client import BridgeError, MaxBridgeClient


mcp = FastMCP("max-mcp-codex")
bridge = MaxBridgeClient()


def _call(method: str, params: dict[str, Any] | None = None) -> dict[str, Any]:
    try:
        return bridge.call(method, params)
    except BridgeError as exc:
        return {"ok": False, "error": str(exc), "method": method}


@mcp.tool()
def get_status() -> dict[str, Any]:
    """Return bridge status, Max version, scene sequence, and capabilities."""
    return _call("host.status")


@mcp.tool()
def get_scene_summary() -> dict[str, Any]:
    """Read a compact scene summary before planning a modeling operation."""
    return _call("scene.summary")


@mcp.tool()
def create_box(
    name: str,
    width: float,
    length: float,
    height: float,
    x: float = 0.0,
    y: float = 0.0,
    z: float = 0.0,
    dry_run: bool = False,
) -> dict[str, Any]:
    """Create one box in a single undo transaction and return its node identity."""
    return _call(
        "object.create_box",
        {
            "name": name,
            "width": width,
            "length": length,
            "height": height,
            "position": [x, y, z],
            "dry_run": dry_run,
        },
    )


@mcp.tool()
def transform_object(
    name: str,
    x: float | None = None,
    y: float | None = None,
    z: float | None = None,
    rx: float | None = None,
    ry: float | None = None,
    rz: float | None = None,
    dry_run: bool = False,
) -> dict[str, Any]:
    """Apply an explicit transform and return the post-edit transform."""
    return _call(
        "object.transform",
        {
            "name": name,
            "position": None if None in (x, y, z) else [x, y, z],
            "rotation_degrees": None if None in (rx, ry, rz) else [rx, ry, rz],
            "dry_run": dry_run,
        },
    )


@mcp.tool()
def verify_scene() -> dict[str, Any]:
    """Run deterministic scene checks after an edit."""
    return _call("scene.verify")


def main() -> None:
    mcp.run()


if __name__ == "__main__":
    main()

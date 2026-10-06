from __future__ import annotations

import json
import socket
import sys
import threading
from unittest.mock import patch
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parents[1] / "src"))

from max_mcp_codex.bridge_client import MaxBridgeClient, _legacy_command
from max_mcp_codex import server as mcp_server


def main() -> None:
    ready = threading.Event()
    captured: list[dict] = []
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.bind(("127.0.0.1", 0))
    server.listen(1)
    port = server.getsockname()[1]

    def serve() -> None:
        ready.set()
        conn, _ = server.accept()
        with conn:
            data = b""
            while not data.endswith(b"\n"):
                data += conn.recv(4096)
            captured.append(json.loads(data.decode("utf-8")))
            result = json.dumps({"ok": True, "scene_seq": 4})
            envelope = json.dumps(
                {"success": True, "requestId": "1", "result": result, "error": ""}
            ).encode("utf-8")
            conn.sendall(envelope + b"\n")
        server.close()

    threading.Thread(target=serve, daemon=True).start()
    ready.wait(2)
    result = MaxBridgeClient(f"tcp://127.0.0.1:{port}", timeout=2).call("scene.verify")
    assert result["ok"] is True
    assert result["scene_seq"] == 4
    assert captured[0]["type"] == "maxscript"
    assert "JsonConvert" in captured[0]["command"]
    assert "Codex_Box" in _legacy_command(
        "object.create_box",
        {"name": "Codex_Box", "width": 1, "length": 2, "height": 3},
    )
    cylinder = _legacy_command(
        "object.create_cylinder",
        {"name": "Codex_Cylinder", "radius": 2, "height": 4, "segments": 12},
    )
    assert 'cylinder name:name' in cylinder
    assert 'sides:12' in cylinder
    mesh = _legacy_command(
        "object.create_mesh",
        {
            "name": "Codex_Mesh",
            "vertices": [[0, 0, 0], [1, 0, 0], [0, 1, 0]],
            "faces": [[1, 2, 3]],
            "position": [4, 5, 6],
        },
    )
    assert 'mesh name:name vertices:verts faces:faces' in mesh
    assert 'point3 1.0 0.0 0.0' in mesh
    assert '(point3 1 2 3)' in mesh
    with patch.object(mcp_server.bridge, "call", return_value={"ok": True, "legacy": True}):
        guarded = mcp_server._call("object.transform", {"expected_scene_seq": 1})
    assert guarded["error"]["code"] == "scene_guard_unavailable"
    partial = _legacy_command(
        "object.transform",
        {"name": "Codex_Box", "position": [1, None, 3], "rotation_degrees": [None, 45, None]},
    )
    assert "n.position.x=1.0" in partial
    assert "n.position.z=3.0" in partial
    assert "n.rotation=eulerangles" in partial
    assert "delete n" in _legacy_command("object.delete", {"name": "Codex_Box"})
    print("client transport tests passed")


if __name__ == "__main__":
    main()

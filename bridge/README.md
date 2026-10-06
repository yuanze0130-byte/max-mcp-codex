# 3ds Max Bridge

桥接层运行在 3ds Max 内部，负责把 JSON-RPC 请求转换成 MaxScript 或 `pymxs` 操作。

首版约定：

- 只监听 `127.0.0.1:9766`。
- 请求和响应使用 JSON-RPC 2.0。
- 所有场景修改使用一次 Undo 事务。
- 修改响应必须包含 `scene_seq`、对象名称和稳定节点引用。
- `create_mesh` 接受世界单位顶点和 1-based 三角面索引。
- bundled HTTP bridge 的写操作可传 `expected_scene_seq`，场景在规划后发生变化时会返回 `stale_scene`；旧版 TCP fallback 会明确返回 `scene_guard_unavailable`。
- 启动响应必须包含 Max 版本和能力清单。

后续实现应优先使用专用操作，不把任意脚本执行作为默认 API。

# Max MCP Codex

面向 Codex 建模工作流的 Autodesk 3ds Max MCP 适配器。

这个项目的目标不是让 3ds Max 原生实现 MCP，而是提供一个稳定的外部 MCP 服务和一个运行在 3ds Max 内部的桥接层，让 Codex 可以按“查询场景 -> 执行修改 -> 验证结果 -> 必要时回滚”的方式完成建模。

## 设计目标

- MCP 服务运行在 3ds Max 外部，避免依赖 Max 内置 Python 版本。
- Max 内部桥接优先使用 MaxScript / `pymxs`，覆盖 3ds Max 2022-2027。
- 工具使用严格 JSON Schema，优先提供高层建模操作，不把任意脚本执行作为默认入口。
- 每次修改都返回可验证的对象引用、场景序号和变更摘要。
- 支持 dry-run、Undo、能力检测和视口截图，方便 Codex 自主校验。

## 兼容性策略

| 版本 | 状态 |
| --- | --- |
| 3ds Max 2022-2026 | 目标稳定支持 |
| 3ds Max 2027 | Preview，完成实机验证后转 Stable |
| 3ds Max 2017-2021 | 未来可通过 MaxScript/pymxs 适配，暂不作为首发承诺 |

MCP 是外部协议，3ds Max 没有原生 MCP 起始版本。若未来增加 C++ 插件，则必须按 Max SDK 版本分别构建；首版不依赖 C++ 插件。

## 目录

```text
src/max_mcp_codex/   外部 MCP 服务
bridge/              Max 内部桥接协议和脚本
docs/                Codex 工作流、工具设计和兼容性说明
tests/               协议和桥接客户端测试
```

## 本地开发

```powershell
py -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -e .
python -m max_mcp_codex.server
```

当前骨架只负责 MCP 工具层和桥接调用契约；MaxScript 桥接运行时会在后续提交中加入。

## 安全默认值

- 桥接只监听 `127.0.0.1`。
- 任意 MaxScript 执行默认关闭。
- 文件访问使用显式允许目录。
- 场景修改必须经过单次 Undo 事务。
- 工具错误返回结构化错误，不把异常堆栈直接当作成功消息。

## 许可

代码建议使用 MIT 或 Apache-2.0。不要把 Autodesk SDK、3ds Max 安装文件或商业渲染器二进制提交到仓库。Autodesk 和 3ds Max 是 Autodesk, Inc. 的商标。

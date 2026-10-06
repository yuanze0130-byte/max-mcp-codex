# Max MCP Codex

面向 Codex 建模工作流的 Autodesk 3ds Max MCP 适配器。

安装和使用请参阅：[安装使用教程](安装使用教程.md)。用户只需要下载整个项目文件夹并在 Codex 中打开它；项目级 `.codex/config.toml` 会让 Codex 自动执行 `run_mcp.ps1`，创建 `.venv`、安装项目并启动 MCP。

这个项目的目标不是把 MCP 误认为 3ds Max 的原生建模 API，而是提供一个稳定的外部 MCP 服务和一个运行在 3ds Max 内部的桥接层，让 Codex 可以按“查询场景 -> 执行修改 -> 验证结果 -> 必要时回滚”的方式完成建模。

## 设计目标

- MCP 服务运行在 3ds Max 外部，避免依赖 Max 内置 Python 版本。
- Max 内部桥接优先使用 MaxScript / `pymxs`，覆盖 3ds Max 2022-2027。
- 工具使用严格 JSON Schema，优先提供高层建模操作，不把任意脚本执行作为默认入口。
- 支持从显式三角网格开始创建墙体、道路和自定义楼体轮廓。
- 每次修改都返回可验证的对象引用、场景序号和变更摘要。
- 支持 dry-run、Undo、能力检测和可重复的场景 smoke test，方便 Codex 自主校验。

## 兼容性策略

| 版本 | 状态 |
| --- | --- |
| 3ds Max 2022 | bundled MaxScript/HTTP bridge 目标支持 |
| 3ds Max 2023-2025 | TCP fallback + bundled bridge；本机 2025 已实机验证 |
| 3ds Max 2026-2027 | 目标稳定支持，按对应 SDK/GUP 单独验证 |
| 3ds Max 2017-2021 | 未来可通过 MaxScript/pymxs 适配，暂不作为首发承诺 |

MCP 是外部协议，不能用“某个 Max 版本开始原生支持 MCP”来描述。不同安装可能同时存在社区/厂商插件；本项目只依赖 MaxScript、.NET 和 localhost 通讯，不依赖 Autodesk SDK 或商业渲染器。

## 连接模式

默认连接 `tcp://127.0.0.1:8765`，这是当前 3ds Max MCP 插件常见的 TCP fallback。若使用本仓库的 HTTP 桥接脚本，在 Max 内执行 `fileIn "bridge/max_mcp_bridge.ms"` 后调用 `mcp_start port:9766`，再设置：

```powershell
$env:MAX_MCP_BRIDGE_URL = "http://127.0.0.1:9766"
```

两种模式都由同一个 MCP 工具层承载；不要让 bundled HTTP bridge 和 Max TCP fallback 监听同一端口。

## Codex 自动安装入口

`.codex/config.toml` 是唯一的安装入口。它调用 `run_mcp.ps1`，脚本会在项目目录内完成依赖安装并启动服务：

```text
下载 ZIP → 解压 → 用 Codex 打开项目根目录 → 信任项目 → 等待 MCP 启动
```

首次启动要求目标电脑已安装 Python 3.10+，并允许 Codex 执行 PowerShell、写入项目目录和访问 Python 包索引。安装日志位于 `.codex/install.log`。不需要手动执行 `codex mcp add` 或编辑用户级 Codex 配置。

## 目录

```text
src/max_mcp_codex/   外部 MCP 服务
bridge/              Max 内部桥接协议和脚本
docs/                Codex 工作流、工具设计和兼容性说明
tests/               协议和桥接客户端测试
```

## 自动安装后的使用

Codex 启动项目级 MCP 后，先调用 `get_status`，再调用 `get_scene_summary`。建模工具包括基础体、`create_mesh`、变换和删除；写操作支持 `dry_run`，也可以传入 `expected_scene_seq` 防止基于旧场景误改，修改后用 `verify_scene` 收口。开发者调试和测试也应从项目级 `.codex/config.toml` 启动，避免产生第二套用户安装流程。

### 真实 Max smoke test

在 PowerShell 中设置仓库根目录，然后用已安装的 3ds Max 运行测试脚本：

```powershell
$env:MAX_MCP_CODEX_ROOT = (Get-Location).Path
& "C:\Program Files\Autodesk\3ds Max 2025\3dsmax.exe" -silent -U MAXScript (Resolve-Path tests\test_bridge.ms).Path
```

脚本会创建盒体和圆柱体、变换盒体、删除圆柱体、检查场景，并保存临时 `.max` 文件。测试完成后关闭由命令启动的 Max 进程。`tests/test_client.py` 可用 Max 2025 自带 Python 运行，不要求安装系统 Python。

## 安全默认值

- 桥接只监听 `127.0.0.1`。
- 任意 MaxScript 执行默认关闭。
- 文件访问使用显式允许目录。
- 场景修改必须经过单次 Undo 事务。
- 工具错误返回结构化错误，不把异常堆栈直接当作成功消息。

## 许可

代码建议使用 MIT 或 Apache-2.0。不要把 Autodesk SDK、3ds Max 安装文件或商业渲染器二进制提交到仓库。Autodesk 和 3ds Max 是 Autodesk, Inc. 的商标。

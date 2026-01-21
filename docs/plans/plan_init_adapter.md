# 多平台入口与引导适配（main/bootstrap）

本 ExecPlan 是一份活文档。`Progress`、`Surprises & Discoveries`、`Decision Log`、`Outcomes & Retrospective` 四个章节必须在执行过程中持续更新。

本仓库有 ExecPlan 规范文件 `.agent/PLANS.md`，本计划必须按该规范维护。

## Purpose / Big Picture

让同一套规则与适配层在 Love2D、Eggy 与 Oasis 三个平台都能稳定进入运行，同时保持现有 Love2D 与 `--all-ai` 行为不变。用户能够通过明确入口文件或显式平台参数启动对应运行环境，并能在每个平台看到 UI 更新/回合推进。验证方式是本地跑回归脚本、Oasis 现有冒烟脚本，以及在 Eggy 编辑器内观察 `EVENT.GAME_INIT`、`UI_CUSTOM_EVENT` 的驱动是否生效。

## Progress

- [x] (2026-01-21 19:10Z) 阅读 `main.lua`、`bootstrap.lua`、Eggy/Oasis runtime 与相关文档，整理平台入口约束与事件驱动方式。
- [x] (2026-01-21 19:40Z) 设计并实现统一入口分发模块，迁移 `main.lua` 逻辑以保持原行为不变。
- [x] (2026-01-21 19:40Z) 新增 Eggy/Oasis 明确入口文件，并定义平台选择策略与手动入口说明。
- [x] (2026-01-21 19:40Z) 使 `bootstrap.lua` 向后兼容并可安全多次调用。
- [ ] (2026-01-21 19:45Z) 执行测试与平台验收步骤（完成：deps_check/regression；剩余：Oasis 冒烟失败需确认原因）。

## Surprises & Discoveries

- Observation: `main.lua` 当前只覆盖 Love2D 与 `--all-ai` 头无界面模式，没有 Eggy/Oasis 的入口逻辑。
  Evidence: `main.lua`
- Observation: Eggy 入口是事件驱动，依赖 `EVENT.GAME_INIT` 与 `LuaAPI.set_tick_handler`、`EVENT.UI_CUSTOM_EVENT`。
  Evidence: `docs/eggy/EggyAPI.md`, `src/adapters/eggy/eggy_runtime.lua`
- Observation: Oasis runtime 需要外部传入 UI 根节点与事件驱动函数，无法在入口里直接启动游戏。
  Evidence: `src/adapters/oasis/oasis_runtime.lua`
- Observation: `tests/oasis_adapter_smoke.lua` 在刷新棋盘时报 `tile_state` 为空导致崩溃。
  Evidence: `src/adapters/core/ui_tile.lua:8` 报错 `attempt to index a nil value (local 'tile_state')`。

## Decision Log

- Decision: 保持 Love2D 与 `--all-ai` 行为完全一致，仅做入口组织与分发，不改规则层与适配层逻辑。
  Rationale: 满足“功能不变”要求，并降低平台接入的回归风险。
  Date/Author: 2026-01-21 / Codex

- Decision: 新增一个共享入口分发模块，并让 `main.lua`、Eggy 入口、Oasis 入口共同复用。
  Rationale: 同一逻辑至少 2 个调用点，符合抽象条件，同时减少重复。
  Date/Author: 2026-01-21 / Codex

- Decision: Oasis 入口只暴露 `OasisRuntime` 与转发函数，不自动调用 `on_begin_play`。
  Rationale: Oasis 需要平台提供 `ui_root` 等参数，入口侧自动启动会造成空参数或错误。
  Date/Author: 2026-01-21 / Codex

- Decision: 不在本次入口改造中修复 Oasis 冒烟脚本的 `tile_state` 崩溃问题，仅记录现象。
  Rationale: 本次目标是入口组织与平台分发，且 CodingDiscipline 要求行为不变，避免越界改动。
  Date/Author: 2026-01-21 / Codex

## Outcomes & Retrospective

已新增统一入口模块并调整 `main.lua`，新增 `eggy_main.lua`/`oasis_main.lua` 入口文件，`bootstrap.lua` 支持可选 `extra` 且避免重复拼接。`lua tests/deps_check.lua` 与 `lua tests/regression.lua` 通过；`lua tests/oasis_adapter_smoke.lua` 在刷新棋盘时报 `tile_state` 为空导致失败，暂未在本次修复。

## Context and Orientation

入口相关的核心文件是仓库根目录的 `main.lua` 与 `bootstrap.lua`。`main.lua` 负责 Love2D UI 或 `--all-ai` 头无界面模式；`bootstrap.lua` 负责补齐 `package.path`。Eggy 的运行入口在 `src/adapters/eggy/eggy_runtime.lua`，它通过 `LuaAPI.global_register_trigger_event(EVENT.GAME_INIT, ...)` 与 `LuaAPI.set_tick_handler(...)` 驱动；相关事件与 API 约束在 `docs/eggy/EggyAPI.md`。Oasis 的入口在 `src/adapters/oasis/oasis_runtime.lua`，需要外部传入 UI 根节点并显式调用 `on_begin_play/on_tick/on_ui_event`。`docs/oasis/README.md` 表明 Oasis 场景在 Unreal/UGC 体系下运行，因此入口应保持事件驱动与外部参数注入。

本计划中的“平台入口”指平台加载脚本时触发的第一段 Lua 逻辑；“分发模块”指一个统一的 Lua 模块，负责选择平台并调用相应 runtime。

## Plan of Work

首先新增一个共享入口模块（例如 `src/entry.lua`），把现有 `main.lua` 中的 Love2D 与 `--all-ai` 逻辑搬入该模块，逻辑与输出保持完全一致，只改变调用位置。该模块负责解析平台选择，优先级为：显式传入 `platform`、环境变量 `MONOPOLY_PLATFORM`、命令行 `--platform=...`、命令行 `--all-ai`、`love` 全局存在、Eggy 的 `LuaAPI+EVENT` 全局存在。为保持现有行为，在没有明确平台时仍默认走 Love2D 逻辑。

然后将 `main.lua` 改为只调用分发模块，保证 Love2D 的入口仍是 `main.lua`，并支持 `--all-ai`。同时新增两个平台入口文件（例如 `eggy_main.lua` 与 `oasis_main.lua`），它们只做 `bootstrap` 与 `Entry.run({platform=...})` 调用。Eggy 入口需要调用 `EggyRuntime.install()`（由分发模块完成），从而注册 `EVENT.GAME_INIT` 与 `UI_CUSTOM_EVENT`。Oasis 入口在分发模块中只暴露 `OasisRuntime` 与转发函数，等待平台在合适时机传入 `ui_root` 调用 `on_begin_play`。

最后调整 `bootstrap.lua` 以保持向后兼容：仍支持传入 “额外路径数组”，并新增可选 `opts.extra` 的写法；同时增加一次性防护，避免重复拼接导致路径无限增长。该防护必须保证第一次传入的额外路径仍能生效，并在已有路径时不重复追加相同片段。

如有必要，在 `README.md` 中新增一小段“平台入口”说明，列出 Love2D、Eggy、Oasis 的入口文件与平台选择方式，便于新人接入。

## Concrete Steps

在仓库根目录执行或编辑以下文件：

1) 新增入口分发模块（例如 `src/entry.lua`），迁移 `main.lua` 的 Love2D 与 `--all-ai` 逻辑，保持输出文本与行为一致。
2) 修改 `main.lua`，仅保留 `require("bootstrap")()` + `require("src.entry").run()`。
3) 新增 `eggy_main.lua` 与 `oasis_main.lua`，内容只做 bootstrap 与显式平台运行。
4) 更新 `bootstrap.lua` 为向后兼容且可安全重复调用。
5) 可选：在 `README.md` 补充平台入口说明。

示例调用（作为实现后的行为验证样例）：

    lua main.lua --all-ai

期望输出包含：

    === All-AI Mode Start ===
    ...
    === Game Over ===

Oasis 冒烟脚本：

    lua tests/oasis_adapter_smoke.lua

期望输出包含：

    [OasisAdapter] init ok
    [OasisAdapter] tick ok

## Validation and Acceptance

- 运行 `lua tests/deps_check.lua` 与 `lua tests/regression.lua` 均通过。
- `lua tests/oasis_adapter_smoke.lua` 输出 `init ok` 与 `tick ok`。
- Love2D 模式仍可启动 UI；`--all-ai` 模式仍打印原有日志并结束。
- Eggy 编辑器中，`EVENT.GAME_INIT` 触发后能初始化游戏与 UI，`EVENT.UI_CUSTOM_EVENT` 能触发一次有效 action（例如“下一回合”按钮使回合数前进）。

## Idempotence and Recovery

入口改动是新增文件与逻辑搬迁，重复执行不会破坏状态。若发现平台分发异常，可临时恢复原 `main.lua` 逻辑并仅保留新增入口文件；若 `bootstrap.lua` 改动导致路径异常，可回退为原实现并保留入口分发模块调用一次的约束。

## Artifacts and Notes

预期入口文件结构（示意，保持简短）：

    -- eggy_main.lua
    require("bootstrap")()
    require("src.entry").run({ platform = "eggy" })

    -- oasis_main.lua
    require("bootstrap")()
    require("src.entry").run({ platform = "oasis" })

## Interfaces and Dependencies

入口分发模块需提供：

- `Entry.run(opts)`：
  - `opts.platform` 可取 `love2d`、`eggy`、`oasis`、`headless`。
  - 当 `opts.platform` 为 `eggy`：调用 `EggyRuntime.install()`。
  - 当 `opts.platform` 为 `oasis`：返回或挂载 `OasisRuntime`，但不自动调用 `on_begin_play`。
  - 当 `opts.platform` 为 `love2d`：与现有 `main.lua` 逻辑一致，创建 `LoveLayer` 并 `attach()`。
  - 当 `opts.platform` 为 `headless`：与现有 `--all-ai` 逻辑一致。

`bootstrap.lua` 继续支持：

- `require("bootstrap")({ "src/gameplay/?.lua" })` 旧写法。
- 新写法可选：`require("bootstrap")({ extra = { ... } })`。
- 必须保证路径只追加一次且兼容已有 `package.path`。

Eggy 依赖 `LuaAPI.global_register_trigger_event` 与 `LuaAPI.set_tick_handler`，事件包括 `EVENT.GAME_INIT` 与 `EVENT.UI_CUSTOM_EVENT`，详见 `docs/eggy/EggyAPI.md`。

Oasis 依赖 `OasisRuntime.on_begin_play(opts)` 的 `opts.ui_root` 参数，详见 `src/adapters/oasis/oasis_runtime.lua`。

## 变更记录

2026-01-21：首次建立计划，明确平台入口分发、Eggy/Oasis 事件驱动约束与入口文件策略。

Plan update note: 2026-01-21 / Codex：创建本 ExecPlan，汇总入口现状与平台接入策略，作为后续实现依据。
Plan update note: 2026-01-21 / Codex：完成入口分发与 bootstrap 调整，记录测试结果与 Oasis 冒烟失败原因。

# Monopoly 全局重构计划（核心层与适配层分离）


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。本文件遵循 `.agent/PLANS.md` 的规范。


## 目的 / 全局视角


基于 `.github/docs/SecretOfEscaper/architecture_study.md` 的对照结论，建立“核心逻辑层（Core）+ 引擎适配层（Adapter）”的分层结构，让 Monopoly 的回合逻辑、状态树、选择系统与效果系统不再依赖 Eggy 运行时细节。完成后，核心层可在无引擎环境下被脚本驱动，适配层仅负责 UI/事件/引擎对象绑定。可观察结果是：核心入口可被脚本独立调用，`lua .github/tests/regression.lua` 仍通过，且运行时入口仍能启动原有流程。


## 进度


- [ ] (2026-01-31 13:20Z) 明确 Core/Adapter 分层目标与接口清单，补充到本计划的接口与依赖
- [ ] (2026-01-31 13:20Z) 新增 Core 入口与最小适配层，并保持旧入口可用
- [ ] (2026-01-31 13:20Z) 迁移或包装核心逻辑模块，建立兼容桥接与 require 重定向
- [ ] (2026-01-31 13:20Z) 更新运行时入口与脚本验证，补充可复现的 smoke 脚本
- [ ] (2026-01-31 13:20Z) 完成验证与复盘，记录可迁移/不可迁移的风险点


## 意外与发现


当前暂无记录。实施中如发现核心层仍依赖引擎对象（例如 `GameAPI` 不可替换）或 Adapter 难以隔离，请记录具体调用点与证据片段。


## 决策日志


当前暂无记录。实施过程中每次关键判断都需以“决策：… 理由：… 日期/作者：…”的句式记录。


## 结果与复盘


尚未开始。完成后总结 Core/Adapter 的落地范围、遗留耦合点与下一阶段重构建议。


## 背景与导读


Monopoly 当前入口 `main.lua` → `init.lua` → `Manager.GameManager.Entry.install()`，逻辑层与运行时强耦合在 `Manager/System/Runtime.lua` 与 `Manager/TurnManager/GUI`。从 `.github/docs/SecretOfEscaper/architecture_study.md` 可见，SecretOfEscaper 以 “Map/Mode/Entity” 组织玩法并将 UI/行为树/导航等通用能力作为 Library 提供；Monopoly 则以 “回合/状态树/规则服务” 为核心。为了后续全局重构，应先建立清晰的核心层边界，把 `Game`、`TurnManager`、`ChoiceService`、`EffectPipeline` 等逻辑归入 Core，并以 Adapter 实现 UI 与引擎事件绑定。


## 工作计划


先定义 Core/Adapter 的职责边界与接口清单，确定哪些模块必须在 Core 内保持纯 Lua（无引擎依赖），哪些模块留在 Adapter。随后新增 Core 入口与最小适配层，保持旧入口继续可运行。接着用“包装/桥接”的方式把核心逻辑模块迁移到 Core，旧路径以薄封装保留兼容。最后更新入口与验证脚本，让核心逻辑可在无引擎环境下进行 smoke 运行，并补齐回归测试与复盘结论。


## 具体步骤


1) 在 `Core/Ports` 新增接口说明文件，描述核心对外依赖的端口（以注释或空实现表达接口即可）：

    - `Core/Ports/RuntimePort.lua`：必须包含 `push_popup(payload)`, `on_tile_owner_changed(tile_id, owner_id)`, `on_tile_upgraded(tile_id, level)`，以及 `wait_action_anim`/`wait_move_anim` 两个只读标志。
    - `Core/Ports/RandomPort.lua`：封装 `next_int(min, max)`，用于替换对 `GameAPI.random_int` 的直接调用。

2) 新增 Core 入口文件（保持与现有 Game 对接）：

    - `Core/Game.lua`：内部直接 `require("Manager.GameManager.Game")` 并导出 `new/advance_turn/dispatch_action` 作为兼容入口。
    - `Core/CompositionRoot.lua`：包装 `Manager.GameManager.CompositionRoot`，允许注入 `runtime_port` 与 `random_port`（先透传给现有结构即可）。
    - `Core/Entry.lua`：提供 `install(opts)`，内部调用旧 `Entry.install`，但统一收敛到 Core 命名空间，后续迁移可只改 Core。

3) 新增 Adapter 最小实现，保持旧入口可用：

    - `Adapters/EggyRuntimePort.lua`：封装 `Manager/System/Runtime.lua` 现有 runtime 对象的 UI 方法与状态标志，暴露为 `RuntimePort` 实例。
    - `Adapters/EggyEntry.lua`：调用 `Core.Entry.install` 并把 `RuntimePort` 传入。

4) 为核心模块建立兼容桥接（不移动文件，仅添加重定向入口）：

    - 在 `Core/` 下建立目录结构映射：`Core/GameManager`, `Core/TurnManager`, `Core/ChoiceManager`, `Core/EffectManager`, `Core/ItemManager`, `Core/LandManager`, `Core/MarketManager`, `Core/MovementManager`。
    - 每个 `Core/*/__init.lua` 或关键文件只需 `return require("Manager.<同名>")`，确保新旧路径都可引用。

5) 更新入口并补充 smoke 脚本：

    - `main.lua` 或 `init.lua` 中改为优先调用 `Adapters/EggyEntry.install()`，保留旧入口作为 fallback。
    - 新增 `.github/scripts/core_smoke.lua`：在无引擎环境下构造 `Core.Game`，跑 `advance_turn` 若干次，验证 `Store` 与 `TurnManager` 能工作。

6) 运行验证并记录输出：

    - `lua .github/tests/regression.lua`
    - `lua .github/scripts/core_smoke.lua`

将关键输出片段与验证结论写入“产物与备注”。


## 验证与验收


必须满足以下条件：

1) `lua .github/tests/regression.lua` 通过且无新增失败。
2) `lua .github/scripts/core_smoke.lua` 可运行并输出至少一次完整回合推进日志（例如当前玩家、回合数变化）。
3) 原入口仍可通过 `Adapters/EggyEntry` 启动（如需要手动启动，记录最小步骤与观察点）。


## 可重复性与恢复


本计划的修改可反复执行。若发现 Core/Adapter 引入问题，可按以下方式回滚：删除 `Core/` 与 `Adapters/` 目录，并恢复 `main.lua/init.lua` 的原入口调用。新增脚本 `.github/scripts/core_smoke.lua` 可直接删除。


## 产物与备注


关键产物：

- `Core/Ports/RuntimePort.lua`
- `Core/Ports/RandomPort.lua`
- `Core/Game.lua`
- `Core/CompositionRoot.lua`
- `Core/Entry.lua`
- `Adapters/EggyRuntimePort.lua`
- `Adapters/EggyEntry.lua`
- `.github/scripts/core_smoke.lua`

验证示例输出片段（示例）：

    lua .github/scripts/core_smoke.lua
    turn=1 current_player=玩家1
    turn=2 current_player=玩家2


## 接口与依赖


核心接口要求如下：

- `Core.Entry.install(opts)`：返回运行时对象或 game 实例，opts 可包含 `runtime_port` 与 `random_port`。
- `Core.Game.new(opts)`：创建 game，opts 至少包含 `players`, `ai`, `seed`。
- `RuntimePort` 需要实现：

    - `push_popup(payload: table)`
    - `on_tile_owner_changed(tile_id: number, owner_id: number|nil)`
    - `on_tile_upgraded(tile_id: number, level: number)`
    - `wait_action_anim: boolean`
    - `wait_move_anim: boolean`

依赖说明：

- 仍使用现有 `Manager` 模块作为底层实现，Core 仅是命名空间收敛与接口抽象。
- 引擎相关调用（`GameAPI`, `LuaAPI`, `UIManager`）必须只出现在 Adapter 或 GUI 层，核心层不得新增新的引擎依赖。


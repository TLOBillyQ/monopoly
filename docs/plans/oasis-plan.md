# Oasis 适配层 ExecPlan

本 ExecPlan 是一份活文档。`Progress`、`Surprises & Discoveries`、`Decision Log`、`Outcomes & Retrospective` 四个章节必须在执行过程中持续更新。

本仓库有 ExecPlan 规范文件 `.agent/PLANS.md`，本计划必须按该规范维护。

## Purpose / Big Picture

目标是在腾讯绿洲启元编辑器环境里运行蛋仔大富翁规则层，并通过适配层把引擎事件、UI 事件和游戏逻辑打通。完成后，开发者可以在 OASIS 项目中挂载 `src/adapters/oasis`，进入游戏时自动创建并驱动规则层，UI 按钮触发动作，界面能显示回合、玩家、格子等核心信息。验证方式是：在本仓库用 Lua 模拟 OASIS 环境跑一条最小流程，以及在编辑器里触发按钮观察 UI 与日志。

## Progress

- [x] (2026-01-20 12:54Z) 阅读 `.agent/PLANS.md`、`.agent/CODING.md`、`.agent/THIS.md`，确认 ExecPlan 规范与 CodingDiscipline 约束。
- [x] (2026-01-20 12:54Z) 盘点现有适配层 `src/adapters/eggy`、`src/adapters/love2d`，确认可复用逻辑与入口方式。
- [x] (2026-01-20 12:54Z) 阅读 `docs/oasis/Areoplane` 模板工程的事件系统与 UI 入口，确认 OASIS 集成路径与可用回调。
- [x] (2026-01-20 13:49Z) 完成共享核心抽取计划，见 `docs/plans/adapters-plan.md`。
- [x] (2026-01-20 14:05Z) 新建 `src/adapters/oasis` 适配层并接入 BeginPlay、Tick、UI 事件入口。
- [x] (2026-01-20 14:05Z) 增加 OASIS 适配层的最小 Lua 模拟测试与验证步骤。
- [x] (2026-01-20 14:05Z) 更新 ExecPlan 各章节记录实现与验证结果。

## Surprises & Discoveries

暂无。执行过程中如发现引擎事件或 UI API 与预期不一致，需要在此记录，并附上最短可复现证据。

## Decision Log

- Decision: 抽出 eggy/love2d/oasis 的共同核心到 `src/adapters/core`，由各平台适配层复用，避免相似逻辑并存。
  Rationale: CodingDiscipline 要求相似逻辑必须合并，且已有多个真实调用点。
  Date/Author: 2026-01-20 / Codex

- Decision: Oasis 适配层采用“运行时入口 + UI 桥接 + UI 状态”三层结构，并在模板工程中从 `UGCGameState` 或 `UGCPlayerController` 入口触发。
  Rationale: 该结构与现有 `eggy_runtime.lua` 入口相近，便于对齐 Tick、事件与 UI 回调。
  Date/Author: 2026-01-20 / Codex

- Decision: 将共享核心抽取从本计划拆分为独立 ExecPlan。
  Rationale: 共享核心抽取跨平台且规模大，拆分后便于独立推进并保持 Oasis 集成目标清晰。
  Date/Author: 2026-01-20 / Codex

- Decision: Oasis 适配层复用 `src/adapters/core/adapter_layer.lua` 和 Love2D 的 board presenter。
  Rationale: 共享核心可直接处理自动运行与选择超时，Love2D presenter 已包含格子与覆盖物构建逻辑，可减少重复实现。
  Date/Author: 2026-01-20 / Codex

## Outcomes & Retrospective

已完成 OASIS 适配层与 Lua 模拟测试，`tests/oasis_adapter_smoke.lua` 与现有依赖/回归测试通过。后续仅需在编辑器内接入 BeginPlay/Tick 与 UI 回调验证。

## Context and Orientation

本仓库的规则层入口为 `src/game.lua`，通过 `Game.new` 装配并运行回合逻辑。现有平台适配层位于 `src/adapters/eggy` 与 `src/adapters/love2d`，其中 `src/adapters/eggy/eggy_runtime.lua` 负责注册事件与 Tick，`src/adapters/eggy/eggy_layer.lua` 负责 UI 刷新与动作分发，`src/adapters/eggy/ui_state.lua` 负责 UI 节点查询与设置。

OASIS 模板工程位于 `docs/oasis/Areoplane`，里面的 `Script/Common/UGCEventSystem.lua` 是事件总线，`Script/GameConfigs/AeroplaneChessEventDefine.lua` 定义事件枚举，`Script/GameConfigs/AeroplaneChessUIManager.lua` 是 UI 创建入口，`Script/Blueprint/UGCGameState.lua` 在 `ReceiveBeginPlay` 和 `ReceiveTick` 中驱动游戏状态并派发事件，`Script/Blueprint/UGCPlayerController.lua` 负责接收客户端 UI 回调并调用 ServerRPC。这里的 “事件总线” 指 `UGCEventSystem`，它保存监听函数并在 `SendEvent` 时调用回调；“适配层” 指连接规则层与引擎 UI/输入/时钟的代码。

本计划需要新增 `src/adapters/oasis` 目录实现 OASIS 适配层，并确保 `src/adapters/eggy` 的行为完全不变。共享核心将抽到 `src/adapters/core`，以便 Eggy/Love2D/Oasis 复用。由于 OASIS 运行环境无法在本仓库直接启动，计划将加入 Lua 模拟测试以验证适配层接口在纯 Lua 环境下可运行，同时给出在编辑器中的观察点。

## Plan of Work

首先完成共享核心抽取计划，见 `docs/plans/adapters-plan.md`。该计划负责把 `src/adapters/eggy/eggy_layer.lua` 与 `src/adapters/love2d` 中平台无关的逻辑迁移到 `src/adapters/core`，并确保 Eggy/Love2D 行为不变。完成后，本计划再基于共享核心继续实现 OASIS 适配层。

然后创建 `src/adapters/oasis`，包含运行时入口、UI 状态与 OASIS UI 桥接。运行时入口负责：在 OASIS BeginPlay 时创建游戏并绑定适配层，在 Tick 时调用适配层更新逻辑，在 UI 回调时把按钮、选项等转成统一动作。UI 桥接负责对接 OASIS 的 UMG Widget，通过 `GetWidgetFromName` 找到控件，并调用 `SetText`、`SetVisibility` 或按钮状态接口更新 UI。UI 状态文件负责缓存节点引用、记录选中格子与自动运行开关。UI 事件会按统一动作格式发送给共享适配核心，动作格式与现有 Eggy 适配层一致：`ui_button`、`choice_select`、`choice_cancel`、`ui_tile_select` 与 `popup_confirm`。

最后补充一个纯 Lua 的模拟测试，提供最小的 OASIS UI 桥接假实现，验证：创建游戏、触发下一回合、选择格子、触发选择弹窗时不会报错。测试通过后，补充验证步骤说明在编辑器内应观察的日志与 UI 变化。

## Milestones

第一个里程碑完成共享适配核心与 Eggy/Love2D 适配层改造。产物是 `src/adapters/core` 新模块和更新后的 `src/adapters/eggy`、`src/adapters/love2d` 文件，运行已有 Love2D 或 Eggy 逻辑时行为不变。验证方式是运行现有 Lua 测试脚本，确认无失败。

第二个里程碑完成 OASIS 适配层实现。产物是 `src/adapters/oasis` 目录以及入口文件，能在 OASIS 模板工程中通过 BeginPlay 与 Tick 调用适配层，并能把 UI 回调转成动作。验证方式是运行新增的 Lua 模拟测试，并在编辑器里触发按钮观察日志与界面刷新。

第三个里程碑补齐说明与验证记录，更新 ExecPlan 中的 Progress、Surprises、Decision Log、Outcomes，保证计划自洽且可单独执行。

## Concrete Steps

在仓库根目录 `/Users/billyq/Dev/Github/Lua/monopoly` 下执行下列步骤。每一步完成后更新 `Progress`。

1) 完成共享适配核心抽取与 Eggy/Love2D 适配层改造。
   - 已按 `docs/plans/adapters-plan.md` 完成。

2) 新增 OASIS 适配层目录与运行时入口。
   - 新增 `src/adapters/oasis/oasis_runtime.lua`、`src/adapters/oasis/oasis_layer.lua`、`src/adapters/oasis/ui_state.lua`、`src/adapters/oasis/ui_bridge.lua`。
   - `oasis_runtime.lua` 提供 `install` 或 `on_begin_play`/`on_tick` 入口，并提供 `on_ui_event` 转换动作。
   - `ui_bridge.lua` 负责把 `set_label`、`set_button`、`set_visible`、`set_touch_enabled` 映射到 OASIS UMG Widget。

3) 增加 Lua 模拟测试验证适配层。
   - 新增 `tests/oasis_adapter_smoke.lua`，用 mock UI 桥接模拟 OASIS API。
   - 运行：

        lua tests/oasis_adapter_smoke.lua

   - 期望输出示例（节选）：

        [OasisAdapter] init ok
        [OasisAdapter] tick ok

4) 在 ExecPlan 中更新进度与结果，确保所有章节最新。

## Validation and Acceptance

必须验证两种路径。第一条是纯 Lua 模拟：运行 `lua tests/oasis_adapter_smoke.lua`，确认适配层能够创建游戏、处理一次 Tick、响应至少一个 UI 动作且无 Lua 报错。第二条是在编辑器内：在 OASIS 模板工程里从 `UGCGameState:ReceiveBeginPlay` 或 `UGCPlayerController:ReceiveBeginPlay` 调用 `oasis_runtime` 的入口，点击“下一回合/自动/重新开始”等按钮，观察 UI 文本刷新与日志输出中出现 `"[OasisAdapter]"` 前缀。若 UI 文本与回合数一致增长且无错误日志，则通过。

## Idempotence and Recovery

本计划的新增模块与测试可重复运行且不会破坏现有数据。若共享核心拆分失败或影响 Eggy 行为，可回滚到拆分前版本并改为在 Eggy 适配层内部保留原实现，再重新设计拆分点。若 OASIS UI API 与预期不一致，可先在 `ui_bridge.lua` 中做兼容判断并记录差异，保证 Lua 模拟测试仍可运行。

## Artifacts and Notes

建议在日志前缀中统一使用 `[OasisAdapter]`。示例动作映射片段如下（仅示意，实际以实现为准）：

    local actions = {
      ui_button = function(payload) return { type = "ui_button", id = payload.id } end,
      choice_select = function(payload) return { type = "choice_select", choice_id = payload.choice_id, option_id = payload.option_id } end,
      choice_cancel = function(payload) return { type = "choice_cancel", choice_id = payload.choice_id } end,
      ui_tile_select = function(payload) return { type = "ui_tile_select", index = payload.index } end,
      popup_confirm = function() return nil end,
    }

OASIS UI 需要提供的节点名称建议与 Eggy 保持一致，以减少差异：`panel_title`、`panel_turn`、`panel_current_name`、`btn_next`、`btn_auto`、`btn_restart`、`tile_1` 至 `tile_N`、`modal_choice`、`modal_popup` 等。

已验证的 Lua 模拟输出（节选）：

    lua tests/oasis_adapter_smoke.lua
    [OasisAdapter] init ok
    [OasisAdapter] tick ok

    lua tests/deps_check.lua
    Dependency self-check passed

    lua tests/regression.lua
    ..........
    All regression checks passed (26)

## Interfaces and Dependencies

共享适配核心建议定义在 `src/adapters/core`（如 `src/adapters/core/adapter_layer.lua`），暴露 `new(opts)`，其中 `opts` 至少包含 `game_factory` 与 `ui`。`ui` 必须实现以下方法：`set_label(name, text)`、`set_button(name, text)`、`set_visible(name, visible)`、`set_touch_enabled(name, enabled)`。共享适配核心应依赖 `src.adapters.love2d.auto_runner` 以保持自动运行逻辑一致。

OASIS 运行时入口建议定义在 `src/adapters/oasis/oasis_runtime.lua`，暴露：

    OasisRuntime.install(opts) -> layer
    OasisRuntime.on_begin_play()
    OasisRuntime.on_tick(delta_seconds)
    OasisRuntime.on_ui_event(payload)

其中 `on_ui_event` 接收 OASIS UI 回调参数并转成动作，动作结构与 `src/adapters/eggy/eggy_runtime.lua` 一致。OASIS UI 桥接建议定义在 `src/adapters/oasis/ui_bridge.lua`，内部依赖 OASIS 的 UMG Widget API（如 `GetWidgetFromName`、`SetText`、`SetVisibility`），如果 API 不存在则降级为空操作并在日志中说明。

## 变更记录

2026-01-20：文档迁移到 `docs/plans/oasis-plan.md` 并修正 ExecPlan 规范文件的引用路径，避免定位歧义。
2026-01-20：将共享核心抽取任务拆分为独立计划 `docs/plans/adapters-plan.md`，减少本计划的范围与风险。
2026-01-20：共享核心抽取计划已完成，更新 Progress 以进入 OASIS 适配层实现阶段。
2026-01-20：完成 OASIS 适配层与模拟测试，实现与验证细节写入 ExecPlan。

# samples_report 接入差距盘点与收敛计划（Eggitor 全量接入基线）

## Goal & Success Criteria

目标：把 `knowledge/samples_report.md` 提到的关键接入点，收敛成“Eggitor 内可稳定跑、可交互、可扩展”的完整接入基线。

完成标准（done when）：
- `lua tests/deps_check.lua` 通过。
- `lua tests/regression.lua` 通过（当前 29 项）。
- `lua tests/ui_nodes_audit.lua` 通过（目前失败，缺 78 项）。
- 在 Eggitor 中打开仓库根目录后：
  - 基础 UI 文本能刷新（标题、回合、当前玩家、日志）。
  - 按钮能驱动动作（下一回合 / 自动控制 / 重新开始）。
  - 黑市面板能显示并完成一次购买流程。
  - 玩家位置能随回合推进更新。

## Non-goals / Out of Scope

- 不在本计划内引入“动态焊接 / 无限世界 / 射线拼装”等玩法型能力。
- 不在本计划内重写规则层（`src/gameplay/*`）。
- 不追求一次性把所有 UI 做到美术最终形态，只追求“功能闭环 + 可验证”。

## Assumptions

- 以“可快速落地 + 后续好维护”为优先级。
- UI 资源允许在 Eggitor 侧调整或补节点。
- 棋盘锚点命名遵循 `t1..t45`（地图长度当前为 45）。
- 存档 key 需要新建一套不会撞车的命名空间（例如 `monopoly_*`）。

## Progress

- [x] (2026-01-27) 对照 `knowledge/samples_report.md` 与现状完成差距盘点。
- [x] (2026-01-27) 运行回归：`deps_check` / `regression` 均通过。
- [x] (2026-01-27) 运行 UI 审计：`ui_nodes_audit` 失败，缺 78 项。
- [ ] (待执行) 补齐“初始化 / UI 节点 / UI 事件 / 玩家映射 / 棋盘锚点 / 存档”六条主线闭环。
- [ ] (待执行) 在 Eggitor 内完成端到端验收并固化到测试脚本。

## Surprises & Discoveries

- UI 资源与代码的“逻辑名”严重不一致，且缺大量节点与事件。
  Evidence:
    lua tests/ui_nodes_audit.lua
    [ui-audit] missing logical nodes/events: 78
- `refs.lua` 已存在，但没有任何初始化把它接到 `G.refs`。
  Evidence: `G.refs` 仅出现在 `src/adapters/eggy/eggy_layer.lua`。
- 当前游戏创建默认 `auto_all = true`，会把所有玩家托管化，不适合真实接入。
  Evidence: `src/adapters/eggy/eggy_runtime.lua` 的 `create_game()`。

## Decision Log

- Decision: 以“测试收敛”为主线，先补接入骨架，再补 UI 资源。
  Rationale: 目前最大风险在 UI 与事件接线，必须用自动化审计兜底。
  Date/Author: 2026-01-27 / Codex
- Decision: 允许保留“逻辑名 -> 资源名”的映射层，但必须单点收敛并被审计脚本复用。
  Rationale: 能降低 UI 侧一次性改名压力，避免代码与审计分叉。
  Date/Author: 2026-01-27 / Codex

## Proposed Solution

核心思路：把“完整接入”拆成 6 条可验证闭环，并让每条都能被脚本或日志证明。

6 条闭环（按优先级）：
1) 初始化闭环（`GAME_INIT` 一次性把 `G` 与资源接好）。
2) UI 节点闭环（逻辑名 -> 资源名，且资源确实存在）。
3) UI 事件闭环（资源事件 -> 逻辑动作）。
4) 玩家映射闭环（真实 Role -> Game 玩家）。
5) 棋盘锚点闭环（`t1..t45` -> `tile_1..tile_45` -> 位置更新）。
6) 存档闭环（最小可用：读写 1~2 个关键字段）。

备选方案与取舍：
- 方案 A（推荐）：代码侧增加映射层 + UI 侧逐步补节点。
  - 优点：落地快、可回归、对 UI 侧压力小。
  - 缺点：需要维护映射表。
- 方案 B：UI 侧一次性全部改成逻辑名。
  - 优点：代码更干净。
  - 缺点：一次性风险高，且当前 UI 明显不完整。

## System Design

目标数据流（接入后应稳定为）：
- `EVENT.GAME_INIT`
  - 初始化 `G`（refs / tiles / roles / 映射表 / 调试开关）。
  - 安装 UIManager（`ui_data.lua`）。
  - 用真实 Role 构建 Game。
- `LuaAPI.set_tick_handler`
  - 驱动 `layer:tick(dt)`。
  - tick 内只做“状态 -> 视图 -> UI 写入”。
- `EVENT.UI_CUSTOM_EVENT`
  - 先过“事件映射层”，再变成统一 action。
  - action 统一走 `EggyLayer:dispatch_action`。

关键不变量：
- UI 写入允许“节点缺失时静默降级”，但必须有审计脚本兜底。
- UI 事件必须能通过统一 action 结构落到 `dispatch_action`。

## Interfaces & Data Contracts

建议新增/固化的契约：

- 全局容器（建议在初始化时保证存在）：
  - `G.refs`: `require("refs")`
  - `G.tiles`: `LuaAPI.query_units({"t1"...})`
  - `G.roles`: `GameAPI.get_all_valid_roles()`
  - `G.ui_name_map`: 逻辑名 -> 资源名
  - `G.ui_event_map`: 资源事件 -> 逻辑事件/动作

- UI 名称解析契约（建议抽到独立模块复用）：
  - `resolve_ui_name(logical_name) -> resource_name`
  - `resolve_ui_event(event_name, payload) -> normalized_event/payload`

- 玩家构建契约（从平台事实出发）：
  - 输入：`GameAPI.get_all_valid_roles()`
  - 输出：`players[]` 与 `ai[]`（可配置默认策略）

- 存档契约（最小可用）：
  - key 命名空间：`monopoly_*`
  - 读写位置：`GAME_INIT` 读、关键节点写（如回合结束 / 游戏结束）

## Execution Details

按顺序执行，且每步都能被验证：

1) 以审计脚本作为收敛锚点。
- 保持 `tests/ui_nodes_audit.lua` 作为 UI 接入完成标准。
- 目标是后续把它从红灯变绿灯。

2) 补初始化闭环（`G` 与资源接线）。
- 在 `src/adapters/eggy/eggy_runtime.lua` 的 `GAME_INIT` 回调中，先执行初始化步骤：
  - 若 `G` 不存在则创建。
  - `G.refs = require("refs")`。
  - 依据棋盘长度构造 `{"t1".."tN"}` 并 `LuaAPI.query_units(...)`，写入 `G.tiles`。
  - `G.roles = GameAPI.get_all_valid_roles()`。

3) 收敛 UI 名称映射为单一事实来源，并复用到审计脚本。
- 现状映射散落在 `src/adapters/eggy/ui_state.lua` 与 `tests/ui_nodes_audit.lua`。
- 需要把映射收敛到单点（建议 `src/adapters/eggy/ui_name_map.lua`），并让 `ui_state` 与审计脚本共同 `require`。
- 该收敛不会改变行为，只是减少漂移风险。

4) 补 UI 资源本体（当前最大缺口）。
- 证据：审计缺 78 项，且 `ui_data.lua` 中几乎没有逻辑名节点。
- 需要在 Eggitor 侧补齐或重命名以下类别节点，并重新导出 `ui_data.lua` / `refs.lua`：
  - 基础面板节点（`panel_*`）。
  - 选择/弹窗节点（`modal_*` / `choice_*` / `popup_*`）。
  - 棋盘文本节点（`tile_1..tile_45`）。
  - 关键按钮节点与事件（`btn_next` / `btn_auto` / `btn_restart`）。
- 每次 UI 改动后重新跑 `lua tests/ui_nodes_audit.lua`，直到通过。

5) 补 UI 事件闭环（事件映射层）。
- 现状：`EggyRuntime` 主要识别逻辑事件名（如 `ui_button`）。
- 实际 UI 事件名往往是“点击XX”。
- 做法：在 runtime 中引入事件映射表，把资源事件名翻译成统一 action（或统一逻辑事件名）。
- 黑市事件已在 `src/adapters/eggy/market_ui.lua` 有事实来源，可作为模板。

6) 补玩家映射闭环（真实 Role -> Game 玩家）。
- 现状：`create_game()` 默认 `auto_all = true`。
- 建议：
  - 用 `GameAPI.get_all_valid_roles()` 生成玩家名与人数。
  - 默认保留 1 个非 auto 的真实玩家，其余再按需要设为 AI/auto。

7) 补存档闭环（最小可用，不污染规则层）。
- 现状：规则层无存档接入。
- 做法：在 Eggy 适配层增加轻量存档桥接：
  - `GAME_INIT` 读取历史统计。
  - 在游戏结束或关键节点写回（使用 `Role.get_archive_by_type` / `set_archive_by_type`）。
- key 统一使用 `monopoly_*` 命名空间。

## Testing & Quality

测试锚点：

- 逻辑回归（现已可跑）：
  - `lua tests/deps_check.lua`
  - `lua tests/regression.lua`

- 接入回归（必须变绿）：
  - `lua tests/ui_nodes_audit.lua`

- Eggitor 端到端验收（人工观察）：
  - GAME_INIT 后 UI 有可见变化（至少标题/回合/玩家名）。
  - `next/auto/restart` 三个动作都可触发。
  - tile 选择与格子详情能联动。
  - 黑市能打开、能选、能确认/取消。

## Rollout, Observability, and Ops

- 渐进式接入：先稳住初始化与映射层，再推进 UI 资源补齐。
- 轻量可观测性：
  - 在 UI 事件入口增加一次性规范化日志（可开关）。
  - 关键节点缺失时打印一次性 warn，避免刷屏。
- 回滚策略：
  - 映射层与初始化层保持增量、可独立回退。
  - UI 资源改动以导出的 `ui_data.lua` / `refs.lua` 为回滚锚点。

## Risks & Mitigations

- 风险：UI 资源持续变动导致代码与资源漂移。
  - 缓解：所有名称映射收敛到单一模块，并让审计脚本复用它。
- 风险：事件名不可控或不可配置。
  - 缓解：在 runtime 做“事件翻译层”，不要把 UI 事件名散落到业务代码。
- 风险：真实玩家被 `auto_all` 覆盖。
  - 缓解：默认关闭 `auto_all`，只对 AI 玩家开启 auto。
- 风险：存档 key 撞车或污染其他系统。
  - 缓解：强制命名空间前缀（`monopoly_*`），并集中定义常量。

## Open Questions

- UI 资源侧最终是“全面改名到逻辑名”，还是“长期保留映射层”。
  - 解决方式：以 `ui_nodes_audit` 的通过成本为准做一次取舍；若 UI 侧改名成本低，就逐步去映射。
- UI 资源侧 `next/auto/restart/tile` 选择的事件名与 payload 结构是什么。
  - 解决方式：在 UI 侧确认事件名后，统一收敛到事件映射表，不直接写死在多处代码里。

## Outcomes & Retrospective

- 当前已确认：规则层稳定、Eggy 入口可运行，但“UI/事件/初始化/玩家/存档”仍是完整接入的主要缺口。
- 完成后应以 `ui_nodes_audit` 绿灯作为“UI 接入完成”的硬门槛。

## Artifacts and Notes

关键现状证据（可复现）：

    lua tests/deps_check.lua
    Dependency self-check passed

    lua tests/regression.lua
    .............................
    All regression checks passed (29)

    lua tests/ui_nodes_audit.lua
    [ui-audit] missing logical nodes/events: 78

变更记录（每次更新本计划都需要追加）：
- 2026-01-27：首版计划，基于 `knowledge/samples_report.md` 与当前代码/测试状态完成差距盘点与收敛路径设计。

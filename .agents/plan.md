# Plan: 修复 `src/game` 的 `projection_cycles`

## Summary

目标是让真实仓库的 `arch_view` 结果里不再出现 `game` 和 `game.systems` 两个 `projection_cycles` 视图，且不改变现有回合推进、AI 自动操作、道具确认、市场确认等外部行为。

当前必须处理的 5 组回折是：

- `game`: `flow <-> scheduler`
- `game`: `core.runtime <-> game.runtime`
- `game`: `runtime -> core.ai`（`auto_play_port_adapter -> agent`）
- `game.systems`: `items <-> land`
- `game.systems`: `land <-> market`

本次不追求“全仓库 projection cycle 为零”；`presentation` 子树不在验收范围内。

## Interfaces / Structural Changes

- `src/game/scheduler/session.lua` 增加 script factory 注入位；`scheduler` 不再直接绑定 flow 的 turn script / await。
- `src/game/core/ai/agent.lua` 拆成内核可复用策略模块与 runtime adapter 组合层，避免 `game.runtime` 反向依赖 `game.core.ai` 聚合节点。
- 新增外层 gameplay port installer，统一供 app bootstrap、gameplay loop、test support 安装默认 `auto_play_port` / `bankruptcy_port`。
- 新增中性 choice helper：建议 `src/game/systems/choices/use_skip_choice.lua`。
- 新增中性查询 helper：
  - `src/game/systems/board/query.lua`
  - `src/game/systems/board/property_query.lua`
  - `src/game/systems/commerce/property_value.lua`
  - 如有必要，`src/game/systems/items/target_query.lua`
- 新增 market 子系统自有 landing effect executor，替代 `land/effects/market.lua -> market` 直连。

## Dependency Graph

```text
T1 ──┐
T2 ──┼──┐
T3 ──┤  │
T4 ──┤  ├── T7 ── T8
T5 ──┤  │
T6 ──┘  │
        └────
```

## Tasks

### T1: 让 `scheduler` 退回纯调度层
- **depends_on**: []
- **location**: `src/game/scheduler/`, `src/game/flow/turn/`, `tests/suites/gameplay/gameplay_coroutine.lua`
- **description**: 把 `src/game/scheduler/turn_script.lua`、`src/game/scheduler/await.lua` 的 flow-specific 状态机逻辑迁到 `src/game/flow/turn/`；`scheduler` 只保留 signal queue、resume、wait-state 存储、snapshot 容器；`flow.turn.engine` 通过 session/script factory 注入 turn script。
- **validation**: `src/game/scheduler/*` 不再 `require("src.game.flow...")`；`session:snapshot()`、`game.turn.phase`、`choice_elapsed_seconds`、各 wait state 行为保持不变；`game` 视图不再出现 `flow <-> scheduler` feedback edge。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T2: 把默认 gameplay port 装配移出 `core.runtime`
- **depends_on**: []
- **location**: `src/game/core/runtime/`, `src/game/runtime/`, `src/app/bootstrap/`, `src/game/flow/turn/loop.lua`, `tests/support/shared_support.lua`, `tests/guards/dep_rules.lua`
- **description**: 从 `composition_root` 移除对 runtime adapter 的直接依赖；新增外层 installer/helper 负责给 game 安装默认 `auto_play_port`、`bankruptcy_port`；同步更新 app 启动、gameplay loop、test support 的装配入口；同一批次删除 `dep_rules` 里与旧装配路径绑定的例外/期望。
- **validation**: `src.game.core.runtime.*` 不再依赖 `src.game.runtime.*`；`support.new_game()`、runtime 启动、`gameplay_loop.new_game()`、无 UI guard 场景都能拿到默认 port；旧 whitelist/例外已同步清理。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T3: 解开 `runtime -> core.ai`
- **depends_on**: []
- **location**: `src/game/runtime/auto_play_port_adapter.lua`, `src/game/core/ai/`, `src/app/bootstrap/runtime/init.lua`, affected tests
- **description**: 拆分 AI 逻辑归属，避免 `src/game/runtime/auto_play_port_adapter.lua` 直接依赖 `src/game/core/ai/agent.lua`。固定方案是把纯策略实现下沉到中性/外层可复用模块，由 runtime adapter 依赖中性实现，`core.ai` 不再成为 `game` 顶层反馈边目标；同步更新直接 `require agent` 的测试入口。
- **validation**: 自动玩家识别、远程骰子、偷窃/路障/目标选择、自动 choice action 行为不变；`game` 视图不再出现 `runtime -> core` 反馈边。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T4: 提取通用 secondary-confirm choice builder
- **depends_on**: []
- **location**: `src/game/systems/choices/`, `src/game/systems/land/choice_specs.lua`, `src/game/systems/items/steal.lua`, `src/game/systems/market/application/purchase_policy.lua`
- **description**: 把 `build_use_skip` 从 `land/choice_specs.lua` 提取到中性 helper；`land/choice_specs.lua` 只保留 `rent_prompt`、`tax_prompt` 等 land 专属 API；steal 与 market 改用新 helper。
- **validation**: `steal_prompt`、`rent_card_prompt`、`tax_card_prompt`、`market_vehicle_replace` 继续显式输出 `owner_role_id`、`route_key`、`requires_confirm`、`allow_cancel`、`confirm_title`、`confirm_body`；`market` 不再依赖 `land.choice_specs`。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T5: 把 market 落地 effect 归还给 market 子系统
- **depends_on**: [T4]
- **location**: `src/game/systems/land/effects/market.lua`, `src/game/systems/market/`, `src/game/core/runtime/bootstrap.lua`
- **description**: 删除 `land/effects/market.lua -> market` 的直接依赖；由 market 子系统提供自己的 landing effect executor，并在 bootstrap 注册；land 侧不再感知 market service。
- **validation**: 进入 market 地块后的 choice/intention、等待态、自动流程保持一致；`land` 不再直接依赖 `market`。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T6: 提取中性 board/property 查询，切断 `items -> land`
- **depends_on**: []
- **location**: `src/game/systems/board/`, `src/game/systems/commerce/`, `src/game/systems/land/`, `src/game/systems/items/`
- **description**: 拆掉 `items` 对 `land/board_utils.lua` 和 `land/rent_resolver.lua` 的读取：
  - `queue_walk`、`indices_in_range` 挪到 `src/game/systems/board/query.lua`
  - 投资额/地产价值计算挪到 `src/game/systems/commerce/property_value.lua`，不要只是新模块继续依赖 `land/pricing.lua`
  - owner/rent-owner 只读查询挪到 `src/game/systems/board/property_query.lua`
  - 如 `find_best_tile` 只服务道具 targeting，则落到 `src/game/systems/items/target_query.lua`
  - 明确迁走 `src/game/systems/items/strategy.lua -> src/game/systems/land/rent_resolver.lua`
- **validation**: `items` 不再直接依赖 `land.board_utils` 或 `land.rent_resolver`；怪兽/导弹目标、强征/免费卡判定、清障/偷窃相关行为不变；`game.systems` 视图不再出现 `items -> land` feedback edge。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T7: 收口护栏、仓库级断言与文档
- **depends_on**: [T1, T2, T3, T5, T6]
- **location**: `scripts/arch/config.lua`, `tests/guards/dep_rules.lua`, `tests/suites/architecture/arch_view_contract.lua`, `docs/architecture/`
- **description**: 新增并收口硬边界，至少覆盖：
  - `src.game.scheduler.*` 不能依赖 `src.game.flow.*`
  - `src.game.core.runtime.*` 不能依赖 `src.game.runtime.*`
  - `src.game.systems.market.*` 不能依赖 `src.game.systems.land.choice_specs`
  - `src.game.systems.items.*` 不能依赖 `src.game.systems.land.board_utils`
  - `src.game.systems.items.*` 不能依赖 `src.game.systems.land.rent_resolver`
  同时在 `arch_view_contract` 中直接分析真实仓库，断言 `projection_cycles` 不再包含 `game`、`game.systems`；同步文档到新归属。
- **validation**: repo 级 architecture suite 明确检查 `projection_cycles` 范围；guard 与文档同步反映新边界，没有残留旧 whitelist。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T8: 回归验证
- **depends_on**: [T7]
- **location**: repo root
- **description**: 运行架构、guard、contract、回归命令，确认 `src/game` 子树 projection cycle 清零且无行为回归。
- **validation**:
  - `lua scripts/arch.lua check`
  - `lua tests/guard.lua`
  - `lua tests/contract.lua`
  - `MONO_REGRESSION_MODE=release_trimmed lua tests/regression.lua`
  - 验收标准：真实仓库 `projection_cycles` 不含 `game`、`game.systems`；不要求清掉 `presentation.runtime`；协程等待态、AI 自动操作、偷窃提示、租金/免税提示、市场换车确认均保持原行为。
- **status**: Not Completed
- **log**:
- **files edited/created**:

## Parallel Execution Groups

| Wave | Tasks | Can Start When |
|------|-------|----------------|
| 1 | T1, T2, T3, T4, T6 | Immediately |
| 2 | T5 | T4 complete |
| 3 | T7 | T1, T2, T3, T5, T6 complete |
| 4 | T8 | T7 complete |

## Test Plan

- 协程链路：`tests/suites/gameplay/gameplay_coroutine.lua` 覆盖 `wait_choice`、`wait_move_anim`、`wait_action_anim`、`wait_landing_visual`、完整生命周期。
- AI 链路：保留自动玩家识别、自动目标选择、自动 choice 行为的现有 domain/gameplay 覆盖。
- Choice 语义：`tests/suites/gameplay/gameplay_items_startup.lua`、`tests/suites/domain/item.lua`、`tests/suites/domain/market.lua`、presentation choice suites 保证 confirm/prompt 字段不漂移。
- 装配链路：`tests/support/shared_support.lua`、`tests/guards/gameplay_loop_no_ui.lua`、runtime/narrow port suites 验证默认 port 安装仍完整。
- 架构链路：`tests/suites/architecture/arch_view_contract.lua` 直接断言真实仓库 `projection_cycles` 不含 `game`、`game.systems`。

## Assumptions

- 本次只修 `src/game` 子树的 `projection_cycles`，不扩大到全仓库。
- 允许新增中性 helper 和 installer，但不改玩家可见文案与交互语义。
- 当前仍在 Plan Mode，所以此回合只交付决策完整的执行计划；实现时再落盘为 `projection-cycles-plan.md`。

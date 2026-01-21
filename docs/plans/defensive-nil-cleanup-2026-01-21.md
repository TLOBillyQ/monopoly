# 清理src过度判空的ExecPlan

这是一个活文档。`Progress`、`Surprises & Discoveries`、`Decision Log`、`Outcomes & Retrospective` 必须随着执行持续更新。

本计划遵循仓库根目录的 `./.agent/PLANS.md`，后续实现必须按该文件要求维护本ExecPlan。

## Purpose / Big Picture

本次调整的目标是清理 `src/` 目录中“过于保守的防御判空”，也就是用 `a and b or c` 这种三元写法绕过潜在空值的代码。我们希望在数据不符合约定时尽早崩溃，避免默默吞掉错误，同时减少运行时分支和复杂度。完成后，正常输入路径的行为保持不变，但当核心数据缺失时会直接暴露问题。

## Progress

- [x] (2026-01-21 16:36:01+08:00) 创建ExecPlan并完成仓库现状梳理。
- [x] (2026-01-21 16:39:07+08:00) 将清理范围扩展到 `src/` 全目录并更新计划。
- [x] (2026-01-21 17:38:37+08:00) 在 `src/` 全目录核对数据约定，确认哪些字段保证存在、允许删除判空。
- [x] (2026-01-21 17:38:37+08:00) 按约定清理防御判空并精简三元表达式（已完成：`src/adapters/eggy/`、`src/adapters/oasis/`、`src/adapters/love2d/`、`src/adapters/core/`、`src/core/board.lua`、`src/game.lua`、`src/gameplay/board_factory.lua`、`src/gameplay/turn_start.lua`、`src/gameplay/turn_manager.lua`、`src/gameplay/turn_land.lua`、`src/gameplay/agent.lua`、`src/gameplay/movement_service.lua`、`src/gameplay/bankruptcy_service.lua`、`src/gameplay/land_pricing.lua`、`src/gameplay/item_phase.lua`、`src/gameplay/item_post_effects.lua`、`src/gameplay/item_executor.lua`、`src/gameplay/item_inventory.lua`、`src/gameplay/item_demolish.lua`、`src/gameplay/item_strategy.lua`、`src/gameplay/choice_service.lua`、`src/gameplay/choice_handlers/item_choice_handler.lua`、`src/gameplay/choice_handlers/market_choice_handler.lua`、`src/gameplay/choice_handlers/land_choice_handler.lua`、`src/gameplay/choice_handlers/optional_effect_handler.lua`、`src/gameplay/market_service.lua`、`src/gameplay/player_vehicle.lua`、`src/gameplay/effect_pipeline.lua`、`src/gameplay/effect.lua`、`src/gameplay/composition_root.lua`、`src/gameplay/chance.lua`、`src/adapters/eggy/ui_state.lua`、`src/adapters/oasis/ui_bridge.lua`、`src/adapters/oasis/oasis_layer.lua`、`src/adapters/eggy/eggy_layer.lua`、`src/adapters/love2d/panel_renderer.lua`、`src/gameplay/item_roadblock.lua`）。
- [x] (2026-01-21 17:38:37+08:00) 跑依赖检查与回归脚本，确认行为在正常输入下不变（已完成：`lua tests/deps_check.lua`、`lua tests/regression.lua`）。

## Surprises & Discoveries

- Observation: 仍有 `and/or` 形式存在于非防御判空路径（逻辑判断、短路条件、外部UI桥接）。
  Evidence: `rg -n "and .* or" src` 的剩余命中包含 `src/gameplay/turn_manager.lua`、`src/gameplay/choice_service.lua`、`src/adapters/oasis/ui_bridge.lua` 等场景的条件表达式。

## Decision Log

- Decision: 将清理范围扩展到 `src/` 全目录，覆盖适配层、玩法与工具模块。
  Rationale: 用户明确要求扩展范围，且核心目标是统一减少过度防御判空，需在全局一致执行。
  Date/Author: 2026-01-21 / Codex
- Decision: 将棋盘覆盖物默认值下移至 `src/gameplay/board_factory.lua`，让 `src/core/board.lua` 只接收完整输入。
  Rationale: 保持 `Board.new` 的输入严格，避免在核心对象中继续兜底空数据。
  Date/Author: 2026-01-21 / Codex
- Decision: 停止清理剩余 `and/or` 命中项，视为业务逻辑或必要短路表达式。
  Rationale: 这些表达式不属于“过度防御判空”，强行替换会降低可读性或改变语义。
  Date/Author: 2026-01-21 / Codex

## Outcomes & Retrospective

已完成 `src/` 目录过度判空清理，并通过依赖检查与回归测试。仍保留少量 `and/or` 形式的逻辑判断表达式作为非防御判空用法。后续若确需统一风格，可逐条改写为 `if`，但需评估可读性与语义风险。

## Context and Orientation

本仓库的运行代码位于 `src/`，覆盖核心玩法、规则、工具与平台适配层。本次任务是全 `src/` 目录清理过度防御判空。这里的“防御判空”指用 `and/or` 组合来绕开潜在 `nil`，例如 `a and a.b or "-"`，而“过于保守”指这些字段根据运行约定应该必然存在。游戏数据常见来源包括 `game` 实例、`game.store.state` 的状态快照，以及玩法模块内部生成的上下文对象。

关键文件包括但不限于：
`src/adapters/` 中的运行时与UI桥接逻辑；
`src/gameplay/` 下的行动与回合逻辑会使用大量 `and/or` 的防御判空；
`src/core/` 定义棋盘、玩家等核心对象；
`src/util/` 中的工具函数可能存在类似兜底逻辑。

## Plan of Work

先用 `rg` 在 `src/` 全目录定位 `and/or` 的防御判空写法，重点关注对核心状态对象、玩家数据、棋盘数据、回合上下文以及各类配置的层层兜底。再回溯调用路径，确认这些字段在正常运行时的必然性。确认后，移除兜底逻辑，改为直接索引或更清晰的 `if` 语句，避免嵌套三元表达式。

具体修改建议如下：在 `src/gameplay/`、`src/util/`、`src/adapters/`、`src/core/` 的各类模块中，按同样原则处理：只要数据在调用约定中必然存在，就删掉 `and/or` 的兜底；真正允许为空的字段则保留清晰的 `if` 分支，禁止嵌套三元表达式。对外部宿主API或运行时可选注入对象（例如外部UI桥接层、可选服务）保留必要的判空保护，避免与运行环境差异冲突。

清理后必须再次通读受影响函数，删除因为兜底逻辑消失而变成多余的临时变量或分支，保持代码直白且无嵌套三元表达式。

## Concrete Steps

在仓库根目录运行 `rg -n "and .* or" src` 定位候选代码，逐段确认哪些字段具备“必然存在”的数据约定。按上述范围修改文件并保存。修改完成后执行 `lua tests/deps_check.lua` 和 `lua tests/regression.lua`，并观察两条命令均正常结束。若需要直观验证运行时行为，可执行 `run_all_ai.bat` 并确认日志无异常中断。

## Validation and Acceptance

在正常游戏运行路径下，界面显示、自动运行与选择流程的日志输出应与修改前一致，玩法流程无异常中断。`lua tests/deps_check.lua` 与 `lua tests/regression.lua` 均应返回成功。为了证明“更早崩溃”的目标达成，可在调试环境中手动将 `game.store.state` 或关键玩法上下文字段置空并执行相关路径，应该触发明确的Lua错误而不是返回空值；该操作仅用于验证，不应提交到代码库。

## Idempotence and Recovery

本次修改只删除兜底逻辑与冗余分支，不引入新的状态或数据文件，多次重复执行不会产生额外副作用。如需回滚，可通过版本控制还原对应文件到变更前状态。

## Artifacts and Notes

暂无。执行时可在此处补充 `rg` 输出或关键片段的前后对比摘录。

## Interfaces and Dependencies

不新增接口或模块，只调整既有函数内部实现。涉及范围覆盖 `src/` 内使用防御判空的函数，例如各适配层的视图构建、`src/gameplay/` 的回合和道具逻辑、`src/core/` 的数据模型访问、以及工具模块的包装函数。对外调用方式与返回结构保持不变，变化仅限内部对字段的取值方式更直接。

Note: 2026-01-21 扩展清理范围到 `src/` 全目录，以响应用户范围调整并保持执行口径一致。
Note: 2026-01-21 移除蛋仔适配层的特定描述，改为纯 `src/` 清理任务，以符合最新需求。

# 棋子位置同步与移动动画冲突消解计划


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。本计划遵循 `.agent/PLANS.md`。


## 目的 / 全局视角


解决 Eggy 侧棋子移动动画与棋盘刷新之间的“位置抢写”冲突，让玩家移动时保持连贯动画，动画结束后棋子能稳定落在正确格子，同时降低每帧轮询刷新的频率与成本。可见效果是：移动动画不会被强行拉回格点，回合结束或动画结束时位置仍正确；在自动回合或高频刷新场景中，棋子位置不抖动、不漂移。


## 进度


- [x] (2026-01-28 13:41Z) 计划初版：完成现状梳理与方案草案
- [x] (2026-01-28 13:41Z) 原型验证：确认冲突触发条件与最小规避策略（以 `turn.phase` 与 `turn.move_anim` 作为动画期判据）
- [x] (2026-01-28 13:41Z) 实现与验证：完成改动并跑测试（手工验收待完成）


## 意外与发现


- 观察：移动服务会立即更新 `player.position`，而 `refresh_board` 每次刷新都会把单位位置直接写回格点，因此在 `wait_move_anim` 阶段可能覆盖动画移动。
  证据：`src/gameplay/movement_service.lua` 中 `game:update_player_position` 与 `src/adapters/eggy/eggy_layer_board.lua` 中 `unit.set_position`。
- 观察：仅单向比对位置快照会漏掉玩家移除或回合裁剪的情况，因此需要双向比对快照与上一次缓存。
  证据：实现中对 `snapshot` 与 `board_last_positions` 做了双向遍历判定变更。


## 决策日志


- 决策：用回合 `phase == "wait_move_anim"` 与 `turn.move_anim` 作为“动画进行中”的判断，移动中的玩家位置刷新改为暂缓，动画结束后再强制同步一次。
  理由：这是当前数据流里最稳定、无需引入新依赖的判断点，且与 `AdapterLayer.step_move_anim` 的执行时机一致。
  日期/作者：2026-01-28 / Codex

- 决策：保留 `EggyLayerBoard.refresh_board` 现有签名，通过新增少量状态字段与差异检测来降低位置刷新频率。
  理由：最小改动、避免新增抽象层，符合当前 CodingDiscipline 的“单一实现”与“克制简化”要求。
  日期/作者：2026-01-28 / Codex

- 决策：动画期间暂停所有玩家的坐标同步，动画结束后强制同步一次。
  理由：避免移动玩家与同格玩家因占位计算被强行错位，优先保证动画流畅与落点一致。
  日期/作者：2026-01-28 / Codex


## 结果与复盘


已完成 Eggy 棋盘位置同步的“暂停/恢复”与快照差异检测，减少动画期间的抢写冲突，并降低每帧重复写入。自动化测试已通过，手工验收仍需在 Eggitor 或 Demo 中确认动画过程是否连贯、多人同格是否稳定错位。后续若发现位置信息仍有抖动，可进一步细化为“只暂停移动玩家”的策略，但当前实现以稳定为优先。


## 背景与导读


本仓库 Eggy 入口为 `main.lua`，运行时入口在 `src/adapters/eggy/eggy_runtime.lua`，每帧由 `EggyLayer:tick` 触发刷新。`EggyLayer:refresh_view` 会调用 `EggyLayerBoard.refresh_board`，后者根据 `view.state.players` 的位置，把玩家单位的坐标直接对齐到棋盘格点（`unit.set_position`）。这是一种“轮询刷新”，即每帧都写入位置。  
移动动画由 `src/adapters/eggy/move_anim.lua` 驱动，`AdapterLayer.step_move_anim` 在 `turn.phase == "wait_move_anim"` 时调用，实际运动依赖 `unit.start_move_by_direction`。但 `src/gameplay/movement_service.lua` 在计算路径时会立即更新 `player.position`，导致 `refresh_board` 在动画期间不断把棋子拉回目标格点，从而产生“动画被覆盖/跳跃”的冲突。

相关关键文件：
`src/adapters/eggy/eggy_layer.lua`、`src/adapters/eggy/eggy_layer_board.lua`、`src/adapters/eggy/move_anim.lua`、`src/adapters/core/adapter_layer.lua`、`src/gameplay/turn_move.lua`、`src/gameplay/turn_manager.lua`、`src/gameplay/movement_service.lua`。


## 里程碑


里程碑一（原型验证）：确认 `wait_move_anim` 阶段的刷新确实会覆盖动画，确定最小拦截条件与同步时机。完成后能在日志或目视观察到“动画期间不再被拉回”，并有明确的触发判据（例如 `turn.phase` 与 `turn.move_anim`）。

里程碑二（实现与验证）：引入位置同步的“暂停/恢复”与“差异检测”机制，降低轮询写入频率，并通过测试与手工观察证明动画连贯、回合结束位置准确。


## 工作计划


先在 `EggyLayerBoard.refresh_board` 内部引入“是否允许写入位置”的判断：当 `turn.phase == "wait_move_anim"` 且存在 `turn.move_anim` 时，暂缓对移动玩家（或全部玩家）的 `set_position`，并记录一次“待同步”的标记。动画结束后再触发一次强制同步，确保最终位置对齐。  
为降低轮询刷新，增加简单的差异检测：在 `layer` 上缓存上一轮玩家位置快照（例如 `player.id -> position` 与 `eliminated`），当快照未变且没有强制同步需求时，不写入坐标。这样每帧仍能快速判定，但只有在变化时才触发位置更新。  
在 `EggyLayer:tick` 中追踪 `turn.phase` 变化，用于识别“刚离开 wait_move_anim 的时刻”，把“待同步”标记设为 true，确保动画结束后的第一帧会执行一次对齐。  
全程保持 `EggyLayerBoard.refresh_board(layer, view, log_once, build_log_prefix)` 的签名不变，不新增跨文件接口；新增状态字段只挂在 `EggyLayer` 实例上。


## 具体步骤


在仓库根目录梳理当前调用链与数据：
  rg -n "refresh_board|wait_move_anim|move_anim" src/adapters src/gameplay
  已执行，输出确认 `eggy_layer.lua` 与 `eggy_layer_board.lua` 的刷新与动画交互点。

修改 `src/adapters/eggy/eggy_layer.lua`，在 `EggyLayer.new` 初始化新增状态字段（例如 `board_sync_pending`、`board_last_positions`、`board_last_phase`），并在 `tick` 中读取 `turn.phase` 变化，必要时置 `board_sync_pending = true`。确保刷新顺序仍是 `step_move_anim` -> `refresh_view`。

修改 `src/adapters/eggy/eggy_layer_board.lua`，在写入坐标前判断是否允许同步：
  - 若 `turn.phase == "wait_move_anim"` 且 `turn.move_anim` 存在，跳过位置写入，并保留同步标记。
  - 计算玩家位置快照，只有快照发生变化或 `board_sync_pending` 为 true 时才写入坐标，并在写完后清理标记与快照。

保持所有逻辑只作用于当前位置同步，不影响格点锚点初始化、玩家单位映射与楼房特效。

运行测试（在仓库根目录）：
  lua .github/tests/deps_check.lua
  预期：Dependency self-check passed
  lua .github/tests/regression.lua
  预期：All regression checks passed (30)

手工验收：在 Eggitor 或 Demo 中触发移动动画，观察移动过程不被拉回；动画结束后棋子落在目标格子；多人同格时仍能正确错位显示。


## 验证与验收


自动化验证：执行 `lua .github/tests/deps_check.lua` 与 `lua .github/tests/regression.lua`，预期输出包含依赖检查与回归测试通过信息。  
手工验证：启动 Eggy 运行入口（Eggitor 打开仓库根目录，入口为 `main.lua`），点“下一回合”触发移动，观察移动过程连续、无瞬移；移动结束后棋子位置与数值日志一致；连续多回合自动播放下不出现棋子抖动或错位。


## 可重复性与恢复


本改动仅涉及 Lua 代码与状态字段，重复运行不会产生数据迁移。若出现异常，可通过回退 `src/adapters/eggy/eggy_layer.lua` 与 `src/adapters/eggy/eggy_layer_board.lua` 恢复。必要时可临时关闭“暂停同步”逻辑，让 `refresh_board` 回到全量刷新模式以验证问题是否来自新逻辑。


## 产物与备注


修改文件：
`src/adapters/eggy/eggy_layer.lua`  
`src/adapters/eggy/eggy_layer_board.lua`

关键行为示例（缩进片段，仅作说明）：
  local phase = store:get({ "turn", "phase" })
  local anim = store:get({ "turn", "move_anim" })
  local suppress = phase == "wait_move_anim" and anim ~= nil
  if suppress then
    layer.board_sync_pending = true
    return
  end

测试输出片段（缩进示例）：
  Dependency self-check passed
  ..............................
  All regression checks passed (30)


## 接口与依赖


保持现有对外接口不变：
`EggyLayerBoard.refresh_board(layer, view, log_once, build_log_prefix)`  
`EggyLayer:refresh_board(view)`

新增/使用的内部状态字段（挂在 `EggyLayer` 实例上）：
`board_last_positions`（玩家位置快照）  
`board_sync_pending`（动画结束后的强制同步标记）  
`board_last_phase`（用于检测 `turn.phase` 变化）

依赖的数据源：
`layer.game.store:get({ "turn", "phase" })`  
`layer.game.store:get({ "turn", "move_anim" })`

变更说明：更新进度为已完成，实现动画期暂停同步与快照差异检测，并补充测试结果，确保计划可独立复现与验证。

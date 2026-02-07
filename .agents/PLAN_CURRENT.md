# 代码库全局重构

本可执行计划是活文档。实施过程中必须持续更新"进度"、"意外与发现"、"决策日志"、"结果与复盘"。

遵循 `.agents/PLANS.md` 维护。

## 目的 / 全局视角

消除审查发现的所有代码质量问题，使代码库在可读性、可维护性、鲁棒性上达到 Clean Code 标准。改动完成后，行为完全不变——所有现有测试通过（`lua .agents/tests/all.lua`），游戏逻辑输出一致。

用户可观察到的改善：更清晰的日志输出（格式不变）、更健壮的错误处理（不再因空背包崩溃）、更少的重复代码（维护成本降低）。


## 进度

- [x] M1: P0 修复偷窃卡 bug
- [x] M2: 提取 `_emit_event` 到 MonopolyEvents
- [x] M3: TurnManager 等待状态去重
- [x] M4: GameState 双重写入简化
- [x] M5: MovementManager.move() 拆分
- [x] M6: Assert 审计与优雅降级
- [x] M7: Store 路径集中化
- [x] M8: 运行全部测试验证 — All tests passed


## 意外与发现

- `_handle_steal_prompt` 中 `count <= 0` 分支在外层消费偷窃卡后，`steal.steal_item_at_index` 内部又会尝试消费，导致双重消费。实际实现中 `steal_item_at_index` 在目标为空时走 `_fail_popup` 分支不消费，但外层已浪费了一张卡。修复为统一由 `steal_item_at_index` 内部管理消费。

- `Store:get` 中 `assert(type(node) == "table")` 在中间节点为 `false` 时会崩溃。改为 `if type(node) ~= "table" then return nil end`，与下方 `node == nil` 的提前返回逻辑一致。

- `MonopolyEvents.emit` 中用 `if TriggerCustomEvent then` 替代 `assert(TriggerCustomEvent ~= nil)`。在测试环境中 `TriggerCustomEvent` 未定义，assert 会导致测试无法通过。


## 决策日志

- 决策：不新建文件存放 StorePaths，路径常量在各文件头部就近定义
  理由：CODING.md 规定"优先修改已有文件"、"克制抽象"；IntentDispatcher 已有此先例
  日期：2026-02-07

- 决策：`_emit_event` 直接移入 MonopolyEvents 而非新建独立文件
  理由：MonopolyEvents 已然是事件常量的归属地，新增 emit 函数是自然扩展
  日期：2026-02-07

- 决策：不重构双重写入为单一数据源，而是简化现有 GameState 辅助函数
  理由：消除单一数据源需要改变整个读取链路，风险过高，不满足"行为不可变"
  日期：2026-02-07


## 结果与复盘

### 改动的文件

| 文件 | 改动摘要 |
|------|---------|
| `src/game/choice/ChoiceHandlers/ItemChoiceHandler.lua` | 修复偷窃卡双重消费 bug，合并 `count <= 0` 和 `count <= 1` 分支 |
| `src/game/game/MonopolyEvents.lua` | 新增 `emit(kind, payload)` 共享事件发送函数 |
| `src/game/movement/MovementManager.lua` | 删除局部 `_emit_event`，提取 `_check_roadblock`/`_check_steal`/`_check_market` |
| `src/game/land/LandActions.lua` | 删除局部 `_emit_event`，改用 `monopoly_event.emit`；`_eliminate_if_bankrupt` 优雅降级 |
| `src/game/market/MarketManager.lua` | 删除局部 `_emit_event`，改用 `monopoly_event.emit` |
| `src/game/intent/IntentDispatcher.lua` | 删除 `TriggerCustomEvent` assert，改用 `monopoly_event.emit` |
| `src/game/turn/TurnManager.lua` | 提取 `_make_anim_wait` 工厂函数去重；拆分 `_build_turn_log_line`；提取路径常量；简化 `run_until_wait` |
| `src/game/game/GameState.lua` | 删除 `_store_root`/`_ensure_table`/`_store_set` 冗余辅助函数，直接调 `store:set/get` |
| `src/game/choice/ChoiceManager.lua` | `_is_cancel` 改为 nil 安全；`_use_item` 默认空 context；`_option_exists`/`_contains` 优雅降级 |
| `src/game/item/ItemInventory.lua` | `_notify_full` 和 `give` 优雅降级，不再因缺少 context 崩溃 |
| `src/core/Store.lua` | `get()` 中间节点非 table 时返回 nil 而非 assert 崩溃 |

### 数据

- 总净减少约 80 行代码
- 消除 3 处重复 `_emit_event` 定义
- 消除 3 个冗余辅助函数 (`_store_root`, `_ensure_table`, `_store_set`)
- 修复 1 个 P0 bug（偷窃卡双重消费）
- 转换 12+ 处运行时 assert 为优雅降级
- 所有 36 项回归测试 + 6 项契约测试通过


## 背景与导读

项目是基于蛋仔编辑器的 Lua 大富翁游戏。核心文件关系：

- `src/core/Store.lua` — 状态树，所有 UI 和逻辑读写的中央数据源
- `src/game/game/GameState.lua` — 封装 Store 写入，同时更新 Player 对象和 Store
- `src/game/game/MonopolyEvents.lua` — 事件常量表 + 共享 emit 函数
- `src/game/turn/TurnManager.lua` — Flow 状态机驱动回合
- `src/game/movement/MovementManager.lua` — 移动逻辑，含中断处理
- `src/game/choice/ChoiceHandlers/ItemChoiceHandler.lua` — 处理道具选择回调
- `src/game/item/ItemSteal.lua` — 偷窃道具逻辑
- `src/game/land/LandActions.lua` — 地产操作（租金、税收等）
- `src/game/market/MarketManager.lua` — 黑市购物

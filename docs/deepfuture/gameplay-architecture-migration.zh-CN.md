# Gameplay 架构迁移指南（Deep Future → 大富翁新项目）

> 目标：把 Deep Future 的 gameplay 架构提炼成一套可复用的工程规范，用于“大富翁”新项目的规则层/数据层/同步层的设计与实现。

## 1. 迁移目标与约束

### 1.1 目标（必须满足）

- **规则与渲染解耦**：规则层不依赖 UI 状态；UI 只读模型或接收同步命令。
- **可存档/读档**：任意时刻能保存；读档后能完整恢复（包含随机性状态）。
- **可复现**：同 seed + 同输入序列 => 同结果（便于测试、回放、排错）。
- **阶段化流程**：回合/阶段可插拔，逻辑可扩展（加扩展包/规则变体）。

### 1.2 非目标（刻意不做）

- 不把 UI 动画框架强行抽象成通用引擎。
- 不追求“完全纯函数”——允许规则层有命令式更新，但必须集中在 Store。

---

## 2. Deep Future 可复用的“架构四件套”

这四个模式是迁移的核心：

1. **协程状态机驱动流程**：把“阶段逻辑”与“等待动画/交互”统一。
   - 参考：`core/flow.lua`
2. **集中式 Store（持久化数据）**：所有可存档状态都在一个 Store 中分域管理。
   - 参考：`gameplay/persist.lua`
3. **同步层（Model → View）**：读档/回放时统一执行 `sync_all()` 对齐 UI。
   - 参考：`gameplay/sync.lua`
4. **效果容器（可用动作扫描与选择）**：把“可执行效果”抽象为统一的选择/执行框架。
   - 参考：`gameplay/effect.lua`

---

## 3. 大富翁项目推荐的模块边界（目录结构）

> 建议规则层与表现层分离；保持 gameplay 只依赖 core，不反向依赖 visual。

### 3.1 建议目录

- `core/`
  - `flow.lua`：状态机/协程调度（可复用 Deep Future 思想）
  - `util.lua`：缓存、脏标记、通用工具（如 `dirty_update/dirty_trigger`）
- `gameplay/`
  - `store.lua`：持久化/版本管理/原子保存
  - `rng.lua`：确定性 RNG（seed + state）
  - `turn/`：阶段脚本（每阶段一个文件）
    - `start.lua`、`roll.lua`、`move.lua`、`land.lua`、`action.lua`、`end.lua`
  - `board.lua`：棋盘结构与移动规则（线性/环图/分支）
  - `player.lua`：玩家状态（现金、位置、资产、状态）
  - `property.lua`：地块/房屋/租金/抵押规则
  - `decks/`：机会/命运等牌堆
  - `effects/`：效果实现（税、租金、入狱、抽卡、奖励、惩罚等）
  - `sync.lua`：读档/回放后的 UI 对齐（Model → View）
- `visual/`
  - `vboard.lua` / `vplayer.lua` / `vui.lua` / `vdecks.lua`：只负责渲染与动画

### 3.2 模块依赖规则（硬性）

- `gameplay/*` **允许** `require core.*`
- `visual/*` **允许** `require core.*`（输入/渲染工具等）
- `gameplay/*` **可以调用** `visual.*` 触发动画，但不能读取 UI 状态来做规则判断
- 规则判断必须以 `store` 为准

---

## 4. 流程层：用状态机写“规则脚本”

### 4.1 状态机原则

- 每个阶段就是一个函数：
  - 读取/更新 `store`
  - 调用 `visual` 做动画/提示
  - 等待用户交互（通过 input 模块）
  - `return next_state, args`

Deep Future 的协程状态机模式参考：`core/flow.lua`。

### 4.2 大富翁最小闭环状态图（建议）

- `turn.start`：回合开始（清理临时状态、显示提示）
- `turn.roll`：掷骰（写入 `store.turn.dice`）
- `turn.move`：移动（写 `player.pos`；动画在 visual）
- `turn.land`：落地结算（交租/税/卡/进监狱等）
- `turn.action`：玩家可选动作（买地、建房、交易、抵押）
- `turn.end`：切换到下一玩家

> 好处：每个阶段逻辑短、可测试、可插拔，便于加扩展包。

---

## 5. 数据层：Store（持久化与可复现）

### 5.1 Store 的设计规范

- Store 是**唯一事实来源（single source of truth）**。
- Store 中只放“可存档、可复现”的数据：
  - 玩家状态
  - 棋盘与地产状态
  - 牌堆顺序与弃牌堆
  - 当前阶段/回合信息
  - RNG 状态

### 5.2 分域建议（entry）

参考 Deep Future 的 `persist.init(entry, init)` 结构（见 `gameplay/persist.lua`），建议大富翁 store 也分域：

- `players`：玩家数组/字典
- `board`：格子定义与运行时状态
- `properties`：地产所有权、房屋数、抵押状态
- `decks`：机会/命运的 draw/discard
- `turn`：当前玩家、阶段、骰子、回合计数
- `rng`：随机状态
- `meta`：存档版本、兼容信息

### 5.3 原子保存与版本

建议沿用 Deep Future 的策略（`filename.save` → rename 覆盖），并保留 `meta.version`：

- **兼容策略**：读档时校验版本，不兼容则给出错误提示或迁移。

---

## 6. 同步层：sync_all（读档/回放对齐 UI）

### 6.1 为什么需要同步层

- 规则层会“跳变”地更新 store。
- UI 动画可能中途被打断、读档后 UI 状态为空。
- 因此必须有一个可重复执行的 `sync_all()`：
  - 用 store 重建 UI
  - 不依赖“之前是否播过动画”

参考：`gameplay/sync.lua`。

### 6.2 sync_all 的职责（建议清单）

- 玩家棋子位置：逐个玩家把棋子移动到 `player.pos`
- 数值 UI：现金、资产、回合数、当前玩家
- 地产 UI：每个地块的 owner/房屋数/抵押标记
- 卡堆 UI：牌堆剩余张数、弃牌堆内容（如需要展示）
- 临时状态 UI：入狱回合数、双倍点数连掷次数、免租卡等

### 6.3 “全量对齐” vs “差量动画”

- **规则推进时**：可以做差量动画（比如移动步数逐格播动画）。
- **读档/回放时**：优先全量对齐（瞬间对齐或快速动画），保证一致性。

---

## 7. 效果系统：把事件统一成 Effect

### 7.1 为什么要引入 Effect

大富翁的“落地/抽卡/奖励/惩罚/交易/建房”等本质都是“在特定上下文触发的一组规则动作”。

如果全写在 `turn.land.lua` 里会变成超长 if-else；扩展包更难维护。

### 7.2 三层结构（强烈建议）

借鉴 Deep Future 的 `effect` 容器（见 `gameplay/effect.lua`），把效果拆成：

1. **扫描层**：`list_available_effects(ctx) -> effects[]`
   - 根据阶段、当前格子、玩家状态、规则开关列出可选项
2. **判定层**：`can_apply(effect, ctx) -> bool, reason?`
   - 纯判断，不改 store
3. **执行层**：`apply(effect, ctx) -> events[]`
   - 只改 store（或返回可重放的 events）

### 7.3 Effect 执行顺序建议

落地结算通常是“强制效果优先，可选效果后置”：

- 强制：进监狱 / 交税 / 交租 / 抽卡并结算
- 可选：购买地块 / 建房 / 抵押 / 交易

> 可选效果可以走“容器选择器”框架，类似 Deep Future 中对可用 advancement 的高亮与选择。

---

## 8. 随机性：确定性 RNG（seed + state）

### 8.1 必须统一随机入口

- 掷骰、洗牌、抽卡必须走同一 RNG。
- RNG 状态必须进入 store（存档可复现）。

### 8.2 推荐策略

- `rng = RNG(seed)` 初始化
- 每次调用 `rng:next()` 更新内部 state
- `store.rng` 持久化为 `{ seed, state }`

---

## 9. 输入与交互：把“等待点击”当作阶段的一部分

- 阶段脚本可以“等待玩家选择”，等待过程可以 `flow.sleep(0)` 轮询输入模块。
- 选择结果写入 store，然后进入下一阶段。

> 关键原则：输入只产生“决定”，决定写入 store；具体 UI 高亮由 visual 完成。

---

## 10. 测试与调试建议

### 10.1 最低成本的测试策略

- 固定 seed 的“金路径”回合：
  - 玩家 1 掷骰 -> 走到某格 -> 结算 -> 结束
- 固定 seed 的抽卡测试：
  - 抽到某张卡 -> 执行 -> store 状态断言

### 10.2 调试日志建议

- 每次 phase 切换记录：`turn`, `player`, `phase`
- 每次 effect 执行记录：`effect_id`, `before/after`（或 event 列表）

---

## 11. 落地实施路线图（建议 4 周最小可玩）

1. **第 1 周：最小闭环**
   - store + flow + board + player
   - `start → roll → move → land(交租/税) → end`
2. **第 2 周：牌堆与事件**
   - decks（机会/命运）+ effect 框架
   - 抽卡结算完全走 effect
3. **第 3 周：资产系统**
   - 购买/建房/抵押/破产处理
4. **第 4 周：存档/回放/测试**
   - 版本化存档
   - 固定 seed 测试用例

---

## 12. Deep Future → 大富翁：概念对照表

- `core/flow.lua` → 回合/阶段状态机
- `gameplay/persist.lua` → `gameplay/store.lua`（存档与版本）
- `gameplay/sync.lua` → `gameplay/sync.lua`（读档后 UI 全量对齐）
- `gameplay/effect.lua` → `gameplay/effects/*` + 选择器（可选动作/事件统一）
- `gameplay/card.lua` → `gameplay/decks/*`（牌堆/弃牌堆/洗牌/抽牌）
- `gameplay/map.lua` → `gameplay/board.lua`（棋盘、移动、可达性）

---

## 13. 迁移落地检查清单（每次 PR 自查）

- 规则判定是否只读 store，而非读取 UI 状态？
- 是否所有随机都通过统一 RNG，并持久化 RNG state？
- 是否能在任意阶段保存并读档后 `sync_all()` 正确恢复？
- 是否把“落地/抽卡/奖励”抽象为 effect，避免巨型 if-else？
- visual 是否只负责表现（动画/高亮/提示），不直接改 store？


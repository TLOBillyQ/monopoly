# 自动推进与 AI 决策（AutoRunner / Agent 设计与实现）

本文面向规则层与适配层维护者，说明“自动推进（AutoRunner）”与“AI 决策（Agent）”的职责边界、关键函数、数据流与常见维护点，便于快速定位“为什么它会自动点下一回合 / 为什么 AI 会自动选某个选项”。

## 1. 目标与边界

这套机制拆成两层，职责非常明确：

- **AutoRunner（适配层节流器）**：只负责“何时自动触发一个动作”，不负责“动作内容如何更聪明”。
- **Agent（规则层决策器）**：只负责“在面临选择时，自动生成更合理的动作”，不负责“自动推进节奏”。

最重要的理解是：AutoRunner 像一个“定时器”，Agent 像一个“策略函数”。两者配合，但不混在一起。

## 2. AutoRunner：自动推进节奏控制

文件：`src/adapters/core/auto_runner.lua`

### 2.1 结构与状态

AutoRunner 是一个很薄的对象，只有三个核心字段：

- `interval`：自动触发的最小间隔（默认 `0.15` 秒）
- `timer`：累计时间
- `enabled`：是否开启自动推进

关键函数：

- `AutoRunner.new(opts)`
  - 创建实例，支持通过 `opts.interval` 覆盖默认间隔。
- `AutoRunner:set_enabled(on)`
  - 开关自动推进，并清零计时器。
- `AutoRunner:reset_timer()`
  - 只清零计时器，不改 enabled。
- `AutoRunner:next_action(dt, env)`
  - 输入“帧间隔 dt + 运行时环境 env”，输出“一个动作或 nil”。

### 2.2 决策规则（非常克制）

`next_action(dt, env)` 的规则顺序是：

1) 没开启（`enabled=false`）→ 直接返回 `nil`  
2) 游戏已结束（`env.game_finished`）→ 返回 `nil`  
3) 计时未达到间隔（`timer < interval`）→ 返回 `nil`  
4) 若 `env.modal_active` 为真：
   - 有按钮列表（`env.modal_buttons`）→ 返回 `{type="modal_button", index=1}`
   - 否则 → 返回 `{type="modal_confirm"}`
5) 默认 → 返回 `{type="ui_button", id="next"}`

可以看出 AutoRunner 不会“分析局面”，只会“按节奏发一个标准动作”。

### 2.3 AutoRunner 在哪里被调用

AutoRunner 不直接接触 Game，而是通过 AdapterLayer 接入：

文件：`src/adapters/core/adapter_layer.lua`

- `AdapterLayer.step_auto_runner(layer, dt, context)`
  - 调 `layer.auto_runner:next_action(dt, ctx)` 拿动作
  - 若有动作，直接 `layer:dispatch_action(auto_action)`

Eggy 侧在 tick 中默认启用这条链路：

文件：`src/adapters/eggy/eggy_layer.lua`

- `EggyLayer.new(opts)`
  - `auto_runner = AutoRunner.new({ interval = ui.auto_interval })`
- `EggyLayer:tick(dt)`
  - 第一段就是 `AdapterLayer.step_auto_runner(self, dt, {...})`
- `EggyLayer:dispatch_action(action)`
  - 当 `action.type=="ui_button" && action.id=="auto"` 时：
    - 翻转 `ui.auto_play`
    - `self.auto_runner:set_enabled(self.ui.auto_play)`
    - `self.auto_runner:reset_timer()`

结论：AutoRunner 的“开关与频率”在适配层控制，“动作是否合理”不在 AutoRunner 内解决。

## 3. Agent：选择题的自动决策

文件：`src/gameplay/agent.lua`

### 3.1 Agent 只在“选择题”里出手

Agent 的总入口是：

- `Agent.auto_action_for_choice(game, choice)`

它只接管 `pending_choice`，不会直接推进回合流程。

判断条件非常严格：

- 先用 `choice_owner(game, choice)` 找到“这次选择的真正拥有者”
  - 优先 `choice.meta.player_id`
  - 否则回退到 `game:current_player()`
- 再用 `is_auto_player(actor)` 判断是否 AI
  - `player.is_ai` 或 `player.auto` 为真才算自动玩家
- 不是自动玩家 → 直接返回 `nil`

### 3.2 核心策略函数（按选择类型拆分）

Agent 的策略是“按 choice.kind 分发”，重点有几类：

1) 遥控骰子选点数：`remote_dice_value`
- 入口：`Agent.pick_remote_dice_value(game, player, dice_count)`
- 关键过程：
  - `simulate_landing(...)`：模拟落点（会考虑路障/地雷/中途市场打断）
  - `remote_priority(...)`：给落点类型打优先级与评分
  - 选择 rank 更小、score 更大的点数

2) 路障 / 拆除类目标格子
- `roadblock_target` → `Agent.pick_roadblock_target(...)`
  - 依赖：`src/gameplay/item_roadblock.lua`
- `demolish_target / missile_target` → `Agent.pick_demolish_target(...)`
  - 依赖：`src/gameplay/item_demolish.lua`

3) 指定目标玩家类道具：`item_target_player`
- 入口：`Agent.pick_target_player(...)`
- 策略要点：
  - 大多走“找最有钱的对手（richest_other）”
  - `share_wealth`（均富卡）会先判断自己是否最有钱
  - `invite_deity` 会优先找带“天使/财神”等状态的玩家

4) 落地可选效果：`landing_optional_effect / land_optional_effect`
- 优先级固定：
  - 先找 `buy_land`
  - 再找 `upgrade_land`
  - 都没有就选第一个选项

5) 明确保守策略
- `item_phase_choice`：直接取消（`choice_cancel`）
- `market_buy`：直接取消（`choice_cancel`）

这两个“故意保守”的分支很重要：它们避免 AI 在道具阶段或黑市阶段做出不可控的消耗行为。

## 4. AutoRunner 与 Agent 如何配合

它们通过“等待态（wait_*）+ pending_choice”串起来：

### 4.1 规则层：TurnManager 会在等待态询问 Agent

文件：`src/gameplay/turn_manager.lua`

关键逻辑在 `wait_choice` 状态：

- `decide_choice_action(game, choice, pending_action)`：
  1) 若已有 pending_action → 直接用
  2) 否则尝试 `Agent.auto_action_for_choice(game, choice)`
  3) 若没有 UI（`game.ui_port == nil`）→ 兜底选第一个/取消
  4) 都没有 → 返回 nil（继续等待）

这意味着：即使没有适配层参与（例如纯规则脚本），Agent 依然能在等待态推进流程。

### 4.2 适配层：Eggy 在“选择超时”时再次询问 Agent

文件：`src/adapters/eggy/eggy_layer.lua`

在 `EggyLayer:tick(dt)` 里：

- `AdapterLayer.step_choice_timeout(self, dt, { build_action = function(...) ... end })`
  - build_action 的第一行就是：
    - `local auto_choice = Agent.auto_action_for_choice(layer.game, choice)`
  - 若 Agent 给不出动作，才会退化为“选第一个 / 取消”

这形成了“双保险”：

- 规则层等待态会问一次 Agent
- 适配层超时兜底时还会再问一次 Agent

因此，Agent 的策略变更会同时影响“无 UI 推进”和“有 UI 但超时推进”两条路径。

## 5. Agent 在道具系统中的位置（很关键）

很多人会误以为 Agent 只在 TurnManager 里被调用，但道具系统里也深度依赖它。

### 5.1 AI 在道具阶段的“主动出手”

文件：`src/gameplay/item_phase.lua`

当当前玩家是自动玩家时：

- `Strategy.auto_pre_action(...)` 会先尝试主动使用道具
- 若产生需要选择的 intent（`waiting=true`），仍然会走选择系统
- 阶段结束通过 `ItemPhase.finish(...)` 收尾

### 5.2 道具执行器会调用 Agent 选目标 / 选点数

文件：`src/gameplay/item_executor.lua`

在 AI 分支（`context.by_ai == true`）下：

- 目标玩家类道具：
  - `Agent.pick_target_player(...)`
- 遥控骰子：
  - `Agent.pick_remote_dice_value(...)`
- 路障：
  - 复用 `Roadblock.pick_best(...)`（Agent 侧也有一层封装）

这说明：Agent 不是“只给 UI 选择用”，它是 AI 玩法的核心决策模块。

## 6. 常见维护点（按风险排序）

1) **不要把节奏策略塞进 Agent**
- “多久自动点一次 next”属于 AutoRunner，不属于 Agent。

2) **不要把复杂策略塞进 AutoRunner**
- AutoRunner 最好只产出标准动作（如 `ui_button next`），否则会和规则层策略打架。

3) **新增 choice.kind 时，先决定是否需要 AI 行为**
- 若需要 AI 自动决策：在 `Agent.auto_action_for_choice` 增加分支
- 若不需要：明确返回 `choice_cancel` 或保持 `nil`

4) **小心 `choice.meta.player_id`**
- Agent 用它判断“是谁在做选择”。
- 如果 meta.player_id 填错，AI 会替错误的玩家做决定。

5) **AI 兜底顺序要保持稳定**
- 目前大量逻辑依赖“没有策略时选第一个选项”。
- 改动 options 的顺序，可能等价于改了 AI 行为。

## 7. 建议的调试路径（最快定位问题）

当你遇到“AI 乱选 / 自动推进不对劲”，按下面顺序查：

1) 先看是否是节奏问题（AutoRunner）
- 是否点了自动：`EggyLayer:dispatch_action` 中 `id=="auto"`
- 频率是否异常：`ui.auto_interval` 与 `AutoRunner.interval`

2) 再看是否是“选择题策略问题”（Agent）
- 当前 choice.kind 是什么
- choice.meta.player_id 是否正确
- `Agent.auto_action_for_choice` 是否覆盖该 kind

3) 最后看是否是等待态/超时逻辑问题
- 规则层：`src/gameplay/turn_manager.lua` 的 `wait_choice`
- 适配层：`AdapterLayer.step_choice_timeout(...)`

## 8. 回归测试建议

已有回归用例已经覆盖 Agent 的关键入口：

- 文件：`tests/regression.lua`
- 关注位置：包含 `Agent = require("src.gameplay.agent")` 与 `Agent.auto_action_for_choice(...)` 的用例段落

建议至少运行：

- `lua tests/deps_check.lua`
- `lua tests/regression.lua`

## 9. 小结

可以用一句话记住这套设计：

- AutoRunner 决定“什么时候自动发动作”
- Agent 决定“自动发什么动作更合理”

它们通过 TurnManager 的等待态与 AdapterLayer 的超时兜底衔接在一起，既保证了自动推进节奏，也保证了 AI 选择的可控与可维护。


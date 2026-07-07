---
kind: spec
status: draft
owner: specifier
---

# Acceptance 测试接入真实 src/ 代码

## 背景

现有 9 个 game feature（150 场景）全部通过，但 step handler 内联模拟游戏逻辑，
未调用任何 `src/` 生产代码（唯一引用 `src.foundation.number` 仅做整数解析）。
这使得 acceptance 测试验证的是"规格自洽"而非"代码行为正确"。

### 目标

让 step handler 通过 `compose_game.new_game()` 创建真实游戏实例，
用真实 API（`movement.move`, `game:add_player_cash`, `game:set_tile_owner` 等）
驱动场景，断言查询真实 game state。

### 现有基础

- `spec/support/test_profile_support.lua` 已有 `new_game()` 模式
- `compose_game.new_game(opts)` 接受 `rng` 注入（可控骰子）
- `game_factory.build_rng(fn)` 可传入自定义随机函数
- game state 通过 mixin 安装 player/board/turn 操作

---

## 设计

### D1 — game_driver 模块

新增 `tools/acceptance/game_driver.lua`，职责：

1. **创建游戏**：封装 `compose_game.new_game()` + `default_ports` + 标准配置
2. **控制 RNG**：提供 `set_next_rolls(values)` 队列式确定性骰子
3. **简化查询**：暴露常用查询（玩家余额、位置、背包、地块状态）
4. **避免 UI 依赖**：不初始化 `state_factory`，不依赖 Eggy 宿主

```
-- 伪代码接口
driver.new_game(opts)           -- 返回 { game = ..., helpers = ... }
driver.player(world, index)     -- 返回第 N 个玩家对象
driver.current_player(world)    -- 返回当前回合玩家
driver.move(world, steps, opts) -- 调用 rules.movement.move
driver.set_next_rolls(world, values) -- 队列式注入骰子结果
driver.player_cash(world, player)
driver.player_position(world, player)
driver.tile_at(world, index)
driver.tile_owner(world, index)
driver.tile_level(world, index)
```

### D2 — step handler 改造模式

每个 step 模块的 `"游戏已初始化标准棋盘"` handler 改为调用 `game_driver.new_game()`，
将真实 game 实例存入 `world.game`。后续 handler 通过 `world.game` 操作真实 state。

**改造前**（inline simulation）：
```lua
["玩家移动<p2>步"] = function(world, example)
  local steps = number_utils.to_integer(example.p2)
  _move_forward(world.game, steps)  -- 自建 _move_forward
  return true
end
```

**改造后**（real src）：
```lua
["玩家移动<p2>步"] = function(world, example)
  local steps = number_utils.to_integer(example.p2)
  local player = driver.current_player(world)
  driver.move(world, player, steps)  -- 调 rules.movement.move
  return true
end
```

### D3 — 分阶段改造

按 feature 复杂度递增：

| 阶段 | Feature | 场景数 | 核心 src/ 模块 |
|------|---------|--------|---------------|
| P1 | dice_roll | 7 | `rules.movement`, `rules.board` |
| P2 | movement | 15 | `rules.movement`, `board_state`(roadblock/mine) |
| P3 | dice | 13 | `turn.phases.roll`, `rules.items.remote_dice` |
| P4 | economy | 27 | `rules.land.rent_math`, `rules.land.pricing`, `player.actions.balance` |
| P5 | bankruptcy | 2 | `rules.endgame` |
| P6 | endgame | 14 | `rules.endgame`, `player.actions.location` |
| P7 | turn_flow | 17 | `turn.loop`, `turn.phases` |
| P8 | items | 30 | `rules.items.*`, `player.actions.inventory` |
| P9 | chance | 25 | `rules.chance.*`, `rules.effects.*` |

### D4 — 场景兼容策略

部分现有场景的参数与真实 game config 不匹配（如 step handler 硬编码
`BOARD_SIZE = 36` 而真实棋盘由 `default_map` 决定）。策略：

- **dice_roll feature**：使用 0-based position（`位置0` ~ `位置N`），
  而真实 board 使用 1-based tile index。handler 做 offset 转换。
- **经济参数**：feature 中的金额是抽象值；handler 预设玩家余额后
  通过 `game:set_player_cash` 注入，断言也读真实 `game:player_cash`。
- **棋盘格数**：feature 中 `棋盘共有<格数>格` 需要动态创建对应大小棋盘，
  或改用真实棋盘尺寸。推荐后者：修改 feature 例子表适配真实棋盘。

### D5 — vendor 依赖隔离

`compose_game.lua` require `vendor.third_party.Utils`（Eggy ClassUtils）。
behavior spec 已通过 `spec/helper.lua` + `spec/bootstrap.lua` mock 这些依赖。
game_driver 复用相同 bootstrap 机制。

---

## 变更范围

1. **新增** `tools/acceptance/game_driver.lua` — 真实游戏创建与驱动
2. **改造** `tools/acceptance/steps/movement.lua` — 接入真实 board + movement
3. **改造** `tools/acceptance/steps/dice.lua` — 接入真实 roll + RNG 注入
4. **改造** `tools/acceptance/steps/economy.lua` — 接入真实 rent/purchase/tax
5. **改造** `tools/acceptance/steps/items.lua` — 接入真实 item executor
6. **改造** `tools/acceptance/steps/chance.lua` — 接入真实 chance resolver
7. **改造** `tools/acceptance/steps/endgame.lua` — 接入真实 endgame checker
8. **改造** `tools/acceptance/steps/turn_flow.lua` — 接入真实 turn loop
9. **可能修改** `features/game/*.feature` — 适配真实 config 参数（最小化修改）

---

## 验收标准

| # | 标准 | 验证方式 |
|---|------|----------|
| R1 | `game_driver.new_game()` 返回真实 game 实例（通过 `compose_game.new_game`） | 检查 require 链 |
| R2 | step handler 中无自建 board/player/game 数据结构 | grep 排除 `_new_board` / `_new_player` / `_new_game` |
| R3 | 所有 9 个 feature 全部通过（≥150 场景 ok） | `run_acceptance.lua` 逐个运行 |
| R4 | step handler 的 state 查询使用 game API（如 `game:player_cash`），不直接访问 `world.player.cash` 等自建字段 | code review |
| R5 | movement handler 调用 `rules.movement.move`，不再自建 `_move_forward` | grep 验证 |
| R6 | economy handler 调用真实 rent/purchase 函数，不再 inline 模拟 | grep 验证 |
| R7 | dice handler 通过 RNG 注入控制骰子结果 | 检查 `game_driver.set_next_rolls` 调用 |
| R8 | 不新增 Eggy 宿主依赖（game_driver 纯 Lua + 现有 vendor mock） | require 链检查 |

---

## 不在范围

- 新增 feature 文件（本期只接入现有 9 个 game feature）
- market 购买 / AI 决策 / UI 渲染的 acceptance 覆盖（后续规格）
- 修改 `src/` 生产代码
- 修改 behavior / contract / guard 测试

---

## 2026-05-23 策划案对齐场景追踪

本节记录 `docs/product/design-source/蛋仔策划案--大富翁.docx` 对齐后新增或修正的高风险场景，
避免把 acceptance 的 world 状态模拟误读为 `src/` 覆盖。

| Feature 场景 | 覆盖状态 | 当前生产入口 | 补充验证 |
|--------------|----------|--------------|----------|
| 单块地块按地价和加盖次数计算租金 | 已接真实代码 | `src.rules.land.pricing.rent_for_level` | `spec/behavior/rules/land_spec.lua` |
| 天使守护不免疫税务局 | 已接真实代码 | `src.rules.land.effect_base.executors.tax.apply` | `spec/behavior/rules/land_spec.lua` |
| 游戏时间结束时资产最高者获胜 | 已接真实代码 | `src.rules.endgame.check_victory` | `spec/behavior/rules/endgame_turn_limit_spec.lua` |
| 天使守护不免疫医院和深山停留 | 已接真实代码 | `src.rules.land.effect_special.executors.{hospital,mountain}.apply` | `spec/behavior/rules/land_spec.lua` |
| 天使守护不免疫路障 | 已接真实代码 | `src.rules.movement.move` | `spec/behavior/scenarios/angel_immunity/angel_immunity_spec.lua` |
| 黑市只展示道具商品并去掉皮肤分页 | 已接真实代码 | `src.rules.market.query` | acceptance step 直接查询 production market list |
| 导弹卡轰炸自己地块也摧毁建筑 | 已接真实代码 | `src.rules.items.demolish.apply` | `spec/behavior/rules/item_spec.lua` |
| AI 主动道具优先级 | 部分接入 | `src.rules.items.post_effects.target_item_ids` / `src.computer.agent.action` | 仍缺完整“从背包选择第一张可用主动卡”的 production acceptance |
| 点击道具槽位弹出使用和丢弃按钮 | 规格锁定 | 暂无稳定 production 入口 | 需要 UI item-slot action panel/use-discard coordinator |
| 丢弃道具删除该卡并空出卡槽 | 规格锁定 | 暂无稳定 production 入口 | 需要 inventory discard use-case 或 UI coordinator |

规则：`覆盖状态=规格锁定` 的场景不得作为 `src/` 已验证证据引用；只有直接调用
`src/` 模块或有对应 behavior spec 的场景，才算实现覆盖。

---

## 风险

- **feature 参数不匹配真实 config**：dice_roll 用 0-based position、economy
  用小金额。可能需要小幅调整 feature 例子表，或在 handler 中做合理的 config override。
  原则：最小化 feature 修改，优先在 handler/driver 层适配。
- **turn loop 复杂度**：`turn_flow.feature` 涉及完整回合循环，可能需要细粒度
  phase 控制。game_driver 需暴露 `advance_to_phase` 等辅助接口。
- **chance/item 随机性**：需注入 deterministic RNG 控制卡池抽取和道具效果。

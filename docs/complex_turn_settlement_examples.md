# 复杂回合结算用例说明

本文档展示蛋仔大富翁中最复杂的回合结算场景，这些场景包含多个连续触发的效果。

## 概述

回合结算的复杂性来自于**连锁触发机制**：一个效果的结果可能触发另一个效果，形成深度嵌套的处理流程。系统通过 `effect_pipeline.lua` 和递归的 `resolve_landing` 函数来处理这些连锁效果。

### 系统限制
- **最大落地深度**：`MAX_LANDING_DEPTH = 10`（防止无限递归）
- **效果处理顺序**：强制效果 → 可选效果
- **中断与恢复**：通过 `wait_choice` 状态暂停回合，等待玩家决策

## 最复杂场景：五层连续触发

### 场景描述

**初始设置**：
- 玩家 P1 位于位置 A
- 玩家 P2 位于位置 B（A 和 B 之间）
- P1 持有偷窃卡（道具 ID 2007）
- P1 拥有座驾（例如滑板 4001）
- 位置 C 是机会卡格子
- 位置 D 有地雷陷阱
- 位置 E 是医院

**触发流程**：

```
回合开始
  ↓
1. 移动阶段（turn_move.lua）
   P1 投骰子移动 3 格
   经过 P2 的位置 B
   最终停在位置 C（机会卡格子）
   ↓
2. 落地效果：擦肩而过（landing_effects: pass_players）
   检测到经过了 P2
   P1 持有偷窃卡 → 触发偷窃提示
   [等待选择：是否使用偷窃卡？]
   ↓
3. 落地效果：机会卡（landing_effects: chance_draw_and_resolve）
   抽取机会卡："后方有犬吠，你向前跑两格"
   effect = "move_forward", steps = 2
   → 触发二次移动
   ↓
4. 二次移动（chance.lua: handlers.move_forward）
   从位置 C 向前移动 2 格
   到达位置 D
   → 返回 { kind = "need_landing" }
   ↓
5. 二次落地效果：地雷（landing_effects: mine）
   检测到位置 D 有地雷
   P1 没有天使保护
   座驾不是免疫地雷的（仅法拉利 4006 免疫）
   → 地雷爆炸：摧毁座驾，送往医院
   → 返回 { kind = "need_landing", hospitalized = true }
   ↓
6. 三次落地效果：医院（landing_effects: hospital）
   位置更新到医院 E
   触发医院效果：治疗所有负面状态
   如果有停留回合数，清除或更新
   ↓
回合结束（turn_end.lua）
```

### 代码实现

这个场景在 `tests/regression.lua` 中实现为：
```lua
test_complex_consecutive_turn_settlement()
```

### 涉及的核心文件

1. **turn_manager.lua** - 回合流程协调器
2. **turn_move.lua** - 移动阶段处理
3. **turn_land.lua** - 落地阶段处理（递归 `resolve_landing`）
4. **effect_pipeline.lua** - 效果管道执行器
5. **landing_effects.lua** - 落地效果定义列表
6. **chance.lua** - 机会卡效果处理器
7. **mine_effect.lua** - 地雷效果处理
8. **item_steal.lua** - 偷窃卡效果

### 技术要点

#### 1. 递归落地处理

```lua
local function resolve_landing(game, player, tile, move_result, depth)
  depth = depth or 0
  -- ...
  
  local function handle_need_landing(out)
    if depth >= MAX_LANDING_DEPTH then
      return out  -- 防止无限递归
    end
    -- 递归调用 resolve_landing
    return resolve_landing(game, target_player, next_tile, out.move_result, depth + 1)
  end
  
  return EffectPipeline.run(landing_defs, player, tile, game_ctx, {
    on_need_landing = handle_need_landing,
    -- ...
  })
end
```

#### 2. 效果管道

强制效果按顺序执行，遇到 `waiting` 状态时暂停：

```lua
function Pipeline.run(effect_defs, player, tile, game_ctx, opts)
  -- 扫描并分类效果
  local mandatory = {}
  local optional = {}
  
  -- 执行所有强制效果
  for _, eff in ipairs(mandatory) do
    local res = Effect.execute(eff, player, tile, game_ctx)
    
    -- 如果返回 need_landing，触发递归
    if opts.on_need_landing and res.kind == "need_landing" then
      res = opts.on_need_landing(res)
    end
    
    -- 如果需要等待（如选择），立即返回
    if res.waiting then
      return res
    end
  end
  
  -- 处理可选效果（如购买地块）
  -- ...
end
```

#### 3. 意图派发

所有需要 UI 交互的事件通过 `IntentDispatcher` 发送：

```lua
IntentDispatcher.dispatch(game, {
  kind = "need_choice",
  choice_spec = {
    kind = "steal_prompt",
    title = "是否使用偷窃卡",
    options = { ... },
    meta = { ... }
  }
})
```

## 其他复杂场景

### 场景 2：黑市中断 + 租金支付

**流程**：
1. 移动经过黑市（`market_interrupt`）
2. 暂停移动，打开黑市购买界面
3. 购买完成后继续移动
4. 落地在他人地块上
5. 触发支付租金效果
6. 如果资金不足，触发破产流程

**测试用例**：
```lua
test_complex_market_interrupt_with_rent()
```

### 场景 3：台风卡 + 路径摧毁

**流程**：
1. 落地机会卡
2. 抽到"台风过境"（id 3017）
3. 遍历本回合经过的所有地块
4. 摧毁路径上所有建筑（`level = 0`）
5. 记录日志事件

**实现**：`chance.lua: handlers.destroy_buildings_on_path`

### 场景 4：强制征地 + 路径重置

**流程**：
1. 落地机会卡
2. 抽到"强制征地"（id 3018）
3. 遍历本回合经过的所有地块
4. 重置路径上所有地块（owner = nil, level = 0）
5. 更新玩家属性列表

**实现**：`chance.lua: handlers.reset_tiles_on_path`

### 场景 5：连续多人支付

**流程**：
1. 机会卡："破财消灾"（id 3012）
2. 向每位其他玩家支付 3000 金币
3. 如果持有穷神卡，支付翻倍
4. 如果对方在深山，跳过支付
5. 如果资金不足，触发破产

**实现**：`chance.lua: handlers.pay_others`

## 调试技巧

### 启用详细日志

```lua
local Logger = require("src.util.logger")
Logger.level = "DEBUG"
```

### 追踪落地深度

在 `turn_land.lua` 中添加：
```lua
print(string.format("[Landing] depth=%d, tile=%s, player=%s", 
  depth, tile.name, player.name))
```

### 检查选择堆栈

```lua
local pending = game.store:get({ "turn", "pending_choice" })
if pending then
  print("Pending choice:", pending.kind, pending.title)
end
```

## 性能考虑

1. **避免深度过大**：10 层递归已经是极限情况
2. **及时清理状态**：每个效果执行后清理临时数据
3. **缓存计算结果**：如邻接地块列表、租金计算

## 相关配置文件

- **landing_effects.lua** - 落地效果定义
- **chance_cards.lua** - 机会卡配置
- **items.lua** - 道具配置
- **constants.lua** - 常量配置

## 扩展性建议

如果需要添加新的复杂效果：

1. **在 `landing_effects.lua` 中定义效果**：
   ```lua
   { id = "new_effect", label = "新效果", mandatory = true }
   ```

2. **在 `landing.lua` 中实现执行器**：
   ```lua
   Landing.executors.new_effect = {
     can_apply = function(ctx) ... end,
     apply = function(ctx) ... end,
   }
   ```

3. **如果需要触发二次落地**：
   ```lua
   return {
     kind = "need_landing",
     player_id = player.id,
     board_index = new_position,
     move_result = {...}
   }
   ```

4. **添加对应的回归测试**

## 总结

蛋仔大富翁的回合结算系统通过以下机制支持复杂的连锁效果：

- ✅ **递归落地处理** - 支持多层嵌套
- ✅ **效果管道** - 有序执行强制和可选效果
- ✅ **意图派发** - 解耦业务逻辑与 UI 交互
- ✅ **状态恢复** - 支持中断与继续
- ✅ **深度限制** - 防止无限递归

这些设计使得游戏能够处理非常复杂的连锁效果，同时保持代码的可维护性和可测试性。

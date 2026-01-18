# 最复杂回合结算：游戏场景可视化

## 场景设置

```
棋盘布局示意（概念图，位置仅供说明）：

起点(1) ──→ 地块(2) ──→ 地块(3) ──→ ... ──→ 玩家P2(12) ──→ 机会卡(13) ──→ 地块(14) ──→ 地雷!(15) ──→ ...

注： 实际测试中位置由代码动态确定，此图仅用于理解流程
初始状态：
- 玩家P1: 位置10
- 玩家P2: 位置12
- 机会卡: 位置13
- 地雷陷阱: 位置15
- 医院: 位置36

玩家P1 持有：
  ✓ 偷窃卡 (道具2007)
  ✓ 滑板座驾 (4001)
  ✓ 10000 金币

玩家P2 持有：
  ✓ 路障卡 (道具2001)
  ✓ 10000 金币
```

## 回合执行过程

### 第1步：投骰子 & 移动

```
回合开始 - 玩家P1的回合
投骰结果: 3 点

位置10 ──→ 位置11 ──→ 位置12 (经过P2!) ──→ 位置13 (机会卡)
  P1           步1          步2              步3

移动结果 (move_result):
{
  visited = [11, 12, 13],
  encountered_players = [2],  -- 经过了玩家2
  stopped_on_roadblock = false,
  passed_start = 0
}
```

### 第2步：落地效果 - 擦肩而过 (depth=0)

```
检测: move_result.encountered_players = [2]
检测: P1 持有偷窃卡 (2007)

触发: item_steal.lua: handle_pass_players()

┌─────────────────────────────────┐
│  💭 选择提示                      │
│  是否使用偷窃卡？                 │
│  目标：玩家P2                     │
│                                  │
│  [使用] [跳过]                    │
└─────────────────────────────────┘

系统状态: waiting = true
回合暂停，等待玩家决策...

(假设玩家选择"使用")
```

### 第3步：偷窃执行

```
执行: Steal.steal_item_at_index(P1, P2, 1)

P2 背包: [路障卡(2001)] → 移除路障卡
P1 背包: [偷窃卡(2007)] → [路障卡(2001)]
P1 消耗: 偷窃卡(2007)

日志: "玩家P1 使用偷窃卡，从 玩家P2 偷走道具 路障卡"

继续执行落地效果...
```

### 第4步：落地效果 - 机会卡 (depth=0)

```
当前位置: 13 (机会卡格子)

触发: chance.lua: resolve()

抽卡 RNG: 使用加权随机选择
抽中: 机会卡 3023 "后方有犬吠，你向前跑两格"
{
  id = 3023,
  effect = "move_forward",
  steps = 2,
  negative = false
}

执行: handlers.move_forward(game, P1, card)

二次移动: 
  位置13 ──→ 位置14 ──→ 位置15 (有地雷!)
          步1       步2

返回结果:
{
  kind = "need_landing",  -- 🔥 关键: 触发二次落地
  player_id = 1,
  board_index = 15,
  move_result = { visited = [14, 15], ... }
}

触发回调: on_need_landing() → 递归调用 resolve_landing(depth=1)
```

### 第5步：二次落地 - 地雷效果 (depth=1)

```
当前位置: 15 (地雷陷阱)

检测: board:has_mine(15) = true
检测: P1.has_angel() = false  -- 没有天使保护
检测: P1.vehicle.indestructible = false  -- 滑板不免疫地雷

触发: mine_effect.lua: apply()

执行步骤:
1. board:clear_mine(15)  -- 清除地雷
2. game:set_player_seat(P1, nil)  -- 💥 摧毁座驾
3. player:send_to_hospital(P1)  -- 送往医院

日志: "玩家P1 触发地雷，座驾被摧毁并送医"

P1 位置: 15 → 36 (医院)
P1 状态: stay_turns = 1 (需要住院1回合)

返回结果:
{
  kind = "need_landing",  -- 🔥 再次触发落地
  player_id = 1,
  board_index = 36,
  move_result = { hospitalized = true }
}

触发回调: on_need_landing() → 递归调用 resolve_landing(depth=2)
```

### 第6步：三次落地 - 医院效果 (depth=2)

```
当前位置: 36 (医院)
tile.type = "hospital"

触发: landing.lua: executors.hospital.apply()

执行: player:apply_hospital_effects(game)

医院效果:
- 治疗所有负面状态
- 清除或更新 stay_turns (根据规则)
- 如果有疾病状态，治愈

日志: "玩家P1 在医院接受治疗"

返回结果: nil  -- ✅ 不触发新的落地

递归结束，返回 depth=1
递归结束，返回 depth=0
```

### 第7步：回合结束

```
落地效果全部处理完成
没有可选效果（因为医院不是地块）

进入: turn_post.lua
进入: turn_end.lua

回合结束检查:
- 更新回合数
- 检查是否有玩家破产
- 检查游戏是否结束

切换到下一个玩家
```

## 完整事件日志

```
[回合] 回合: 1 [Player 1]
[移动] 玩家P1 投骰子: 3 点
[移动] 玩家P1 移动: 10 → 11 → 12 → 13
[效果] 玩家P1 经过了 玩家P2
[选择] 是否使用偷窃卡？目标：玩家P2
[道具] 玩家P1 使用偷窃卡，从 玩家P2 偷走道具 路障卡
[效果] 玩家P1 抽到机会卡 后方有犬吠，你向前跑两格
[移动] 玩家P1 移动: 13 → 14 → 15
[效果] 玩家P1 触发地雷，座驾被摧毁并送医
[效果] 玩家P1 在医院接受治疗
[回合] 回合结束
```

## 系统状态追踪

```
初始状态:
P1 = { position=10, cash=10000, vehicle=4001, inventory=[2007], eliminated=false }
P2 = { position=12, cash=10000, vehicle=nil, inventory=[2001], eliminated=false }
Board(15) = { has_mine=true }

最终状态:
P1 = { position=36, cash=10000, vehicle=nil, inventory=[2001], eliminated=false, stay_turns=1 }
P2 = { position=12, cash=10000, vehicle=nil, inventory=[], eliminated=false }
Board(15) = { has_mine=false }

变化:
✓ P1 位置: 10 → 36 (医院)
✓ P1 座驾: 4001 → nil (被地雷摧毁)
✓ P1 道具: [2007] → [2001] (偷窃后)
✓ P1 状态: stay_turns = 1
✓ P2 道具: [2001] → [] (被偷)
✓ 地雷清除: 位置15 的地雷被引爆
```

## 代码调用栈

```
TurnManager:dispatch()
├── phase_move(depth=0)
│   └── MovementService.move(P1, 3)
│       └── 返回: { visited=[11,12,13], encountered_players=[2] }
│
├── phase_land(depth=0)
│   └── resolve_landing(P1, tile(13), move_result, depth=0)
│       └── EffectPipeline.run(landing_defs, ...)
│           │
│           ├── [强制] pass_players
│           │   └── Steal.handle_pass_players()
│           │       └── 返回: { waiting=true, intent={need_choice} }
│           │       └── [暂停] 等待选择
│           │       └── [继续] Steal.steal_item_at_index()
│           │
│           ├── [强制] chance_draw_and_resolve
│           │   └── ChanceEffects.resolve(P1, card(3023))
│           │       └── handlers.move_forward(P1, 2)
│           │           └── MovementService.move(P1, 2)
│           │           └── 返回: { kind="need_landing", board_index=15 }
│           │               │
│           │               └── on_need_landing() → resolve_landing(P1, tile(15), result, depth=1)
│           │                   └── EffectPipeline.run(landing_defs, ...)
│           │                       │
│           │                       ├── [强制] mine
│           │                       │   └── MineEffect.apply(P1, 15)
│           │                       │       └── player:send_to_hospital(P1)
│           │                       │       └── 返回: { kind="need_landing", board_index=36, hospitalized=true }
│           │                       │           │
│           │                       │           └── on_need_landing() → resolve_landing(P1, tile(36), result, depth=2)
│           │                       │               └── EffectPipeline.run(landing_defs, ...)
│           │                       │                   │
│           │                       │                   ├── [强制] hospital
│           │                       │                   │   └── player:apply_hospital_effects(P1)
│           │                       │                   │   └── 返回: nil
│           │                       │                   │
│           │                       │                   └── 返回 nil (depth=2)
│           │                       │
│           │                       └── 返回到 depth=1
│           │
│           └── 返回到 depth=0
│
└── phase_end()
    └── 回合结束
```

## 技术亮点

### 1. 递归深度控制
```lua
MAX_LANDING_DEPTH = 10
当前场景使用: depth=0 → depth=1 → depth=2 (共3层)
```

### 2. 意图派发解耦
```lua
IntentDispatcher.dispatch(game, { kind = "need_choice", ... })
-- UI 层监听意图，业务层不关心 UI 实现
```

### 3. 状态恢复机制
```lua
return {
  waiting = true,
  resume_state = "post_action",
  resume_args = { player = player }
}
-- 选择解决后从 resume_state 继续
```

### 4. 效果管道
```lua
强制效果按序执行 → 遇到 waiting 暂停 → 解决后继续 → 可选效果
```

## 相关测试

- **测试函数**: `test_complex_consecutive_turn_settlement()`
- **文件位置**: `tests/regression.lua`
- **验证点**: 
  - ✓ 不崩溃
  - ✓ 最终状态正确
  - ✓ 递归深度不超限

## 总结

这个场景展示了蛋仔大富翁回合结算系统的**核心能力**：

1. ✅ **多层递归** - 3 层嵌套落地处理
2. ✅ **异步等待** - 偷窃卡选择暂停回合
3. ✅ **连锁触发** - 机会卡 → 移动 → 地雷 → 医院
4. ✅ **状态一致性** - 所有状态正确更新
5. ✅ **日志完整** - 每个效果都有记录

代码设计精髓：**用递归处理连锁效果，用意图派发解耦UI，用效果管道保证顺序。**

# 最复杂回合结算用例速查

## 快速导航

- **测试代码位置**：`tests/regression.lua`
  - `test_complex_consecutive_turn_settlement()` - 五层连续触发
  - `test_complex_market_interrupt_with_rent()` - 黑市中断场景
- **详细文档**：`docs/complex_turn_settlement_examples.md`

## 最复杂场景：五层连续触发示例

### 视觉流程图

```
玩家投骰子
    ↓
[1] 移动 3 格（经过其他玩家）
    ↓
[2] 落地效果：擦肩而过 → 偷窃卡提示
    ↓ (玩家选择)
[3] 落地效果：机会卡 → 抽到"向前跑两格"
    ↓
[4] 二次移动 → 到达新位置（有地雷）
    ↓
[5] 落地效果：地雷 → 摧毁座驾，送往医院
    ↓
[6] 三次落地：医院 → 治疗效果
    ↓
回合结束
```

### 触发的效果类型

| 序号 | 效果类型 | 定义位置 | 是否强制 | 可能触发二次落地 |
|------|---------|---------|---------|---------------|
| 1 | 擦肩而过 | landing_effects.lua | 强制 | 否（但会等待选择） |
| 2 | 机会卡 | landing_effects.lua | 强制 | 是（某些卡会移动） |
| 3 | 地雷 | landing_effects.lua | 强制 | 是（送医院） |
| 4 | 医院 | landing_effects.lua | 强制 | 否 |

### 代码执行路径

```
TurnManager:dispatch()
  → turn_move.lua: phase_move()
    → MovementService.move()
      → 返回 move_result { encountered_players = [...] }
  
  → turn_land.lua: phase_land()
    → resolve_landing(depth=0)
      → EffectPipeline.run()
        
        [强制效果1] pass_players
          → item_steal.lua: handle_pass_players()
          → 返回 { waiting = true, intent = { need_choice } }
          → 暂停，等待选择
        
        (选择解决后继续)
        
        [强制效果2] chance_draw_and_resolve
          → chance.lua: resolve()
          → handlers.move_forward()
          → 返回 { kind = "need_landing", player_id, board_index }
          → 触发 on_need_landing 回调
        
        → resolve_landing(depth=1)
          → EffectPipeline.run()
            
            [强制效果3] mine
              → mine_effect.lua: apply()
              → player:send_to_hospital()
              → 返回 { kind = "need_landing", hospitalized = true }
              → 触发 on_need_landing 回调
            
            → resolve_landing(depth=2)
              → EffectPipeline.run()
                
                [强制效果4] hospital
                  → player_effects.lua: apply_hospital_effects()
                  → 清除负面状态
                  → 返回 nil（不触发新落地）
                
                → 返回到 depth=1
            
            → 返回到 depth=0
        
        → 返回到 phase_land
  
  → turn_post.lua: phase_post()
  → turn_end.lua: phase_end()
```

## 如何运行测试

### 使用 LÖVE 运行完整游戏
```bash
love .
```

### 使用 Lua 运行回归测试
```bash
# 如果安装了 lua5.1
lua tests/regression.lua

# 或使用 lua5.3
lua5.3 tests/regression.lua

# 或使用 luajit
luajit tests/regression.lua
```

### 预期输出
```
....................
All regression checks passed (22)
```

## 关键代码片段

### 1. 递归深度限制

```lua
-- turn_land.lua
local MAX_LANDING_DEPTH = 10

local function resolve_landing(game, player, tile, move_result, depth)
  depth = depth or 0
  
  local function handle_need_landing(out)
    if depth >= MAX_LANDING_DEPTH then
      return out  -- 防止无限递归
    end
    -- 递归处理新的落地
    return resolve_landing(game, target_player, next_tile, out.move_result, depth + 1)
  end
  
  return EffectPipeline.run(landing_defs, player, tile, game_ctx, {
    on_need_landing = handle_need_landing,
  })
end
```

### 2. 机会卡触发移动

```lua
-- chance.lua
handlers.move_forward = function(game, player, card)
  local movement = game:get_service("movement")
  local res = movement.move(game, player, card.steps or 0)
  return {
    kind = "need_landing",  -- 关键：触发新的落地
    player_id = player.id,
    board_index = player.position,
    move_result = res,
  }
end
```

### 3. 地雷送医院

```lua
-- mine_effect.lua
function MineEffect.apply(game, player, position)
  board:clear_mine(position)
  game:set_player_seat(player, nil)  -- 摧毁座驾
  player:send_to_hospital(game)
  return {
    detonated = true,
    hospitalized = true,
    new_position = player.position  -- 医院位置
  }
end

-- landing.lua
Landing.executors.mine = {
  apply = function(ctx)
    local res = MineEffect.apply(ctx.game, ctx.player, ctx.tile.id)
    if res and res.hospitalized then
      return {
        kind = "need_landing",  -- 触发医院落地
        player_id = ctx.player.id,
        board_index = ctx.player.position,
      }
    end
  end,
}
```

## 测试场景速查表

| 测试函数 | 复杂度 | 涉及效果 | 递归深度 |
|---------|-------|---------|---------|
| test_complex_consecutive_turn_settlement | ⭐⭐⭐⭐⭐ | 偷窃+机会卡+移动+地雷+医院 | 3 |
| test_complex_market_interrupt_with_rent | ⭐⭐⭐⭐ | 黑市中断+继续移动+租金支付 | 1 |
| test_missile_card | ⭐⭐⭐ | 导弹卡+多目标摧毁+送医 | 1 |
| test_chance_is_mandatory_effect_entrypoint | ⭐⭐ | 机会卡随机效果 | 1 |

## 调试建议

如果测试失败，按以下顺序排查：

1. **检查 RNG 设置**：复杂场景依赖特定的随机结果
   ```lua
   g.rng = { 
     next_float = function() return 0.1 end,
     random = function() return 1 end,
   }
   ```

2. **验证位置设置**：确保玩家位置、地雷位置正确
   ```lua
   print(string.format("P1 pos=%d, tile=%s", p1.position, g.board:get_tile(p1.position).name))
   ```

3. **追踪落地深度**：添加调试输出
   ```lua
   print(string.format("[Landing] depth=%d, tile=%s", depth, tile.name))
   ```

4. **检查选择处理**：确保所有等待的选择都被正确解决
   ```lua
   local pending = get_choice(g)
   if pending then
     print("Pending choice:", pending.kind)
   end
   ```

## 扩展阅读

- **回合管理器**：`src/gameplay/turn_manager.lua`
- **效果管道**：`src/gameplay/effect_pipeline.lua`
- **落地效果定义**：`src/config/landing_effects.lua`
- **机会卡配置**：`src/config/chance_cards.lua`
- **架构文档**：`docs/design/architecture.md`

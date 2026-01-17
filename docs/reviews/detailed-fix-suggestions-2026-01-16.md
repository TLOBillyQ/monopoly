# 蛋仔大富翁项目详细修复建议

**日期**: 2026-01-16  
**版本**: 1.0

---

## 1. 删除 ui_port.lua 包装层

### 问题描述
`ui_port.lua` 是一个仅有22行代码的包装层，只提供了两个简单的函数，没有实际的业务逻辑，属于违反 AGENTS.md "无默认抽象" 原则的典型例子。

### 当前代码
```lua
-- src/gameplay/ui_port.lua
local UI = {}

local function get_port(game)
  if game and game.ui_port then
    return game.ui_port
  end
  return nil
end

function UI.is_available(game)
  return get_port(game) ~= nil
end

function UI.push_popup(game, payload)
  local port = get_port(game)
  if port and port.push_popup then
    return port:push_popup(payload) ~= false
  end
  return false
end

return UI
```

### 修复步骤

#### 步骤1: 查找所有调用点
在项目中搜索 `UI.is_available` 和 `UI.push_popup` 的使用位置：

```bash
grep -r "UI\.is_available" src/
grep -r "UI\.push_popup" src/
```

根据代码分析，调用点包括：
1. `src/gameplay/choice_resolver.lua`
2. `src/gameplay/item_phase.lua`
3. `src/gameplay/market_service.lua`
4. 其他8个文件

#### 步骤2: 替换调用代码

**替换 `UI.is_available(game)`**:
```lua
-- 原代码
if UI.is_available(game) then
  -- ...
end

-- 新代码
if game.ui_port ~= nil then
  -- ...
end
```

**替换 `UI.push_popup(game, payload)`**:
```lua
-- 原代码
UI.push_popup(game, payload)

-- 新代码
if game.ui_port then
  game.ui_port:push_popup(payload)
end
```

#### 步骤3: 删除文件
确认所有调用点都已替换后，删除 `src/gameplay/ui_port.lua` 文件。

#### 步骤4: 验证
运行测试确保功能正常：
```bash
lua tests/deps_check.lua
lua tests/regression.lua
```

---

## 2. 合并重复的 dispatch() 函数

### 问题描述
`dispatch()` 函数在 `choice_resolver.lua`、`effect_pipeline.lua` 和 `item_phase.lua` 中重复出现，完全相同的实现。

### 当前代码
```lua
-- 三个文件中的相同实现
local function dispatch(game, payload)
  if not payload then return end
  local intent = payload.intent or payload
  if intent.kind == "need_choice" and intent.choice_spec then
    Choice.open(game, intent.choice_spec)
  elseif intent.kind == "push_popup" and intent.payload then
    UI.push_popup(game, intent.payload)
  end
end
```

### 修复步骤

#### 步骤1: 创建工具模块
创建 `src/util/intent_dispatcher.lua`:

```lua
local Choice = require("src.gameplay.choice")

local IntentDispatcher = {}

function IntentDispatcher.dispatch(game, payload)
  if not payload then return end
  local intent = payload.intent or payload
  if intent.kind == "need_choice" and intent.choice_spec then
    Choice.open(game, intent.choice_spec)
  elseif intent.kind == "push_popup" and intent.payload then
    if game.ui_port then
      game.ui_port:push_popup(intent.payload)
    end
  end
end

return IntentDispatcher
```

#### 步骤2: 更新调用文件

**更新 `src/gameplay/choice_resolver.lua`**:
```lua
-- 在文件顶部添加
local IntentDispatcher = require("src.util.intent_dispatcher")

-- 删除原有的 dispatch 函数定义
-- 更新调用点
-- 原代码: dispatch(game, payload)
-- 新代码: IntentDispatcher.dispatch(game, payload)
```

**更新 `src/gameplay/effect_pipeline.lua`**:
```lua
-- 在文件顶部添加
local IntentDispatcher = require("src.util.intent_dispatcher")

-- 删除原有的 dispatch 函数定义
-- 更新调用点
-- 原代码: dispatch(game, payload)
-- 新代码: IntentDispatcher.dispatch(game, payload)
```

**更新 `src/gameplay/item_phase.lua`**:
```lua
-- 在文件顶部添加
local IntentDispatcher = require("src.util.intent_dispatcher")

-- 删除原有的 dispatch 函数定义
-- 更新调用点
-- 原代码: dispatch(game, payload)
-- 新代码: IntentDispatcher.dispatch(game, payload)
```

#### 步骤3: 验证
运行测试确保功能正常：
```bash
lua tests/deps_check.lua
lua tests/regression.lua
```

---

## 3. 内联 choice.lua 到调用点

### 问题描述
`choice.lua` 是一个仅有44行代码的包装层，只提供了三个简单的 store 操作函数，没有实际的业务逻辑。

### 当前代码
```lua
-- src/gameplay/choice.lua
local Choice = {}

function Choice.get(game)
  if not game or not game.store then
    return nil
  end
  return game.store:get({ "turn", "pending_choice" })
end

function Choice.clear(game)
  if not game or not game.store then
    return
  end
  game.store:set({ "turn", "pending_choice" }, nil)
end

function Choice.open(game, payload)
  -- ... 实现细节
  game.store:set({ "turn", "pending_choice" }, entry)
  return entry
end

return Choice
```

### 修复步骤

#### 步骤1: 查找所有调用点
搜索所有 `Choice.get`、`Choice.clear` 和 `Choice.open` 的使用位置。

#### 步骤2: 替换调用代码

**替换 `Choice.get(game)`**:
```lua
-- 原代码
local choice = Choice.get(game)

-- 新代码
local choice = game.store:get({ "turn", "pending_choice" })
```

**替换 `Choice.clear(game)`**:
```lua
-- 原代码
Choice.clear(game)

-- 新代码
game.store:set({ "turn", "pending_choice" }, nil)
```

**替换 `Choice.open(game, spec)`**:
```lua
-- 原代码
Choice.open(game, spec)

-- 新代码
-- 需要复制 choice.lua 中的实现逻辑，或者直接使用 store 操作
game.store:set({ "turn", "pending_choice" }, spec)
```

#### 步骤3: 删除文件
确认所有调用点都已替换后，删除 `src/gameplay/choice.lua` 文件。

#### 步骤4: 验证
运行测试确保功能正常：
```bash
lua tests/deps_check.lua
lua tests/regression.lua
```

---

## 4. 删除 landing_resolver.lua 薄层

### 问题描述
`landing_resolver.lua` 是一个仅有57行代码的薄层，只被 `turn_land.lua` 调用一次，仅仅是为了传递固定的参数给 `effect_pipeline.lua`。

### 当前代码
```lua
-- src/gameplay/landing_resolver.lua
local landing_effects = require("src.gameplay.landing")
local EffectPipeline = require("src.gameplay.effect_pipeline")

local LandingResolver = {}

function LandingResolver.resolve(game, player, tile, move_result)
  return EffectPipeline.run(game, player, tile, move_result, {
    include_optional = false,
    include_auto_buy = true,
  })
end

return LandingResolver
```

### 修复步骤

#### 步骤1: 更新 turn_land.lua
修改 `src/gameplay/turn_land.lua`:

```lua
-- 原代码
local LandingResolver = require("src.gameplay.landing_resolver")

local function phase_land(tm, args)
  local player = args.player
  local move_result = args.move_result
  local tile = tm.game.board:get_tile(player.position)

  local res = LandingResolver.resolve(tm.game, player, tile, move_result)
  -- ...
end

-- 新代码
local EffectPipeline = require("src.gameplay.effect_pipeline")
local landing_effects = require("src.gameplay.landing")

local function phase_land(tm, args)
  local player = args.player
  local move_result = args.move_result
  local tile = tm.game.board:get_tile(player.position)

  local res = EffectPipeline.run(landing_effects.defs, {
    game = tm.game,
    player = player,
    tile = tile,
    move_result = move_result,
  }, {
    include_optional = false,
    include_auto_buy = true,
  })
  -- ...
end
```

#### 步骤2: 删除文件
确认 `turn_land.lua` 已更新后，删除 `src/gameplay/landing_resolver.lua` 文件。

#### 步骤3: 验证
运行测试确保功能正常：
```bash
lua tests/deps_check.lua
lua tests/regression.lua
```

---

## 5. 提取 as_number() 到工具模块

### 问题描述
`as_number()` 函数在 `choice_resolver.lua` 和 `market_service.lua` 中重复实现。

### 当前代码
```lua
-- 两个文件中的相同实现
local function as_number(v)
  if type(v) == "number" then
    return v
  end
  if type(v) == "string" then
    return tonumber(v)
  end
  return nil
end
```

### 修复步骤

#### 步骤1: 创建工具模块
创建 `src/util/convert.lua`:

```lua
local Convert = {}

function Convert.to_number(v)
  if type(v) == "number" then
    return v
  end
  if type(v) == "string" then
    return tonumber(v)
  end
  return nil
end

return Convert
```

#### 步骤2: 更新调用文件

**更新 `src/gameplay/choice_resolver.lua`**:
```lua
-- 在文件顶部添加
local Convert = require("src.util.convert")

-- 删除原有的 as_number 函数定义
-- 更新调用点
-- 原代码: as_number(value)
-- 新代码: Convert.to_number(value)
```

**更新 `src/gameplay/market_service.lua`**:
```lua
-- 在文件顶部添加
local Convert = require("src.util.convert")

-- 删除原有的 as_number 函数定义
-- 更新调用点
-- 原代码: as_number(value)
-- 新代码: Convert.to_number(value)
```

#### 步骤3: 验证
运行测试确保功能正常：
```bash
lua tests/deps_check.lua
lua tests/regression.lua
```

---

## 6. 拆分 choice_resolver.lua

### 问题描述
`choice_resolver.lua` 文件过大（442行），包含了21个处理函数，职责过重。

### 修复步骤

#### 步骤1: 设计新结构
```
src/gameplay/choice_service.lua (主入口)
src/gameplay/choice_handlers/
├── land_choice_handler.lua
├── market_choice_handler.lua
├── item_choice_handler.lua
└── optional_effect_handler.lua
```

#### 步骤2: 创建处理器模块

**创建 `src/gameplay/choice_handlers/land_choice_handler.lua`**:
```lua
local Choice = require("src.gameplay.choice")
local Effect = require("src.gameplay.effect")
local logger = require("src.util.logger")

local LandChoiceHandler = {}

function LandChoiceHandler.handle_optional_landing_effect(game, choice, action)
  -- 移植原有实现
end

return LandChoiceHandler
```

#### 步骤3: 创建主服务模块
创建 `src/gameplay/choice_service.lua`:

```lua
local Choice = require("src.gameplay.choice")
local LandChoiceHandler = require("src.gameplay.choice_handlers.land_choice_handler")
local MarketChoiceHandler = require("src.gameplay.choice_handlers.market_choice_handler")
-- 导入其他处理器

local ChoiceService = {}

local handlers = {
  landing_optional_effect = LandChoiceHandler.handle_optional_landing_effect,
  land_optional_effect = LandChoiceHandler.handle_optional_landing_effect,
  -- 注册其他处理器
}

function ChoiceService.resolve(game, choice, action)
  if not game or not choice then
    return { stay = false }
  end

  local handler = handlers[choice.kind]
  if handler then
    return handler(game, choice, action)
  end

  -- 处理其他情况
end

return ChoiceService
```

#### 步骤4: 更新调用点
将原来引用 `choice_resolver.lua` 的地方改为引用 `choice_service.lua`。

#### 步骤5: 删除原文件
确认所有调用点都已更新后，删除 `src/gameplay/choice_resolver.lua`。

#### 步骤6: 验证
运行测试确保功能正常：
```bash
lua tests/deps_check.lua
lua tests/regression.lua
```

---

## 7. 简化 agent.lua 嵌套逻辑

### 问题描述
`agent.lua` 中的 `pick_remote_dice_value` 函数存在深层嵌套，可读性较差。

### 当前代码
```lua
function Agent.pick_remote_dice_value(game, player, dice_count)
  dice_count = dice_count or 1
  local best_value, best_rank, best_score, best_tile
  for value = 1, 6 do
    local steps = value * dice_count
    local sim = simulate_landing(game, player, steps)
    local rank, score = remote_priority(game, player, sim)
    if rank then
      if (not best_rank)
        or rank < best_rank
        or (rank == best_rank and (score or 0) > (best_score or -math.huge)) then
        best_rank = rank
        best_score = score
        best_value = value
        best_tile = sim.tile
      end
    end
  end
  return best_value, best_tile
end
```

### 修复步骤

#### 步骤1: 使用提前返回减少嵌套
```lua
function Agent.pick_remote_dice_value(game, player, dice_count)
  dice_count = dice_count or 1
  local best_value, best_rank, best_score, best_tile
  
  for value = 1, 6 do
    local steps = value * dice_count
    local sim = simulate_landing(game, player, steps)
    local rank, score = remote_priority(game, player, sim)
    
    -- 提前返回条件检查
    if not rank then
      goto continue
    end
    
    if not best_rank 
       or rank < best_rank
       or (rank == best_rank and (score or 0) > (best_score or -math.huge)) then
      best_rank = rank
      best_score = score
      best_value = value
      best_tile = sim.tile
    end
    
    ::continue::
  end
  
  return best_value, best_tile
end
```

或者更好的方式是重构为更清晰的结构：

```lua
function Agent.pick_remote_dice_value(game, player, dice_count)
  dice_count = dice_count or 1
  local best = nil
  
  for value = 1, 6 do
    local steps = value * dice_count
    local sim = simulate_landing(game, player, steps)
    local rank, score = remote_priority(game, player, sim)
    
    -- 跳过无效排名
    if not rank then
      continue
    end
    
    -- 初始化最佳选择
    if not best then
      best = { rank = rank, score = score, value = value, tile = sim.tile }
      continue
    end
    
    -- 比较并更新最佳选择
    if rank < best.rank 
       or (rank == best.rank and (score or 0) > (best.score or -math.huge)) then
      best = { rank = rank, score = score, value = value, tile = sim.tile }
    end
  end
  
  return best and best.value, best and best.tile
end
```

#### 步骤2: 添加注释说明算法意图
```lua
--[[
  AI决策函数：选择遥控骰子的最佳点数
  
  算法思路：
  1. 模拟每个骰子点数(1-6)对应的移动结果
  2. 为每个落点计算优先级(rank)和得分(score)
  3. 选择优先级最高且得分最高的点数
  
  优先级规则(rank)：
  1. 道具格(最高优先级)
  2. 机会格
  3. 无主土地
  4. 自己的土地
  5. 起点格
  6. 商店格
  7. 山脉格
  8. 税收格
  9. 医院格
  10. 他人土地(最低优先级，得分是负租金)
  
  得分规则(score)：
  - 对于他人土地：负的租金金额
  - 其他格子：移动步数
]]
function Agent.pick_remote_dice_value(game, player, dice_count)
  -- 实现代码...
end
```

#### 步骤3: 验证
运行测试确保功能正常：
```bash
lua tests/deps_check.lua
lua tests/regression.lua
```

---

## 总结

通过以上详细的修复建议，我们可以逐步改善代码质量，使其更符合 AGENTS.md 的原则：

1. **删除不必要的抽象层**：消除单调用点的包装层
2. **消除代码重复**：提取公共函数到工具模块
3. **简化复杂逻辑**：减少嵌套，提高可读性
4. **拆分大文件**：使模块职责更清晰
5. **保持简洁**：遵循 Lua 简单原则

每一步修改都应该伴随着充分的测试验证，确保功能不受影响。
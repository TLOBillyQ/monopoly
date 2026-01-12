# 代码优化详细分析

## 1. 重复代码分析

### 1.1 get_service 函数重复 (6 次)

**发现位置**:
- src/gameplay/domain/item.lua
- src/gameplay/domain/chance.lua
- src/gameplay/domain/land.lua
- src/gameplay/domain/landing.lua
- src/gameplay/app/choice_resolver.lua
- src/gameplay/app/landing_resolver.lua

**当前实现**:
```lua
-- 在每个文件中重复出现
local function get_service(game, key)
  if game and game.services then
    return game.services[key]
  end
end

local function status_service(game)
  return get_service(game, "status")
end

local function bankruptcy_service(game)
  return get_service(game, "bankruptcy")
end
```

**优化方案** - 创建 `src/util/services.lua`:
```lua
local Services = {}

function Services.get(game, key)
  return game and game.services and game.services[key]
end

function Services.status(game)
  return Services.get(game, "status")
end

function Services.bankruptcy(game)
  return Services.get(game, "bankruptcy")
end

function Services.tile(game)
  return Services.get(game, "tile")
end

function Services.movement(game)
  return Services.get(game, "movement")
end

function Services.item(game)
  return Services.get(game, "item")
end

function Services.market(game)
  return Services.get(game, "market")
end

function Services.chance(game)
  return Services.get(game, "chance")
end

return Services
```

**节省**: ~72 行 (每个文件节省 12 行 × 6 个文件)

### 1.2 tile_state 函数重复 (3 次)

**发现位置**:
- src/gameplay/domain/item.lua (98-107 行)
- src/gameplay/domain/land.lua (7-16 行)
- src/gameplay/app/services/tile_service.lua

**当前实现**:
```lua
local function tile_state(game, tile)
  if not game or not game.store or not tile or tile.type ~= "land" then
    return { owner_id = nil, level = 0 }
  end
  local s = game.store:get({ "board", "tiles", tile.id })
  if type(s) ~= "table" then
    return { owner_id = nil, level = 0 }
  end
  return { owner_id = s.owner_id, level = s.level or 0 }
end
```

**优化方案** - 创建 `src/util/game_state.lua`:
```lua
local GameState = {}

function GameState.tile_state(game, tile)
  if not game or not game.store or not tile or tile.type ~= "land" then
    return { owner_id = nil, level = 0 }
  end
  local s = game.store:get({ "board", "tiles", tile.id })
  if type(s) ~= "table" then
    return { owner_id = nil, level = 0 }
  end
  return { owner_id = s.owner_id, level = s.level or 0 }
end

function GameState.total_invested(tile, owner_id, level)
  if not owner_id then
    return 0
  end
  level = level or 0
  local price = tile.price or 0
  return price * ((2 ^ (level + 1)) - 1)
end

return GameState
```

**节省**: ~30 行 (3 个重复 × 10 行)

## 2. item.lua 优化分析 (747 行)

### 2.1 表驱动的道具效果配置

**当前问题**: post_consume_handlers 包含大量相似函数

**示例当前代码**:
```lua
post_consume_handlers[2001] = function(game, player, _context)
  game:set_player_status(player, "pending_free_rent", true)
  logger.event(player.name .. " 使用免费卡，下一次租金免除")
  return true
end

post_consume_handlers[2002] = function(game, player, _context)
  local dice_count = player.seat_id and constants.dice_with_vehicle or constants.default_dice_count
  local values = {}
  for i = 1, dice_count do
    values[i] = 6
  end
  game:set_player_status(player, "pending_remote_dice", { values = values })
  logger.event(player.name .. " 使用遥控骰子，设定点数 " .. table.concat(values, ","))
  return true
end

post_consume_handlers[2003] = function(game, player, _context)
  game:set_player_status(player, "pending_dice_multiplier", 2)
  logger.event(player.name .. " 使用骰子加倍卡，本次步数翻倍")
  return true
end

post_consume_handlers[2010] = function(game, player, _context)
  game:set_player_status(player, "pending_tax_free", true)
  logger.event(player.name .. " 使用免税卡，本次征税免除")
  return true
end

post_consume_handlers[2017] = function(game, player)
  local status = status_service(game)
  if not status then
    logger.warn("缺少 StatusService，无法附身财神")
    return false
  end
  status.apply_deity(player, "rich")
  return true
end

post_consume_handlers[2019] = function(game, player)
  local status = status_service(game)
  if not status then
    logger.warn("缺少 StatusService，无法附身天使")
    return false
  end
  status.apply_deity(player, "angel")
  return true
end
```

**优化方案**:
```lua
local Services = require("src.util.services")

-- 配置化的道具效果
local ITEM_EFFECTS = {
  [2001] = { 
    type = "set_status", 
    key = "pending_free_rent", 
    value = true,
    message = "使用免费卡，下一次租金免除"
  },
  [2002] = { 
    type = "remote_dice",
    message = "使用遥控骰子"
  },
  [2003] = { 
    type = "set_status", 
    key = "pending_dice_multiplier", 
    value = 2,
    message = "使用骰子加倍卡，本次步数翻倍"
  },
  [2010] = { 
    type = "set_status", 
    key = "pending_tax_free", 
    value = true,
    message = "使用免税卡，本次征税免除"
  },
  [2017] = { 
    type = "deity", 
    deity = "rich",
    message = "附身财神"
  },
  [2019] = { 
    type = "deity", 
    deity = "angel",
    message = "附身天使"
  },
}

-- 通用处理器
local effect_handlers = {
  set_status = function(game, player, config)
    game:set_player_status(player, config.key, config.value)
    return true
  end,
  
  remote_dice = function(game, player, config)
    local dice_count = player.seat_id and constants.dice_with_vehicle or constants.default_dice_count
    local values = {}
    for i = 1, dice_count do
      values[i] = 6
    end
    game:set_player_status(player, "pending_remote_dice", { values = values })
    return true
  end,
  
  deity = function(game, player, config)
    local status = Services.status(game)
    if not status then
      logger.warn("缺少 StatusService，无法附身" .. config.deity)
      return false
    end
    status.apply_deity(player, config.deity)
    return true
  end,
}

-- 统一的道具使用函数
local function apply_post_consume_effect(game, player, item_id)
  local config = ITEM_EFFECTS[item_id]
  if not config then
    return false
  end
  
  local handler = effect_handlers[config.type]
  if not handler then
    return false
  end
  
  local success = handler(game, player, config)
  if success and config.message then
    logger.event(player.name .. " " .. config.message)
  end
  
  return success
end
```

**节省**: ~100 行 (从 ~150 行减少到 ~50 行)

### 2.2 合并目标查找逻辑

**当前代码**:
```lua
-- find_monster_target (118-137 行)
function ItemEffects.find_monster_target(game, player, distance)
  distance = distance or 3
  local board = game.board
  local best_idx = nil
  local best_value = nil
  for _, idx in ipairs(indices_in_range(board, player.position, distance)) do
    local tile = board:get_tile(idx)
    if tile.type == "land" then
      local st = tile_state(game, tile)
      if (st.level or 0) > 0 and st.owner_id and st.owner_id ~= player.id then
        local value = total_invested(tile, st.owner_id, st.level)
        if not best_value or value > best_value then
          best_value = value
          best_idx = idx
        end
      end
    end
  end
  return best_idx
end

-- find_missile_target (163-183 行)
find_missile_target = function(game, player, distance)
  distance = distance or 3
  local board = game.board
  local best_idx = nil
  local best_value = nil
  for _, idx in ipairs(indices_in_range(board, player.position, distance)) do
    if idx ~= player.position then
      local tile = board:get_tile(idx)
      local val = 0
      if tile.type == "land" then
        local st = tile_state(game, tile)
        val = total_invested(tile, st.owner_id, st.level)
      end
      if not best_value or val > best_value then
        best_value = val
        best_idx = idx
      end
    end
  end
  return best_idx
end
```

**优化方案**:
```lua
local GameState = require("src.util.game_state")

-- 通用的目标查找函数
local function find_best_target(game, player, distance, filter_fn)
  distance = distance or 3
  local board = game.board
  local best_idx = nil
  local best_value = nil
  
  for _, idx in ipairs(indices_in_range(board, player.position, distance)) do
    if filter_fn(idx, player.position) then
      local tile = board:get_tile(idx)
      local value = 0
      
      if tile.type == "land" then
        local st = GameState.tile_state(game, tile)
        value = GameState.total_invested(tile, st.owner_id, st.level)
      end
      
      if not best_value or value > best_value then
        best_value = value
        best_idx = idx
      end
    end
  end
  
  return best_idx
end

-- 怪兽卡：只攻击有建筑的他人地块
function ItemEffects.find_monster_target(game, player, distance)
  return find_best_target(game, player, distance, function(idx, pos)
    local tile = game.board:get_tile(idx)
    if tile.type == "land" then
      local st = GameState.tile_state(game, tile)
      return (st.level or 0) > 0 and st.owner_id and st.owner_id ~= player.id
    end
    return false
  end)
end

-- 导弹卡：攻击任何位置（除了自己）
find_missile_target = function(game, player, distance)
  return find_best_target(game, player, distance, function(idx, pos)
    return idx ~= pos
  end)
end
```

**节省**: ~25 行 (从 ~45 行减少到 ~20 行)

## 3. chance.lua 优化分析 (245 行)

### 3.1 配置驱动的机会牌效果

**当前代码示例**:
```lua
handlers.add_cash = function(_, player, card)
  apply_cash_change(player, card.amount)
  logger.event(player.name .. " 获得 " .. card.amount .. " 金币")
end

handlers.pay_cash = function(game, player, card)
  apply_cash_change(player, -card.amount)
  logger.event(player.name .. " 支付 " .. card.amount .. " 金币")
  if player.cash < 0 then
    local bankruptcy = get_service(game, "bankruptcy")
    if not bankruptcy then
      return missing_service("BankruptcyService")
    end
    bankruptcy.eliminate(game, player)
  end
end

handlers.percent_pay_cash = function(game, player, card)
  local fee = math.floor(player.cash * (card.percent / 100))
  apply_cash_change(player, -fee)
  logger.event(player.name .. " 按比例支付 " .. fee .. " 金币")
  if player.cash < 0 then
    local bankruptcy = get_service(game, "bankruptcy")
    if not bankruptcy then
      return missing_service("BankruptcyService")
    end
    bankruptcy.eliminate(game, player)
  end
end
```

**优化方案**:
```lua
local Services = require("src.util.services")

-- 配置映射
local EFFECT_TYPES = {
  add_cash = "cash_change",
  pay_cash = "cash_change",
  percent_pay_cash = "percent_cash_change",
  pay_others = "distribute_cash",
  collect_from_others = "distribute_cash",
  -- ...
}

-- 通用现金变化处理
local function handle_cash_change(game, player, card, multiplier)
  multiplier = multiplier or 1
  local amount = card.amount * multiplier
  
  player:add_cash(amount)
  
  local action = amount > 0 and "获得" or "支付"
  logger.event(player.name .. " " .. action .. " " .. math.abs(amount) .. " 金币")
  
  if player.cash < 0 then
    local bankruptcy = Services.bankruptcy(game)
    if bankruptcy then
      bankruptcy.eliminate(game, player)
    end
  end
end

-- 统一的 handler
handlers.add_cash = function(game, player, card)
  handle_cash_change(game, player, card, 1)
end

handlers.pay_cash = function(game, player, card)
  handle_cash_change(game, player, card, -1)
end

handlers.percent_pay_cash = function(game, player, card)
  local fee = math.floor(player.cash * (card.percent / 100))
  local modified_card = { amount = fee }
  handle_cash_change(game, player, modified_card, -1)
end
```

**节省**: ~60 行 (减少重复的破产检查和日志记录)

## 4. 渲染层优化分析

### 4.1 love_layer.lua 模态对话框构建 (374 行)

**当前代码**:
```lua
function LoveLayer:sync_pending_choice_modal()
  -- ... 省略前置检查 ...
  
  local buttons = {}
  for _, opt in ipairs(pending.options or {}) do
    table.insert(buttons, {
      label = opt.label,
      on_click = function()
        if self.game and self.game.resolve_choice then
          self.game:resolve_choice(opt.id)
        end
      end,
    })
  end
  
  table.insert(buttons, {
    label = "取消",
    on_click = function()
      if self.game and self.game.resolve_choice then
        self.game:resolve_choice(nil)
      end
    end,
  })
  
  local modal_data = {
    title = pending.title or "请选择",
    body = pending.body or "",
    buttons = buttons,
    _pending_choice_id = pending.id,
  }
  
  self.modal:push(modal_data)
end
```

**优化方案** - 创建构建器:
```lua
-- src/adapters/love2d/modal_builder.lua
local ModalBuilder = {}
ModalBuilder.__index = ModalBuilder

function ModalBuilder.new(modal)
  return setmetatable({ modal = modal, data = {} }, ModalBuilder)
end

function ModalBuilder:title(text)
  self.data.title = text
  return self
end

function ModalBuilder:body(text)
  self.data.body = text
  return self
end

function ModalBuilder:options(opts, callback)
  self.data.buttons = self.data.buttons or {}
  for _, opt in ipairs(opts) do
    table.insert(self.data.buttons, {
      label = opt.label,
      on_click = function() callback(opt.id) end
    })
  end
  return self
end

function ModalBuilder:cancel(callback)
  table.insert(self.data.buttons or {}, {
    label = "取消",
    on_click = callback
  })
  return self
end

function ModalBuilder:meta(key, value)
  self.data[key] = value
  return self
end

function ModalBuilder:show()
  self.modal:push(self.data)
end

-- 使用示例
function LoveLayer:sync_pending_choice_modal()
  -- ... 省略前置检查 ...
  
  ModalBuilder.new(self.modal)
    :title(pending.title or "请选择")
    :body(pending.body or "")
    :options(pending.options, function(id)
      if self.game and self.game.resolve_choice then
        self.game:resolve_choice(id)
      end
    end)
    :cancel(function()
      if self.game and self.game.resolve_choice then
        self.game:resolve_choice(nil)
      end
    end)
    :meta("_pending_choice_id", pending.id)
    :show()
end
```

**节省**: ~40 行 (在 love_layer.lua 中的多个相似模态创建)

## 5. 配置文件优化

### 5.1 items.lua 紧凑化 (232 行)

**当前格式**:
```lua
{
  id = 2001,
  name = "免费卡",
  tier = 1,
  shop_currency = "广告",
  shop_price = 1,
  weight = 1000,
  angel_immune = false,
  timing = "rent_prompt",
  usage = "确认使用，免除本次租金",
  description = "停留在其他玩家地块时，可使用免费卡免交本次租金。",
},
```

**优化格式** (使用默认值和更紧凑的表示):
```lua
-- 建立默认值系统
local DEFAULTS = {
  tier = 1,
  weight = 1000,
  angel_immune = false,
  shop_currency = "金币",
}

-- 紧凑格式
{ id = 2001, name = "免费卡", shop = {"广告", 1}, timing = "rent_prompt",
  desc = "停留在其他玩家地块时，可使用免费卡免交本次租金。" },
```

**使用合并函数**:
```lua
local function merge_defaults(item)
  for k, v in pairs(DEFAULTS) do
    if item[k] == nil then
      item[k] = v
    end
  end
  -- 处理 shop 简写
  if item.shop then
    item.shop_currency = item.shop[1]
    item.shop_price = item.shop[2]
    item.shop = nil
  end
  return item
end
```

**节省**: ~50 行 (每个道具节省 2-3 行 × 20 个道具)

## 总结

### 预计总节省
| 优化项目 | 节省行数 |
|---------|---------|
| 提取 get_service | 72 |
| 提取 tile_state | 30 |
| item.lua 表驱动 | 100 |
| item.lua 目标查找 | 25 |
| chance.lua 统一处理 | 60 |
| 模态对话框构建器 | 40 |
| items.lua 紧凑化 | 50 |
| 其他小优化 | 100+ |
| **合计** | **~477+ 行** |

加上其他未详细列出的优化（服务层、回合管理等），预计总共可减少 **700-1,000 行**。

### 优化原则

1. **DRY (Don't Repeat Yourself)**: 提取重复代码
2. **数据驱动**: 用配置替代代码
3. **单一职责**: 每个函数做一件事
4. **早期返回**: 减少嵌套
5. **合并相似**: 用参数区分相似函数

### 下一步

建议按照路线图逐步实施这些优化，每个阶段后进行充分测试。

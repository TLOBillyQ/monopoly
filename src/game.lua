
local CompositionRoot = require("src.gameplay.composition_root")
local Tables = require("src.util.tables")
local gameplay_constants = require("src.gameplay.constants")
local Tile = require("src.core.tile")
local Pricing = require("src.gameplay.land_pricing")

---@class Game
---游戏主协调类，管理所有游戏逻辑、状态、玩家和棋盘
local Game = {}
Game.__index = Game

local deep_copy = Tables.deep_copy
local tile_state = Tile.get_state

local function store_value(v)
  if type(v) == "table" then
    return deep_copy(v)
  end
  return v
end

---计算玩家总资产（现金+地产评估价值）
---@param game Game
---@param player Player
---@return number 总资产
local function total_assets(game, player)
  local total = player.cash or 0
  for tile_id in pairs(player.properties or {}) do
    local tile = game.board:get_tile_by_id(tile_id)
    if tile and tile.type == "land" then
      local ok, st = pcall(tile_state, game, tile)
      local level = 0
      if ok and type(st) == "table" then
        level = st.level
      end
      total = total + Pricing.total_invested(tile, level)
    end
  end
  return total
end

---从玩家列表生成胜者名字（用中文分号连接）
---@param list Player[]
---@return string 名字字符串
local function winner_names(list)
  local names = {}
  for _, player in ipairs(list or {}) do
    table.insert(names, player.name)
  end
  return table.concat(names, "、")
end

---更新游戏胜者信息
---@param game Game
---@param winners Player[] 胜者列表
---@param message string? 事件日志消息
---@return boolean 总是返回true
local function apply_winners(game, winners, message)
  game.winners = winners
  if #winners == 1 then
    game.winner = winners[1]
  else
    game.winner = nil
  end
  local names = winner_names(winners)
  if names ~= "" then
    game.winner_names = names
  else
    game.winner_names = nil
  end
  if message then
    if game.winner_names then
      game.logger.event(message, game.winner_names)
    else
      game.logger.event(message)
    end
  end
  game.finished = true
  return true
end

---创建新游戏实例
---@param opts table 配置选项表（players/ai/seed等）
---@return Game 新游戏实例
function Game.new(opts)
  return CompositionRoot.assemble(opts, Game)
end


---内部方法：将值持久化到状态树
---@param self Game
---@param path table 状态路径数组
---@param value any 要存储的值
function Game:_store_set(path, value)
  if self.store then
    self.store:set(path, store_value(value))
  end
end


---设置玩家状态标志
---@param self Game
---@param player Player 目标玩家
---@param key string 状态键名（如"stay_turns"、"deity"等）
---@param value any 状态值
function Game:set_player_status(player, key, value)
  player.status[key] = value
  self:_store_set({ "players", player.id, "status", key }, value)
end


---设置玩家座位ID
---@param self Game
---@param player Player
---@param seat_id number 座位ID
function Game:set_player_seat(player, seat_id)
  player.seat_id = seat_id
  self:_store_set({ "players", player.id, "seat_id" }, seat_id)
end


---设置玩家是否出局
---@param self Game
---@param player Player
---@param eliminated boolean 是否出局
function Game:set_player_eliminated(player, eliminated)
  player.eliminated = eliminated == true
  self:_store_set({ "players", player.id, "eliminated" }, player.eliminated)
end


---更新玩家地产所有权
---@param self Game
---@param player Player
---@param tile_id string|number 地块ID
---@param owned boolean 是否拥有
function Game:set_player_property(player, tile_id, owned)
  if owned then
    player.properties[tile_id] = true
  else
    player.properties[tile_id] = nil
  end
  local store_value = nil
  if owned then
    store_value = true
  end
  self:_store_set({ "players", player.id, "properties", tile_id }, store_value)
end


---同步玩家背包到状态树
---@param self Game
---@param player Player
function Game:sync_player_inventory(player)
  if player.inventory then
    self:_store_set({ "players", player.id, "inventory" }, CompositionRoot.snapshot_inventory(player.inventory))
  end
end


---更新地块状态（仅限地产类地块）
---@param self Game
---@param tile Tile 地块对象
---@param updates table 更新字段表（如{level=1, owner_id=2}）
function Game:update_tile(tile, updates)
  if not (tile and tile.type == "land" and updates) then
    return
  end
  for key, value in pairs(updates) do
    self:_store_set({ "board", "tiles", tile.id, key }, value)
  end
end


---将动画负载加入队列，生成序列号
---@param self Game
---@param payload table 动画负载
---@return table? 带seq字段的负载，或nil
function Game:queue_action_anim(payload)
  if not (payload and self.store) then
    return nil
  end
  local seq = (self.store:get({ "turn", "action_anim_seq" }) or 0) + 1
  payload.seq = seq
  self.store:set({ "turn", "action_anim_seq" }, seq)
  self.store:set({ "turn", "action_anim" }, payload)
  return payload
end


---设置地块所有者，并通知UI
---@param self Game
---@param tile Tile 地块对象
---@param owner_id number? 所有者ID，nil表示无主
function Game:set_tile_owner(tile, owner_id)
  if not (tile and tile.type == "land") then
    return
  end
  local ui_port = self.ui_port
  if ui_port and ui_port.on_tile_owner_changed then
    ui_port:on_tile_owner_changed(tile.id, owner_id)
  end
  if owner_id == nil then
    self:_store_set({ "board", "tiles", tile.id, "owner_id" }, nil)
  else
    self:update_tile(tile, { owner_id = owner_id })
  end
end


---设置地块等级
---@param self Game
---@param tile Tile 地块对象
---@param level number 等级
function Game:set_tile_level(tile, level)
  self:update_tile(tile, { level = level })
end


---重置地块（清除所有者和等级）
---@param self Game
---@param tile Tile 地块对象
function Game:reset_tile(tile)
  if not (tile and tile.type == "land") then
    return
  end
  local ui_port = self.ui_port
  if ui_port and ui_port.on_tile_owner_changed then
    ui_port:on_tile_owner_changed(tile.id, nil)
  end
  self:_store_set({ "board", "tiles", tile.id, "owner_id" }, nil)
  self:_store_set({ "board", "tiles", tile.id, "level" }, 0)
end


---获取所有存活的玩家
---@param self Game
---@return Player[] 存活玩家列表
function Game:alive_players()
  local alive = {}
  for _, p in ipairs(self.players) do
    if not p.eliminated then
      table.insert(alive, p)
    end
  end
  return alive
end

---获取当前轮次的活跃玩家
---@param self Game
---@return Player 当前玩家对象
function Game:current_player()
  local idx = self.store:get({ "turn", "current_player_index" }) or 1
  return self.players[idx]
end

---重建占位表（根据当前玩家位置）
---@param self Game
function Game:rebuild()
  self.occupants = {}
  for _, p in ipairs(self.players) do
    if not p.eliminated then
      local idx = p.position
      self.occupants[idx] = self.occupants[idx] or {}
      table.insert(self.occupants[idx], p.id)
    end
  end
end

---更新玩家位置，维护占位表
---@param self Game
---@param player Player 玩家对象
---@param new_index number 新位置索引
function Game:update_player_position(player, new_index)
  for _, list in pairs(self.occupants) do
    for i = #list, 1, -1 do
      if list[i] == player.id then
        table.remove(list, i)
      end
    end
  end
  player.position = new_index
  self:_store_set({ "players", player.id, "position" }, new_index)
  self.occupants[new_index] = self.occupants[new_index] or {}
  table.insert(self.occupants[new_index], player.id)
end


---检查游戏是否已结束（根据存活人数或时间限制）
---@param self Game
---@return boolean 游戏是否结束
function Game:check_victory()
  if self.finished then
    return true
  end
  local alive = self:alive_players()
  local turn_limit = gameplay_constants.turn_limit or 0
  if turn_limit > 0 and self.store then
    local turn_count = self.store:get({ "turn", "turn_count" }) or 0
    if turn_count >= turn_limit then
      if #alive == 0 then
        return apply_winners(self, {}, "游戏结束，无人生还")
      end
      local winners = {}
      local best = nil
      for _, player in ipairs(alive) do
        local assets = total_assets(self, player)
        if best == nil or assets > best then
          best = assets
          winners = { player }
        elseif assets == best then
          table.insert(winners, player)
        end
      end
      return apply_winners(self, winners, "游戏结束，时间到，胜者:")
    end
  end
  if #alive <= 1 then
    if #alive == 1 then
      return apply_winners(self, { alive[1] }, "游戏结束，胜者:")
    end
    return apply_winners(self, {}, "游戏结束，无人生还")
  end
  return false
end

---推进回合（运行回合管理器）
---@param self Game
function Game:advance_turn()
  if self.finished then
    return
  end
  if self.turn_manager then
    self.turn_manager:run_turn()
  end
  self:check_victory()
end

---分发玩家行动到回合管理器
---@param self Game
---@param action table 行动对象
function Game:dispatch_action(action)
  if self.finished then
    return
  end
  if self.turn_manager then
    self.turn_manager:dispatch(action)
  end
  self:check_victory()
end

---获取特定服务实例
---@param self Game
---@param key string 服务键（如"movement"、"market"等）
---@param context table? 上下文（优先级高于全局services）
---@return any 服务对象或nil
function Game:get_service(key, context)
  if context and context.services and context.services[key] then
    return context.services[key]
  end
  return self.services and self.services[key]
end

---获取所有服务
---@param self Game
---@param context table? 上下文（优先级高于全局services）
---@return table 服务表
function Game:get_services(context)
  if context and context.services then
    return context.services
  end
  return self.services
end

function Game:pending_choice()
  if self.store then
    return self.store:get({ "turn", "pending_choice" })
  end
end

return Game

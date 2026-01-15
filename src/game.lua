-- Game：游戏运行时门面
-- 职责：领域写操作、状态查询、流程驱动
-- 装配：由 CompositionRoot.assemble() 完成

local CompositionRoot = require("src.gameplay.composition_root")
local Tables = require("src.util.tables")

local Game = {}
Game.__index = Game

local deep_copy = Tables.deep_copy

local function store_value(v)
  if type(v) == "table" then
    return deep_copy(v)
  end
  return v
end

-- 创建游戏实例（装配由 CompositionRoot 完成）
function Game.new(opts)
  return CompositionRoot.assemble(opts, Game)
end

-- ========== 领域写操作 ==========

function Game:_store_set(path, value)
  if self.store then
    self.store:set(path, store_value(value))
  end
end


function Game:set_player_status(player, key, value)
  player.status[key] = value
  self:_store_set({ "players", player.id, "status", key }, value)
end


function Game:set_player_seat(player, seat_id)
  player.seat_id = seat_id
  self:_store_set({ "players", player.id, "seat_id" }, seat_id)
end


function Game:set_player_eliminated(player, eliminated)
  player.eliminated = eliminated and true or false
  self:_store_set({ "players", player.id, "eliminated" }, player.eliminated)
end


function Game:set_player_property(player, tile_id, owned)
  if owned then
    player.properties[tile_id] = true
  else
    player.properties[tile_id] = nil
  end
  self:_store_set({ "players", player.id, "properties", tile_id }, owned and true or nil)
end


function Game:sync_player_inventory(player)
  if player.inventory then
    self:_store_set({ "players", player.id, "inventory" }, CompositionRoot.snapshot_inventory(player.inventory))
  end
end


function Game:set_tile_owner(tile, owner_id)
  if tile and tile.type == "land" then
    self:_store_set({ "board", "tiles", tile.id, "owner_id" }, owner_id)
  end
end


function Game:set_tile_level(tile, level)
  if tile and tile.type == "land" then
    self:_store_set({ "board", "tiles", tile.id, "level" }, level)
  end
end


function Game:reset_tile(tile)
  if tile and tile.type == "land" then
    self:_store_set({ "board", "tiles", tile.id, "owner_id" }, nil)
    self:_store_set({ "board", "tiles", tile.id, "level" }, 0)
  end
end

-- ========== 状态查询 ==========

function Game:alive_players()
  local alive = {}
  for _, p in ipairs(self.players) do
    if not p.eliminated then
      table.insert(alive, p)
    end
  end
  return alive
end

function Game:current_player()
  local idx = self.store:get({ "turn", "current_player_index" }) or 1
  return self.players[idx]
end

function Game:rebuild_occupants()
  self.occupants = {}
  for _, p in ipairs(self.players) do
    if not p.eliminated then
      local idx = p.position
      self.occupants[idx] = self.occupants[idx] or {}
      table.insert(self.occupants[idx], p.id)
    end
  end
end

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

-- ========== 流程驱动 ==========

function Game:check_victory()
  if self.finished then
    return true
  end
  local alive = self:alive_players()
  if #alive <= 1 then
    if #alive == 1 then
      self.logger.event("游戏结束，胜者:", alive[1].name)
      self.winner = alive[1]
    else
      self.logger.event("游戏结束，无人生还")
    end
    self.finished = true
    return true
  end
  return false
end

function Game:advance_turn()
  if self.finished then
    return
  end
  if self.turn_manager then
    self.turn_manager:run_turn()
  end
  self:check_victory()
end

function Game:dispatch_action(action)
  if self.finished then
    return
  end
  if self.turn_manager then
    self.turn_manager:dispatch(action)
  end
  self:check_victory()
end

function Game:pending_choice()
  if self.store then
    return self.store:get({ "turn", "pending_choice" })
  end
end

return Game

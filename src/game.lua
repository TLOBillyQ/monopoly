
local CompositionRoot = require("src.gameplay.composition_root")
local Tables = require("src.util.tables")
local gameplay_constants = require("src.gameplay.constants")
local Tile = require("src.core.tile")
local Pricing = require("src.gameplay.land_pricing")

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

local function winner_names(list)
  local names = {}
  for _, player in ipairs(list or {}) do
    table.insert(names, player.name)
  end
  return table.concat(names, "、")
end

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

function Game.new(opts)
  return CompositionRoot.assemble(opts, Game)
end


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
  player.eliminated = eliminated == true
  self:_store_set({ "players", player.id, "eliminated" }, player.eliminated)
end


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


function Game:sync_player_inventory(player)
  if player.inventory then
    self:_store_set({ "players", player.id, "inventory" }, CompositionRoot.snapshot_inventory(player.inventory))
  end
end


function Game:update_tile(tile, updates)
  if not (tile and tile.type == "land" and updates) then
    return
  end
  for key, value in pairs(updates) do
    self:_store_set({ "board", "tiles", tile.id, key }, value)
  end
end


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


function Game:set_tile_level(tile, level)
  self:update_tile(tile, { level = level })
end


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

function Game:get_service(key, context)
  if context and context.services and context.services[key] then
    return context.services[key]
  end
  return self.services and self.services[key]
end

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

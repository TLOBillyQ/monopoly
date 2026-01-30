local CompositionRoot = require("Manager.GameManager.CompositionRoot")
local Tables = require("Library.Monopoly.Tables")

local GameState = {}

local deep_copy = Tables.deep_copy

local function store_value(v)
  if type(v) == "table" then
    return deep_copy(v)
  end
  return v
end

function GameState:_store_set(path, value)
  if self.store then
    self.store:set(path, store_value(value))
  end
end

function GameState:set_player_status(player, key, value)
  player.status[key] = value
  self:_store_set({ "players", player.id, "status", key }, value)
end

function GameState:set_player_seat(player, seat_id)
  player.seat_id = seat_id
  self:_store_set({ "players", player.id, "seat_id" }, seat_id)
end

function GameState:set_player_eliminated(player, eliminated)
  player.eliminated = eliminated == true
  self:_store_set({ "players", player.id, "eliminated" }, player.eliminated)
end

function GameState:set_player_property(player, tile_id, owned)
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

function GameState:sync_player_inventory(player)
  if player.inventory then
    self:_store_set({ "players", player.id, "inventory" }, CompositionRoot.snapshot_inventory(player.inventory))
  end
end

function GameState:update_tile(tile, updates)
  if not (tile and tile.type == "land" and updates) then
    return
  end
  for key, value in pairs(updates) do
    self:_store_set({ "board", "tiles", tile.id, key }, value)
  end
end

function GameState:queue_action_anim(payload)
  if not (payload and self.store) then
    return nil
  end
  local seq = (self.store:get({ "turn", "action_anim_seq" }) or 0) + 1
  payload.seq = seq
  self.store:set({ "turn", "action_anim_seq" }, seq)
  self.store:set({ "turn", "action_anim" }, payload)
  return payload
end

function GameState:set_tile_owner(tile, owner_id)
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

function GameState:set_tile_level(tile, level)
  self:update_tile(tile, { level = level })
end

function GameState:reset_tile(tile)
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

function GameState:alive_players()
  local alive = {}
  for _, p in ipairs(self.players) do
    if not p.eliminated then
      table.insert(alive, p)
    end
  end
  return alive
end

function GameState:current_player()
  local idx = self.store:get({ "turn", "current_player_index" }) or 1
  return self.players[idx]
end

function GameState:rebuild()
  self.occupants = {}
  for _, p in ipairs(self.players) do
    if not p.eliminated then
      local idx = p.position
      self.occupants[idx] = self.occupants[idx] or {}
      table.insert(self.occupants[idx], p.id)
    end
  end
end

function GameState:update_player_position(player, new_index)
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

function GameState:pending_choice()
  if self.store then
    return self.store:get({ "turn", "pending_choice" })
  end
end

return GameState

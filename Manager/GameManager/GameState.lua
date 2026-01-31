local CompositionRoot = require("Manager.GameManager.CompositionRoot")
local Constants = require("Manager.GameManager.Constants")
require "Library.Utils"

local GameState = {}

local deep_copy = Utils.deep_copy
local StorePath = Constants.store_path_enum
local StorePathKey = Constants.store_path_key

local function sp(id)
  return StorePathKey[id]
end

local function normalize_tile_key(key)
  if type(key) == "number" then
    return StorePathKey[key] or key
  end
  return key
end

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
  self:_store_set({ sp(StorePath.players), player.id, sp(StorePath.status), key }, value)
end

function GameState:set_player_seat(player, seat_id)
  player.seat_id = seat_id
  self:_store_set({ sp(StorePath.players), player.id, sp(StorePath.seat_id) }, seat_id)
end

function GameState:set_player_eliminated(player, eliminated)
  player.eliminated = eliminated == true
  self:_store_set({ sp(StorePath.players), player.id, sp(StorePath.eliminated) }, player.eliminated)
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
  self:_store_set({ sp(StorePath.players), player.id, sp(StorePath.properties), tile_id }, store_value)
end

function GameState:sync_player_inventory(player)
  if player.inventory then
    self:_store_set({ sp(StorePath.players), player.id, sp(StorePath.inventory) }, CompositionRoot.snapshot_inventory(player.inventory))
  end
end

function GameState:update_tile(tile, updates)
  if not (tile and tile.type == "land" and updates) then
    return
  end
  for key, value in pairs(updates) do
    local store_key = normalize_tile_key(key)
    self:_store_set({ sp(StorePath.board), sp(StorePath.tiles), tile.id, store_key }, value)
  end
end

function GameState:queue_action_anim(payload)
  if not (payload and self.store) then
    return nil
  end
  local seq = (self.store:get({ sp(StorePath.turn), sp(StorePath.action_anim_seq) }) or 0) + 1
  payload.seq = seq
  self.store:set({ sp(StorePath.turn), sp(StorePath.action_anim_seq) }, seq)
  self.store:set({ sp(StorePath.turn), sp(StorePath.action_anim) }, payload)
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
    self:_store_set({ sp(StorePath.board), sp(StorePath.tiles), tile.id, sp(StorePath.owner_id) }, nil)
  else
    self:update_tile(tile, { [StorePath.owner_id] = owner_id })
  end
end

function GameState:set_tile_level(tile, level)
  self:update_tile(tile, { [StorePath.level] = level })
end

function GameState:reset_tile(tile)
  if not (tile and tile.type == "land") then
    return
  end
  local ui_port = self.ui_port
  if ui_port and ui_port.on_tile_owner_changed then
    ui_port:on_tile_owner_changed(tile.id, nil)
  end
  self:_store_set({ sp(StorePath.board), sp(StorePath.tiles), tile.id, sp(StorePath.owner_id) }, nil)
  self:_store_set({ sp(StorePath.board), sp(StorePath.tiles), tile.id, sp(StorePath.level) }, 0)
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
  local idx = self.store:get({ sp(StorePath.turn), sp(StorePath.current_player_index) }) or 1
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
  self:_store_set({ sp(StorePath.players), player.id, sp(StorePath.position) }, new_index)
  self.occupants[new_index] = self.occupants[new_index] or {}
  table.insert(self.occupants[new_index], player.id)
end

function GameState:pending_choice()
  if self.store then
    return self.store:get({ sp(StorePath.turn), sp(StorePath.pending_choice) })
  end
end

return GameState

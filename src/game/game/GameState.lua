local composition_root = require("src.game.game.CompositionRoot")
require "vendor.third_party.Utils"

local game_state = {}

local deep_copy = Utils.deep_copy

local function _store_value(v)
  if type(v) == "table" then
    return deep_copy(v)
  end
  return v
end

local function _bump_land_rent_version(self)
  self._land_rent_version = (self._land_rent_version or 0) + 1
end

function game_state:set_player_status(player, key, value)
  player.status[key] = value
  self.store:set({ "players", player.id, "status", key }, _store_value(value))
end

function game_state:set_player_seat(player, seat_id)
  player.seat_id = seat_id
  self.store:set({ "players", player.id, "seat_id" }, _store_value(seat_id))
end

function game_state:set_player_eliminated(player, eliminated)
  player.eliminated = eliminated == true
  self.store:set({ "players", player.id, "eliminated" }, player.eliminated)
end

function game_state:set_player_property(player, tile_id, owned)
  if owned then
    player.properties[tile_id] = true
  else
    player.properties[tile_id] = nil
  end
  self.store:set({ "players", player.id, "properties", tile_id }, owned and true or nil)
end

function game_state:sync_player_inventory(player)
  self.store:set(
    { "players", player.id, "inventory" },
    _store_value(composition_root.snapshot_inventory(player.inventory))
  )
end

function game_state:update_tile(tile, updates)
  assert(tile ~= nil and tile.type == "land", "invalid tile for update")
  for key, value in pairs(updates) do
    self.store:set({ "board", "tiles", tile.id, key }, _store_value(value))
  end
end

function game_state:queue_action_anim(payload)
  assert(payload ~= nil, "missing action anim payload")
  local seq = (self.store:get({ "turn", "action_anim_seq" }) or 0) + 1
  payload.seq = seq
  self.store:set({ "turn", "action_anim_seq" }, seq)
  self.store:set({ "turn", "action_anim" }, payload)
  return payload
end

function game_state:set_tile_owner(tile, owner_id)
  assert(tile ~= nil and tile.type == "land", "invalid tile for owner")
  _bump_land_rent_version(self)
  local ui_port = self.ui_port
  assert(ui_port ~= nil and ui_port.on_tile_owner_changed ~= nil, "missing ui_port")
  ui_port:on_tile_owner_changed(tile.id, owner_id)
  self:update_tile(tile, { owner_id = owner_id })
end

function game_state:set_tile_level(tile, level)
  _bump_land_rent_version(self)
  self:update_tile(tile, { level = level })
end

function game_state:reset_tile(tile)
  assert(tile ~= nil and tile.type == "land", "invalid tile for reset")
  _bump_land_rent_version(self)
  local ui_port = self.ui_port
  assert(ui_port ~= nil and ui_port.on_tile_owner_changed ~= nil, "missing ui_port")
  ui_port:on_tile_owner_changed(tile.id, nil)
  self.store:set({ "board", "tiles", tile.id, "owner_id" }, nil)
  self.store:set({ "board", "tiles", tile.id, "level" }, 0)
end

function game_state:alive_players()
  local alive = {}
  for _, p in ipairs(self.players) do
    if not p.eliminated then
      table.insert(alive, p)
    end
  end
  return alive
end

function game_state:current_player()
  local idx = self.store:get({ "turn", "current_player_index" })
  assert(idx ~= nil, "missing current_player_index")
  return self.players[idx]
end

function game_state:rebuild()
  local length = self.board:length()
  self.occupants = {}
  for i = 1, length do
    self.occupants[i] = {}
  end
  for _, p in ipairs(self.players) do
    if not p.eliminated then
      local idx = p.position
      table.insert(self.occupants[idx], p.id)
    end
  end
end

function game_state:update_player_position(player, new_index)
  for _, list in pairs(self.occupants) do
    for i = #list, 1, -1 do
      if list[i] == player.id then
        table.remove(list, i)
      end
    end
  end
  player.position = new_index
  self.store:set({ "players", player.id, "position" }, new_index)
  table.insert(self.occupants[new_index], player.id)
end

function game_state:pending_choice()
  return self.store:get({ "turn", "pending_choice" })
end

return game_state

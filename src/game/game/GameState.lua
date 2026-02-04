local composition_root = require("src.game.game.CompositionRoot")
require "vendor.third_party.Utils"

local game_state = {}

local deep_copy = Utils.deep_copy

local function _store_root(self)
  assert(self.store ~= nil, "missing store")
  return self.store.state
end

local function _store_set(self, path, value)
  assert(self.store ~= nil and self.store.set ~= nil, "missing store.set")
  self.store:set(path, value)
end

local function _ensure_table(node, key)
  assert(type(node[key]) == "table", "missing table: " .. tostring(key))
  return node[key]
end

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
  local root = _store_root(self)
  local players = _ensure_table(root, "players")
  local player_node = _ensure_table(players, player.id)
  local status = _ensure_table(player_node, "status")
  _store_set(self, { "players", player.id, "status", key }, _store_value(value))
end

function game_state:set_player_seat(player, seat_id)
  player.seat_id = seat_id
  local root = _store_root(self)
  local players = _ensure_table(root, "players")
  local player_node = _ensure_table(players, player.id)
  _store_set(self, { "players", player.id, "seat_id" }, _store_value(seat_id))
end

function game_state:set_player_eliminated(player, eliminated)
  player.eliminated = eliminated == true
  local root = _store_root(self)
  local players = _ensure_table(root, "players")
  local player_node = _ensure_table(players, player.id)
  _store_set(self, { "players", player.id, "eliminated" }, _store_value(player.eliminated))
end

function game_state:set_player_property(player, tile_id, owned)
  if owned then
    player.properties[tile_id] = true
  else
    player.properties[tile_id] = nil
  end
  local store_value = nil
  if owned then
    store_value = true
  end
  local root = _store_root(self)
  local players = _ensure_table(root, "players")
  local player_node = _ensure_table(players, player.id)
  local properties = _ensure_table(player_node, "properties")
  _store_set(self, { "players", player.id, "properties", tile_id }, store_value)
end

function game_state:sync_player_inventory(player)
  local root = _store_root(self)
  local players = _ensure_table(root, "players")
  local player_node = _ensure_table(players, player.id)
  _store_set(self, { "players", player.id, "inventory" }, _store_value(composition_root.snapshot_inventory(player.inventory)))
end

function game_state:update_tile(tile, updates)
  assert(tile ~= nil and tile.type == "land", "invalid tile for update")
  assert(updates ~= nil, "missing tile updates")
  local root = _store_root(self)
  local board = _ensure_table(root, "board")
  local tiles = _ensure_table(board, "tiles")
  _ensure_table(tiles, tile.id)
  for key, value in pairs(updates) do
    _store_set(self, { "board", "tiles", tile.id, key }, _store_value(value))
  end
end

function game_state:queue_action_anim(payload)
  assert(payload ~= nil, "missing action anim payload")
  local root = _store_root(self)
  local turn = _ensure_table(root, "turn")
  local seq = turn["action_anim_seq"] + 1
  payload.seq = seq
  _store_set(self, { "turn", "action_anim_seq" }, seq)
  _store_set(self, { "turn", "action_anim" }, payload)
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
  local root = _store_root(self)
  local board = _ensure_table(root, "board")
  local tiles = _ensure_table(board, "tiles")
  _ensure_table(tiles, tile.id)
  _store_set(self, { "board", "tiles", tile.id, "owner_id" }, nil)
  _store_set(self, { "board", "tiles", tile.id, "level" }, 0)
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
  local root = _store_root(self)
  local turn = _ensure_table(root, "turn")
  local idx = turn["current_player_index"]
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
  local root = _store_root(self)
  local players = _ensure_table(root, "players")
  local player_node = _ensure_table(players, player.id)
  _store_set(self, { "players", player.id, "position" }, _store_value(new_index))
  table.insert(self.occupants[new_index], player.id)
end

function game_state:pending_choice()
  local root = _store_root(self)
  local turn = _ensure_table(root, "turn")
  return turn["pending_choice"]
end

return game_state

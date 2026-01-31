local CompositionRoot = require("Manager.GameManager.CompositionRoot")
require "Library.Utils"

local GameState = {}

local deep_copy = Utils.deep_copy

local function store_root(self)
  if self.store then
    return self.store.state
  end
end

local function ensure_table(node, key)
  if type(node[key]) ~= "table" then
    node[key] = {}
  end
  return node[key]
end

local function store_value(v)
  if type(v) == "table" then
    return deep_copy(v)
  end
  return v
end

function GameState:set_player_status(player, key, value)
  player.status[key] = value
  local root = store_root(self)
  if not root then
    return
  end
  local players = ensure_table(root, "players")
  local player_node = ensure_table(players, player.id)
  local status = ensure_table(player_node, "status")
  status[key] = store_value(value)
end

function GameState:set_player_seat(player, seat_id)
  player.seat_id = seat_id
  local root = store_root(self)
  if not root then
    return
  end
  local players = ensure_table(root, "players")
  local player_node = ensure_table(players, player.id)
  player_node["seat_id"] = store_value(seat_id)
end

function GameState:set_player_eliminated(player, eliminated)
  player.eliminated = eliminated == true
  local root = store_root(self)
  if not root then
    return
  end
  local players = ensure_table(root, "players")
  local player_node = ensure_table(players, player.id)
  player_node["eliminated"] = store_value(player.eliminated)
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
  local root = store_root(self)
  if not root then
    return
  end
  local players = ensure_table(root, "players")
  local player_node = ensure_table(players, player.id)
  local properties = ensure_table(player_node, "properties")
  properties[tile_id] = store_value
end

function GameState:sync_player_inventory(player)
  if player.inventory then
    local root = store_root(self)
    if not root then
      return
    end
    local players = ensure_table(root, "players")
    local player_node = ensure_table(players, player.id)
    player_node["inventory"] = store_value(CompositionRoot.snapshot_inventory(player.inventory))
  end
end

function GameState:update_tile(tile, updates)
  if not (tile and tile.type == "land" and updates) then
    return
  end
  local root = store_root(self)
  if not root then
    return
  end
  local board = ensure_table(root, "board")
  local tiles = ensure_table(board, "tiles")
  local tile_node = ensure_table(tiles, tile.id)
  for key, value in pairs(updates) do
    tile_node[key] = store_value(value)
  end
end

function GameState:queue_action_anim(payload)
  if not (payload and self.store) then
    return nil
  end
  local root = store_root(self)
  local turn = ensure_table(root, "turn")
  local seq = (turn["action_anim_seq"] or 0) + 1
  payload.seq = seq
  turn["action_anim_seq"] = seq
  turn["action_anim"] = payload
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
    local root = store_root(self)
    if not root then
      return
    end
    local board = ensure_table(root, "board")
    local tiles = ensure_table(board, "tiles")
    local tile_node = ensure_table(tiles, tile.id)
    tile_node["owner_id"] = nil
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
  local root = store_root(self)
  if not root then
    return
  end
  local board = ensure_table(root, "board")
  local tiles = ensure_table(board, "tiles")
  local tile_node = ensure_table(tiles, tile.id)
  tile_node["owner_id"] = nil
  tile_node["level"] = 0
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
  local root = self.store.state
  local turn = root["turn"]
  local idx = 1
  if type(turn) == "table" then
    idx = turn["current_player_index"] or 1
  end
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
  local root = store_root(self)
  if not root then
    return
  end
  local players = ensure_table(root, "players")
  local player_node = ensure_table(players, player.id)
  player_node["position"] = store_value(new_index)
  self.occupants[new_index] = self.occupants[new_index] or {}
  table.insert(self.occupants[new_index], player.id)
end

function GameState:pending_choice()
  if self.store then
    local root = self.store.state
    local turn = root["turn"]
    if type(turn) ~= "table" then
      return nil
    end
    return turn["pending_choice"]
  end
end

return GameState

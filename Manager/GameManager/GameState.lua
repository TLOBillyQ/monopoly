local CompositionRoot = require("Manager.GameManager.CompositionRoot")
require "Library.Utils"

local GameState = {}

local deep_copy = Utils.deep_copy

local function _StoreRoot(self)
  assert(self.store ~= nil, "missing store")
  return self.store.state
end

local function _EnsureTable(node, key)
  assert(type(node[key]) == "table", "missing table: " .. tostring(key))
  return node[key]
end

local function _StoreValue(v)
  if type(v) == "table" then
    return deep_copy(v)
  end
  return v
end

function GameState:SetPlayerStatus(player, key, value)
  player.status[key] = value
  local root = _StoreRoot(self)
  local players = _EnsureTable(root, "players")
  local player_node = _EnsureTable(players, player.id)
  local status = _EnsureTable(player_node, "status")
  status[key] = _StoreValue(value)
end

function GameState:SetPlayerSeat(player, seat_id)
  player.seat_id = seat_id
  local root = _StoreRoot(self)
  local players = _EnsureTable(root, "players")
  local player_node = _EnsureTable(players, player.id)
  player_node["seat_id"] = _StoreValue(seat_id)
end

function GameState:SetPlayerEliminated(player, eliminated)
  player.eliminated = eliminated == true
  local root = _StoreRoot(self)
  local players = _EnsureTable(root, "players")
  local player_node = _EnsureTable(players, player.id)
  player_node["eliminated"] = _StoreValue(player.eliminated)
end

function GameState:SetPlayerProperty(player, tile_id, owned)
  if owned then
    player.properties[tile_id] = true
  else
    player.properties[tile_id] = nil
  end
  local store_value = nil
  if owned then
    store_value = true
  end
  local root = _StoreRoot(self)
  local players = _EnsureTable(root, "players")
  local player_node = _EnsureTable(players, player.id)
  local properties = _EnsureTable(player_node, "properties")
  properties[tile_id] = store_value
end

function GameState:SyncPlayerInventory(player)
  local root = _StoreRoot(self)
  local players = _EnsureTable(root, "players")
  local player_node = _EnsureTable(players, player.id)
  player_node["inventory"] = _StoreValue(CompositionRoot.SnapshotInventory(player.inventory))
end

function GameState:UpdateTile(tile, updates)
  assert(tile ~= nil and tile.type == "land", "invalid tile for update")
  assert(updates ~= nil, "missing tile updates")
  local root = _StoreRoot(self)
  local board = _EnsureTable(root, "board")
  local tiles = _EnsureTable(board, "tiles")
  local tile_node = _EnsureTable(tiles, tile.id)
  for key, value in pairs(updates) do
    tile_node[key] = _StoreValue(value)
  end
end

function GameState:QueueActionAnim(payload)
  assert(payload ~= nil, "missing action anim payload")
  local root = _StoreRoot(self)
  local turn = _EnsureTable(root, "turn")
  local seq = turn["action_anim_seq"] + 1
  payload.seq = seq
  turn["action_anim_seq"] = seq
  turn["action_anim"] = payload
  return payload
end

function GameState:SetTileOwner(tile, owner_id)
  assert(tile ~= nil and tile.type == "land", "invalid tile for owner")
  local ui_port = self.ui_port
  assert(ui_port ~= nil and ui_port.OnTileOwnerChanged ~= nil, "missing ui_port")
  ui_port:OnTileOwnerChanged(tile.id, owner_id)
  self:UpdateTile(tile, { owner_id = owner_id })
end

function GameState:SetTileLevel(tile, level)
  self:UpdateTile(tile, { level = level })
end

function GameState:ResetTile(tile)
  assert(tile ~= nil and tile.type == "land", "invalid tile for reset")
  local ui_port = self.ui_port
  assert(ui_port ~= nil and ui_port.OnTileOwnerChanged ~= nil, "missing ui_port")
  ui_port:OnTileOwnerChanged(tile.id, nil)
  local root = _StoreRoot(self)
  local board = _EnsureTable(root, "board")
  local tiles = _EnsureTable(board, "tiles")
  local tile_node = _EnsureTable(tiles, tile.id)
  tile_node["owner_id"] = nil
  tile_node["level"] = 0
end

function GameState:AlivePlayers()
  local alive = {}
  for _, p in ipairs(self.players) do
    if not p.eliminated then
      table.insert(alive, p)
    end
  end
  return alive
end

function GameState:CurrentPlayer()
  local root = _StoreRoot(self)
  local turn = _EnsureTable(root, "turn")
  local idx = turn["current_player_index"]
  assert(idx ~= nil, "missing current_player_index")
  return self.players[idx]
end

function GameState:Rebuild()
  local length = self.board:Length()
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

function GameState:UpdatePlayerPosition(player, new_index)
  for _, list in pairs(self.occupants) do
    for i = #list, 1, -1 do
      if list[i] == player.id then
        table.remove(list, i)
      end
    end
  end
  player.position = new_index
  local root = _StoreRoot(self)
  local players = _EnsureTable(root, "players")
  local player_node = _EnsureTable(players, player.id)
  player_node["position"] = _StoreValue(new_index)
  table.insert(self.occupants[new_index], player.id)
end

function GameState:PendingChoice()
  local root = _StoreRoot(self)
  local turn = _EnsureTable(root, "turn")
  return turn["pending_choice"]
end

return GameState

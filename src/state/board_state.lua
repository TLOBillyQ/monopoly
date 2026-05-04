local game_state_tiles = {}

local function _bump_land_rent_version(self)
  self._land_rent_version = (self._land_rent_version or 0) + 1
end

local function _mark_board(self)
  self.dirty.any = true
  self.dirty.board_tiles = true
end

local function _sync_board_visual(self, payload)
  if not self then
    return false
  end
  local board_visual_feedback_port = self.board_visual_feedback_port
  if board_visual_feedback_port == nil and type(self.ensure_board_visual_feedback_port) == "function" then
    board_visual_feedback_port = self:ensure_board_visual_feedback_port()
  end
  if not (type(board_visual_feedback_port) == "table" and type(board_visual_feedback_port.sync_many) == "function") then
    return false
  end
  local ok, handled = pcall(board_visual_feedback_port.sync_many, self, payload)
  if not ok then
    return false
  end
  return handled == true
end

local function _notify_tile_owner_changed(self, tile_id, owner_id)
  local notifier = self and self.tile_owner_notifier or nil
  if notifier and type(notifier.notify_owner_changed) == "function" then
    notifier:notify_owner_changed(tile_id, owner_id)
    return true
  end
  if notifier and type(notifier.on_tile_owner_changed) == "function" then
    notifier:on_tile_owner_changed(tile_id, owner_id)
    return true
  end
  return false
end

function game_state_tiles.update_tile(self, tile, updates)
  assert(tile ~= nil and tile.type == "land", "invalid tile for update")
  for key, value in pairs(updates) do
    tile[key] = value
  end
  _mark_board(self)
end

local function _collect_affected_owner_ids(...)
  local out = {}
  local seen = {}
  for i = 1, select("#", ...) do
    local owner_id = select(i, ...)
    if owner_id ~= nil and not seen[owner_id] then
      seen[owner_id] = true
      out[#out + 1] = owner_id
    end
  end
  return out
end

function game_state_tiles.set_tile_owner(self, tile, owner_id)
  assert(tile ~= nil and tile.type == "land", "invalid tile for owner")
  local previous_owner_id = tile.owner_id
  _bump_land_rent_version(self)
  game_state_tiles.update_tile(self, tile, { owner_id = owner_id })
  _notify_tile_owner_changed(self, tile.id, owner_id)
  _sync_board_visual(self, {
    tile_ids = { tile.id },
    affected_owner_ids = _collect_affected_owner_ids(previous_owner_id, owner_id),
  })
end

function game_state_tiles.set_tile_level(self, tile, level)
  _bump_land_rent_version(self)
  game_state_tiles.update_tile(self, tile, { level = level })
  if tile and tile.id ~= nil then
    _sync_board_visual(self, {
      tile_ids = { tile.id },
      affected_owner_ids = _collect_affected_owner_ids(tile.owner_id),
    })
  end
end

function game_state_tiles.reset_tile(self, tile)
  assert(tile ~= nil and tile.type == "land", "invalid tile for reset")
  local previous_owner_id = tile.owner_id
  _bump_land_rent_version(self)
  tile.owner_id = nil
  tile.level = 0
  _mark_board(self)
  _notify_tile_owner_changed(self, tile.id, nil)
  _sync_board_visual(self, {
    tile_ids = { tile.id },
    affected_owner_ids = _collect_affected_owner_ids(previous_owner_id),
  })
end

function game_state_tiles.place_roadblock(self, index)
  assert(self ~= nil and self.board ~= nil, "missing board")
  self.board:place_roadblock(index)
  _mark_board(self)
  _sync_board_visual(self, { overlay_indices = { index } })
end

function game_state_tiles.clear_roadblock(self, index)
  assert(self ~= nil and self.board ~= nil, "missing board")
  self.board:clear_roadblock(index)
  _mark_board(self)
  _sync_board_visual(self, { overlay_indices = { index } })
end

function game_state_tiles.place_mine(self, index, data)
  assert(self ~= nil and self.board ~= nil, "missing board")
  self.board:place_mine(index, data)
  _mark_board(self)
  _sync_board_visual(self, { overlay_indices = { index } })
end

function game_state_tiles.clear_mine(self, index)
  assert(self ~= nil and self.board ~= nil, "missing board")
  self.board:clear_mine(index)
  _mark_board(self)
  _sync_board_visual(self, { overlay_indices = { index } })
end

function game_state_tiles.clear_all_overlays(self, index)
  assert(self ~= nil and self.board ~= nil, "missing board")
  self.board:clear_all(index)
  _mark_board(self)
  _sync_board_visual(self, { overlay_indices = { index } })
end

return game_state_tiles

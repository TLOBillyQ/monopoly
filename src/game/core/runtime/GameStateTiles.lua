local game_state_tiles = {}

local function _bump_land_rent_version(self)
  self._land_rent_version = (self._land_rent_version or 0) + 1
end

local function _mark_board(self)
  self.dirty.any = true
  self.dirty.board_tiles = true
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
  local ui_port = self and self.ui_port or nil
  if ui_port and type(ui_port.on_tile_owner_changed) == "function" then
    ui_port:on_tile_owner_changed(tile_id, owner_id)
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

function game_state_tiles.set_tile_owner(self, tile, owner_id)
  assert(tile ~= nil and tile.type == "land", "invalid tile for owner")
  _bump_land_rent_version(self)
  _notify_tile_owner_changed(self, tile.id, owner_id)
  game_state_tiles.update_tile(self, tile, { owner_id = owner_id })
end

function game_state_tiles.set_tile_level(self, tile, level)
  _bump_land_rent_version(self)
  game_state_tiles.update_tile(self, tile, { level = level })
end

function game_state_tiles.reset_tile(self, tile)
  assert(tile ~= nil and tile.type == "land", "invalid tile for reset")
  _bump_land_rent_version(self)
  _notify_tile_owner_changed(self, tile.id, nil)
  tile.owner_id = nil
  tile.level = 0
  _mark_board(self)
end

return game_state_tiles

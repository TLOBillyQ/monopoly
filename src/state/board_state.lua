local dirty_tracker = require("src.state.dirty_tracker")

local game_state_tiles = {}

local function _bump_land_rent_version(self)
  self._land_rent_version = (self._land_rent_version or 0) + 1
end

local function _mark_board(self)
  dirty_tracker.mark(self.dirty, "board_tiles")
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

local function _update_tile(self, tile, updates)
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
  _update_tile(self, tile, { owner_id = owner_id })
  _notify_tile_owner_changed(self, tile.id, owner_id)
  _sync_board_visual(self, {
    tile_ids = { tile.id },
    affected_owner_ids = _collect_affected_owner_ids(previous_owner_id, owner_id),
  })
end

function game_state_tiles.set_tile_level(self, tile, level)
  _bump_land_rent_version(self)
  _update_tile(self, tile, { level = level })
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

local function _delegate_overlay(self, board_method, index, ...)
  assert(self ~= nil and self.board ~= nil, "missing board")
  self.board[board_method](self.board, index, ...)
  _mark_board(self)
  _sync_board_visual(self, { overlay_indices = { index } })
end

function game_state_tiles.place_roadblock(self, index)
  _delegate_overlay(self, "place_roadblock", index)
end

function game_state_tiles.clear_roadblock(self, index)
  _delegate_overlay(self, "clear_roadblock", index)
end

function game_state_tiles.place_mine(self, index, data)
  _delegate_overlay(self, "place_mine", index, data)
end

function game_state_tiles.clear_mine(self, index)
  _delegate_overlay(self, "clear_mine", index)
end

function game_state_tiles.clear_all_overlays(self, index)
  _delegate_overlay(self, "clear_all", index)
end

return game_state_tiles

--[[ mutate4lua-manifest
version=2
projectHash=9db46f18f4996141
scope.0.id=chunk:src/state/board_state.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=130
scope.0.semanticHash=3dbaec2290749962
scope.1.id=function:_bump_land_rent_version:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=7
scope.1.semanticHash=67a33f8a42513a0a
scope.2.id=function:_mark_board:9
scope.2.kind=function
scope.2.startLine=9
scope.2.endLine=11
scope.2.semanticHash=8fedd43a53fa15ad
scope.3.id=function:_sync_board_visual:13
scope.3.kind=function
scope.3.startLine=13
scope.3.endLine=29
scope.3.semanticHash=17a138a3670ddc06
scope.4.id=function:_notify_tile_owner_changed:31
scope.4.kind=function
scope.4.startLine=31
scope.4.endLine=42
scope.4.semanticHash=c7ba369d4c090c71
scope.5.id=function:game_state_tiles.set_tile_owner:65
scope.5.kind=function
scope.5.startLine=65
scope.5.endLine=75
scope.5.semanticHash=b4009e0d3cd2a39c
scope.6.id=function:game_state_tiles.set_tile_level:77
scope.6.kind=function
scope.6.startLine=77
scope.6.endLine=86
scope.6.semanticHash=337061d92cc9370b
scope.7.id=function:game_state_tiles.reset_tile:88
scope.7.kind=function
scope.7.startLine=88
scope.7.endLine=100
scope.7.semanticHash=b122152751d59a1a
scope.8.id=function:_delegate_overlay:102
scope.8.kind=function
scope.8.startLine=102
scope.8.endLine=107
scope.8.semanticHash=154f1480d254b51f
scope.9.id=function:game_state_tiles.place_roadblock:109
scope.9.kind=function
scope.9.startLine=109
scope.9.endLine=111
scope.9.semanticHash=ea974cd642604fa9
scope.10.id=function:game_state_tiles.clear_roadblock:113
scope.10.kind=function
scope.10.startLine=113
scope.10.endLine=115
scope.10.semanticHash=4bbba9108b20c1e1
scope.11.id=function:game_state_tiles.place_mine:117
scope.11.kind=function
scope.11.startLine=117
scope.11.endLine=119
scope.11.semanticHash=4f22d39c8128817d
scope.12.id=function:game_state_tiles.clear_mine:121
scope.12.kind=function
scope.12.startLine=121
scope.12.endLine=123
scope.12.semanticHash=9bd70297750c0b03
scope.13.id=function:game_state_tiles.clear_all_overlays:125
scope.13.kind=function
scope.13.startLine=125
scope.13.endLine=127
scope.13.semanticHash=dc38f23ee6960cc1
]]

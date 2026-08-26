local dirty_tracker = require("src.state.dirty_tracker")
local logger = require("src.foundation.log")

local game_state_tiles = {}

local function _bump_land_rent_version(self)
  self._land_rent_version = (self._land_rent_version or 0) + 1
end

local function _mark_board(self)
  dirty_tracker.mark(self.dirty, "board_tiles")
end

-- Returns the port only when it can actually sync; nil means "no visual feedback wired".
local function _resolve_board_visual_feedback_port(self)
  local board_visual_feedback_port = self.board_visual_feedback_port
  if type(board_visual_feedback_port) == "table" and type(board_visual_feedback_port.sync_many) == "function" then
    return board_visual_feedback_port
  end
  return nil
end

-- #551:同步失败留痕按「game 实例 × 失败类别」去重——坏装配下 tile 高频路径
-- 不刷屏,且 sink 不跨 game 泄漏。handled==false(no-op port / 无事可同步)是
-- headless 合法日常,不在此留痕。
local function _warn_sync_failure_once(self, key, ...)
  local sink = self._board_visual_sync_warned
  if sink == nil then
    sink = {}
    self._board_visual_sync_warned = sink
  end
  logger.log_once(sink, "warn", key, ...)
end

local function _sync_board_visual(self, payload)
  if not self then
    return false
  end
  local board_visual_feedback_port = _resolve_board_visual_feedback_port(self)
  if board_visual_feedback_port == nil then
    _warn_sync_failure_once(self, "no_port",
      "[board_state] visual sync dropped: board_visual_feedback_port not wired")
    return false
  end
  local ok, result = pcall(board_visual_feedback_port.sync_many, self, payload)
  if not ok then
    _warn_sync_failure_once(self, "sync_error",
      "[board_state] visual sync dropped: sync_many threw: " .. tostring(result))
    return false
  end
  return result == true
end

local function _notifier_of(self)
  return self and self.tile_owner_notifier or nil
end

local function _notify_owner_changed(notifier, tile_id, owner_id)
  if notifier and type(notifier.notify_owner_changed) == "function" then
    notifier:notify_owner_changed(tile_id, owner_id)
    return true
  end
  return false
end

local function _on_owner_changed(notifier, tile_id, owner_id)
  if notifier and type(notifier.on_tile_owner_changed) == "function" then
    notifier:on_tile_owner_changed(tile_id, owner_id)
    return true
  end
  return false
end

local function _notify_tile_owner_changed(self, tile_id, owner_id)
  local notifier = _notifier_of(self)
  if _notify_owner_changed(notifier, tile_id, owner_id) then
    return true
  end
  return _on_owner_changed(notifier, tile_id, owner_id)
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
version=4
projectHash=5a8c3fab02f68d15
scope.0.id=chunk:src/state/board_state.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=168
scope.0.semanticHash=5923e8f6f14ec58d
scope.1.id=function:_bump_land_rent_version
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=8
scope.1.semanticHash=c306e1585bec7d41
scope.2.id=function:_mark_board
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=12
scope.2.semanticHash=84b996fd1b689e65
scope.3.id=function:_resolve_board_visual_feedback_port
scope.3.kind=function
scope.3.startLine=15
scope.3.endLine=21
scope.3.semanticHash=56a3b6e04292a9f5
scope.4.id=function:_warn_sync_failure_once
scope.4.kind=function
scope.4.startLine=26
scope.4.endLine=33
scope.4.semanticHash=da0f6185a3d03c0f
scope.5.id=function:_sync_board_visual
scope.5.kind=function
scope.5.startLine=35
scope.5.endLine=52
scope.5.semanticHash=2e85caf4d0e1aba1
scope.6.id=function:_notifier_of
scope.6.kind=function
scope.6.startLine=54
scope.6.endLine=56
scope.6.semanticHash=616a2ca60599c94f
scope.7.id=function:_notify_owner_changed
scope.7.kind=function
scope.7.startLine=58
scope.7.endLine=64
scope.7.semanticHash=703ca8e10dae3754
scope.8.id=function:_on_owner_changed
scope.8.kind=function
scope.8.startLine=66
scope.8.endLine=72
scope.8.semanticHash=703ca8e10dae3754
scope.9.id=function:_notify_tile_owner_changed
scope.9.kind=function
scope.9.startLine=74
scope.9.endLine=80
scope.9.semanticHash=cfc8ec42a2d26cd3
scope.10.id=function:_update_tile
scope.10.kind=function
scope.10.startLine=82
scope.10.endLine=88
scope.10.semanticHash=c9a232781012a802
scope.11.id=function:_collect_affected_owner_ids
scope.11.kind=function
scope.11.startLine=90
scope.11.endLine=101
scope.11.semanticHash=8f04594b75040eb0
scope.12.id=function:game_state_tiles.set_tile_owner
scope.12.kind=function
scope.12.startLine=103
scope.12.endLine=113
scope.12.semanticHash=fb9101eb72524bf1
scope.13.id=function:game_state_tiles.set_tile_level
scope.13.kind=function
scope.13.startLine=115
scope.13.endLine=124
scope.13.semanticHash=69bda13c82422c96
scope.14.id=function:game_state_tiles.reset_tile
scope.14.kind=function
scope.14.startLine=126
scope.14.endLine=138
scope.14.semanticHash=5eaaa51c7519703a
scope.15.id=function:_delegate_overlay
scope.15.kind=function
scope.15.startLine=140
scope.15.endLine=145
scope.15.semanticHash=7bdf8eac62acc65f
scope.16.id=function:game_state_tiles.place_roadblock
scope.16.kind=function
scope.16.startLine=147
scope.16.endLine=149
scope.16.semanticHash=6cd55047a98a900e
scope.17.id=function:game_state_tiles.clear_roadblock
scope.17.kind=function
scope.17.startLine=151
scope.17.endLine=153
scope.17.semanticHash=6cd55047a98a900e
scope.18.id=function:game_state_tiles.place_mine
scope.18.kind=function
scope.18.startLine=155
scope.18.endLine=157
scope.18.semanticHash=a78865feb442dcda
scope.19.id=function:game_state_tiles.clear_mine
scope.19.kind=function
scope.19.startLine=159
scope.19.endLine=161
scope.19.semanticHash=6cd55047a98a900e
scope.20.id=function:game_state_tiles.clear_all_overlays
scope.20.kind=function
scope.20.startLine=163
scope.20.endLine=165
scope.20.semanticHash=6cd55047a98a900e
]]

local shared = require("src.ui.render.board.visual_sync_shared")
local tile_sync = require("src.ui.render.board.visual_sync_tile")
local overlay_sync = require("src.ui.render.board.visual_sync_overlay")

local visual_sync_batch = {}

local function _clear_table(t)
  for k in pairs(t) do t[k] = nil end
end

local function _append_unique(raw_list, out, seen)
  for _, value in ipairs(raw_list) do
    if value ~= nil and not seen[value] then
      seen[value] = true
      out[#out + 1] = value
    end
  end
end

local function _dedupe_into(raw_list, out, seen)
  _clear_table(out)
  _clear_table(seen)
  if type(raw_list) == "table" then
    _append_unique(raw_list, out, seen)
  end
  return out
end

local _norm_tiles = {}
local _norm_tiles_seen = {}
local _norm_overlays = {}
local _norm_overlays_seen = {}
local _norm_owners = {}
local _norm_owners_seen = {}
local _normalized = { tile_ids = _norm_tiles, overlay_indices = _norm_overlays, affected_owner_ids = _norm_owners }

local function _normalize_payload(payload)
  payload = payload or {}
  _normalized.tile_ids = _dedupe_into(payload.tile_ids, _norm_tiles, _norm_tiles_seen)
  _normalized.overlay_indices = _dedupe_into(payload.overlay_indices, _norm_overlays, _norm_overlays_seen)
  _normalized.affected_owner_ids = _dedupe_into(payload.affected_owner_ids, _norm_owners, _norm_owners_seen)
  return _normalized
end

local _expand_owner_set = {}
local _expand_tile_ids = {}

local function _build_owner_set(owner_ids)
  _clear_table(_expand_owner_set)
  for _, owner_id in ipairs(owner_ids) do
    _expand_owner_set[owner_id] = true
  end
  return _expand_owner_set
end

local function _is_owned_land_tile(tile, owner_set)
  return tile and tile.type == "land" and tile.owner_id and owner_set[tile.owner_id]
end

local function _collect_owned_land_tiles(path, owner_set, out)
  for _, tile in ipairs(path) do
    if _is_owned_land_tile(tile, owner_set) then
      out[#out + 1] = tile.id
    end
  end
  return out
end

local function _expand_affected_tiles(state, owner_ids)
  _clear_table(_expand_tile_ids)
  -- owner_ids 恒为 table(_normalize_payload 经 _dedupe_into 归一),`not owner_ids`
  -- 是死防御——or->and 变异体在空表下殊途同归不可杀(#262 删除)。
  if #owner_ids == 0 then
    return _expand_tile_ids
  end
  local board = shared.resolve_board(state)
  if not (board and type(board.path) == "table") then
    return _expand_tile_ids
  end
  local owner_set = _build_owner_set(owner_ids)
  return _collect_owned_land_tiles(board.path, owner_set, _expand_tile_ids)
end

local _sync_seen = {}

local function _sync_tile_dedup(state, tile_ids)
  local handled = false
  for _, tile_id in ipairs(tile_ids) do
    if tile_id ~= nil and not _sync_seen[tile_id] then
      _sync_seen[tile_id] = true
      if tile_sync.sync_tile_visual(state, tile_id) then handled = true end
    end
  end
  return handled
end

local function _sync_overlays(state, indices)
  local handled = false
  for _, board_index in ipairs(indices) do
    if overlay_sync.sync_overlay_visual(state, board_index) then
      handled = true
    end
  end
  return handled
end

function visual_sync_batch.sync_many(state, payload)
  local normalized = _normalize_payload(payload)
  for k in pairs(_sync_seen) do _sync_seen[k] = nil end
  local handled = _sync_tile_dedup(state, normalized.tile_ids)
  if _sync_tile_dedup(state, _expand_affected_tiles(state, normalized.affected_owner_ids)) then
    handled = true
  end
  if _sync_overlays(state, normalized.overlay_indices) then
    handled = true
  end
  return handled
end

return visual_sync_batch

--[[ mutate4lua-manifest
version=4
projectHash=f66d1633fdc5bba1
scope.0.id=chunk:src/ui/render/board/visual_sync_batch.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=121
scope.0.semanticHash=5e157a5a6a808340
scope.1.id=function:_clear_table
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=9
scope.1.semanticHash=b6c04f8e080b736d
scope.2.id=function:_append_unique
scope.2.kind=function
scope.2.startLine=11
scope.2.endLine=18
scope.2.semanticHash=e56035f32acd2f77
scope.3.id=function:_dedupe_into
scope.3.kind=function
scope.3.startLine=20
scope.3.endLine=27
scope.3.semanticHash=5add2309f31ba607
scope.4.id=function:_normalize_payload
scope.4.kind=function
scope.4.startLine=37
scope.4.endLine=43
scope.4.semanticHash=e4f72db7124f79c2
scope.5.id=function:_build_owner_set
scope.5.kind=function
scope.5.startLine=48
scope.5.endLine=54
scope.5.semanticHash=a601a166fc4ecaa0
scope.6.id=function:_is_owned_land_tile
scope.6.kind=function
scope.6.startLine=56
scope.6.endLine=58
scope.6.semanticHash=c3782fb29a6f6477
scope.7.id=function:_collect_owned_land_tiles
scope.7.kind=function
scope.7.startLine=60
scope.7.endLine=67
scope.7.semanticHash=ef0b154480add223
scope.8.id=function:_expand_affected_tiles
scope.8.kind=function
scope.8.startLine=69
scope.8.endLine=82
scope.8.semanticHash=b32c0186b0c1216f
scope.9.id=function:_sync_tile_dedup
scope.9.kind=function
scope.9.startLine=86
scope.9.endLine=95
scope.9.semanticHash=90291e0164a88f21
scope.10.id=function:_sync_overlays
scope.10.kind=function
scope.10.startLine=97
scope.10.endLine=105
scope.10.semanticHash=dc596bf29dfba2bb
scope.11.id=function:visual_sync_batch.sync_many
scope.11.kind=function
scope.11.startLine=107
scope.11.endLine=118
scope.11.semanticHash=6ebc6395a4ceb03f
]]

local runtime_state = require("src.ui.state.runtime")
local player_resolve = require("src.ui.render.board.player_resolve")
local placement_snap = require("src.ui.render.board.placement_snap")

local M = {}

local _resolve_player_id = player_resolve.resolve_player_id
local _resolve_active_player_base = player_resolve.resolve_active_player_base

local _snapshot_a = {}
local _snapshot_b = {}
local _snapshot_current = _snapshot_a

local function _build_snapshot(players)
  local snapshot = (_snapshot_current == _snapshot_a) and _snapshot_b or _snapshot_a
  _snapshot_current = snapshot
  for k in pairs(snapshot) do
    snapshot[k] = nil
  end
  for i, player in ipairs(players) do
    assert(player ~= nil, "missing player: " .. tostring(i))
    local pid = _resolve_player_id(player, i)
    local pos = player.position
    local eliminated = player.eliminated and 1 or 0
    snapshot[pid] = tostring(pos) .. ":" .. tostring(eliminated)
  end
  return snapshot
end

function M.compute_need_sync(state, snapshot)
  local board_runtime = runtime_state.ensure_board_runtime(state)
  local need_sync = board_runtime.board_sync_pending or false
  local last_positions = assert(board_runtime.board_last_positions, "missing board_runtime.board_last_positions")
  if not need_sync then
    for pid, value in pairs(snapshot) do
      if last_positions[pid] ~= value then
        need_sync = true
        break
      end
    end
  end
  return need_sync
end

local _occupants = {}

local function _reset_occupants()
  for k, v in pairs(_occupants) do
    if type(v) == "table" then
      for j = 1, #v do v[j] = nil end
    else
      _occupants[k] = nil
    end
  end
end

local function _append_occupant(state, player, i)
  local idx, _, pid = _resolve_active_player_base(state, player, i)
  local list = _occupants[idx]
  if not list then
    list = {}
    _occupants[idx] = list
  end
  list[#list + 1] = pid
end

function M.build_occupants(state, players)
  _reset_occupants()
  for i, player in ipairs(players) do
    assert(player ~= nil, "missing player: " .. tostring(i))
    if not player.eliminated then
      _append_occupant(state, player, i)
    end
  end
  return _occupants
end

M.resolve_min_player_y = placement_snap.resolve_min_player_y
M.place_players = placement_snap.place_players
M.build_snapshot = _build_snapshot

-- Exported for testing
M._resolve_occupant_slot = placement_snap._resolve_occupant_slot

return M

--[[ mutate4lua-manifest
version=2
projectHash=2eecf523e9ebebff
scope.0.id=chunk:src/ui/render/board/placement.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=86
scope.0.semanticHash=f39e445c7b689f9c
scope.0.lastMutatedAt=2026-07-07T02:46:59Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=survived
scope.0.lastMutationSites=35
scope.0.lastMutationKilled=34
scope.1.id=function:_append_occupant:57
scope.1.kind=function
scope.1.startLine=57
scope.1.endLine=65
scope.1.semanticHash=5467c1d482d8310f
scope.1.lastMutatedAt=2026-07-07T02:46:59Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=4
scope.1.lastMutationKilled=4
]]

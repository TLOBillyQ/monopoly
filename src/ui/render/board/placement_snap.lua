local board_geometry = require("src.config.gameplay.camera_follow")
local runtime_state = require("src.ui.state.runtime")
local runtime_constants = require("src.config.gameplay.runtime_constants")
local move_anim_debug = require("src.ui.render.move_anim.debug")
local move_anim = require("src.ui.render.move_anim")
local player_resolve = require("src.ui.render.board.player_resolve")

local M = {}

local _should_debug_log = move_anim_debug.enabled
local _debug_log = move_anim_debug.debug_log

local _resolve_player_id = player_resolve.resolve_player_id
local _resolve_active_player_base = player_resolve.resolve_active_player_base

local _stop_opts = {}

local function _stop_player_motion(pid, unit, stop_synthetic_ai)
  _stop_opts.stop_synthetic_ai = stop_synthetic_ai == true
  return move_anim.stop_player_presentation(pid, unit, _stop_opts)
end

function M.resolve_min_player_y(scene)
  assert(scene.ground ~= nil, "missing board_scene.ground")
  assert(scene.ground.get_position ~= nil, "missing board_scene.ground.get_position")
  local ground_pos = scene.ground.get_position()
  assert(ground_pos ~= nil and ground_pos.y ~= nil, "missing ground position")
  local board_cfg = board_geometry or {}
  local offset = board_cfg.player_min_ground_offset
  if offset == nil then
    offset = 0.5
  end
  return ground_pos.y + offset
end

local function _resolve_occupant_slot(list, pid)
  local count = list and #list or 1
  local slot = 1
  if list and count > 1 then
    for s = 1, count do
      if list[s] == pid then
        slot = s
        break
      end
    end
  end
  return slot, count
end

local function _calc_slot_offset(slot, count, spacing)
  if count <= 1 or spacing <= 0 then
    return 0.0, 0.0
  end
  local per_row = 0
  while per_row * per_row < count do
    per_row = per_row + 1
  end
  local row = math.floor((slot - 1) / per_row)
  local col = (slot - 1) % per_row
  local start = -(per_row - 1) * spacing * 0.5
  local ox = start + col * spacing
  local oz = start + row * spacing
  return ox, oz
end

local function _calc_y_offset(base_y, min_player_y)
  if base_y < min_player_y then
    return min_player_y - base_y
  end
  return 0
end

local function _resolve_target_position(base, y_offset, ox, oz)
  return base + math.Vector3(ox, y_offset, oz)
end

local _follow_opts = {}

local function _publish_follow_target(state, pid, target_pos, source)
  _follow_opts.source = source
  _follow_opts.seq = nil
  runtime_state.set_follow_target_position(state, pid, target_pos, _follow_opts)
end

local function _place_player_unit(pid, unit, target_pos)
  assert(unit.set_position ~= nil, "missing unit.set_position: " .. tostring(pid))
  unit.set_position(target_pos)
end

local _park_pos = runtime_constants.entity_pool_park_pos

local function _hide_eliminated_player(state, player, i)
  local pid = _resolve_player_id(player, i)
  local unit = state.player_units and state.player_units[pid] or nil
  if not unit then return end
  move_anim.clear_player_token(state.board_scene, pid, "board_sync_eliminated")
  _stop_player_motion(pid, unit, true)
  if type(unit.set_model_visible) == "function" then
    unit.set_model_visible(false)
  end
  if unit.set_position then
    unit.set_position(_park_pos)
  end
end

local function _stop_and_log_player_motion(state, pid, unit)
  move_anim.clear_player_token(state.board_scene, pid, "board_sync_place_players")
  return _stop_player_motion(pid, unit, true)
end

local function _log_stop_and_snap(pid, idx, stop_result, target_pos)
  if not _should_debug_log() then return end
  _debug_log(
    "board_refresh_stop_and_snap",
    "player_id=" .. tostring(pid),
    "position=" .. tostring(idx),
    "motion_stop=" .. tostring(stop_result.motion_stop_path or "none"),
    "ai_stop=" .. tostring(stop_result.ai_stop_path or "none"),
    "anim_stop=" .. tostring(stop_result.anim_stop_path or "none"),
    "target_pos=" .. tostring(target_pos)
  )
end

local function _place_single_player(state, player, i, occupants, spacing, min_player_y)
  local idx, base, pid = _resolve_active_player_base(state, player, i)
  assert(state.player_units ~= nil, "missing player_units")
  local unit = assert(state.player_units[pid], "missing player unit: " .. tostring(pid))
  local base_y = assert(base.y, "missing base.y: " .. tostring(idx))
  local y_offset = _calc_y_offset(base_y, min_player_y)
  local list = occupants[idx]
  local slot, count = _resolve_occupant_slot(list, pid)
  local ox, oz = _calc_slot_offset(slot, count, spacing)
  local target_pos = _resolve_target_position(base, y_offset, ox, oz)
  local stop_result = _stop_and_log_player_motion(state, pid, unit)
  _log_stop_and_snap(pid, idx, stop_result, target_pos)
  _place_player_unit(pid, unit, target_pos)
  _publish_follow_target(state, pid, target_pos, "board_sync_snap")
end

function M.place_players(state, players, occupants, spacing, min_player_y)
  for i, player in ipairs(players) do
    assert(player ~= nil, "missing player: " .. tostring(i))
    if not player.eliminated then
      _place_single_player(state, player, i, occupants, spacing, min_player_y)
    else
      _hide_eliminated_player(state, player, i)
    end
  end
end

-- Exported for testing
M._resolve_occupant_slot = _resolve_occupant_slot

return M

--[[ mutate4lua-manifest
version=2
projectHash=670996924db37637
scope.0.id=chunk:src/ui/render/board/placement_snap.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=155
scope.0.semanticHash=d1a85e4cbf816709
scope.1.id=function:_stop_player_motion:18
scope.1.kind=function
scope.1.startLine=18
scope.1.endLine=21
scope.1.semanticHash=ed266c880f72fa1e
scope.2.id=function:M.resolve_min_player_y:23
scope.2.kind=function
scope.2.startLine=23
scope.2.endLine=34
scope.2.semanticHash=5bc16e2e450021a6
scope.3.id=function:_calc_y_offset:66
scope.3.kind=function
scope.3.startLine=66
scope.3.endLine=71
scope.3.semanticHash=0d7a54786081b9bc
scope.4.id=function:_resolve_target_position:73
scope.4.kind=function
scope.4.startLine=73
scope.4.endLine=75
scope.4.semanticHash=16bc3717a1b5f5ba
scope.5.id=function:_publish_follow_target:79
scope.5.kind=function
scope.5.startLine=79
scope.5.endLine=83
scope.5.semanticHash=95d085f4a0d0380c
scope.6.id=function:_place_player_unit:85
scope.6.kind=function
scope.6.startLine=85
scope.6.endLine=88
scope.6.semanticHash=85ed1756b1aa0a09
scope.7.id=function:_hide_eliminated_player:92
scope.7.kind=function
scope.7.startLine=92
scope.7.endLine=104
scope.7.semanticHash=57707ce064228e10
scope.8.id=function:_stop_and_log_player_motion:106
scope.8.kind=function
scope.8.startLine=106
scope.8.endLine=109
scope.8.semanticHash=514607304163879b
scope.9.id=function:_log_stop_and_snap:111
scope.9.kind=function
scope.9.startLine=111
scope.9.endLine=122
scope.9.semanticHash=edb5d8220eed2edd
scope.10.id=function:_place_single_player:124
scope.10.kind=function
scope.10.startLine=124
scope.10.endLine=138
scope.10.semanticHash=f2f8c1c51108e460
]]

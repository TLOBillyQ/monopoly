local board_geometry = require("src.config.gameplay.camera_follow")
local runtime_state = require("src.ui.state.runtime")
local runtime_constants = require("src.config.gameplay.runtime_constants")
local move_anim_debug = require("src.ui.render.move_anim.debug")
local move_anim = require("src.ui.render.move_anim")

local M = {}

local _should_debug_log = move_anim_debug.enabled
local _debug_log = move_anim_debug.log

local _stop_opts = {}

local function _stop_player_motion(pid, unit, stop_synthetic_ai)
  _stop_opts.stop_synthetic_ai = stop_synthetic_ai == true
  return move_anim.stop_player_presentation(pid, unit, _stop_opts)
end

local function _resolve_player_id(player, i)
  return assert(player.id, "missing player id: " .. tostring(i))
end

local function _resolve_active_player_base(state, player, i)
  local idx = assert(player.position, "missing player position: " .. tostring(i))
  assert(state.tile_positions ~= nil, "missing tile_positions")
  local base = assert(state.tile_positions[idx], "missing tile_position: " .. tostring(idx))
  local pid = _resolve_player_id(player, i)
  return idx, base, pid
end

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

function M.build_occupants(state, players)
  for k, v in pairs(_occupants) do
    if type(v) == "table" then
      for j = 1, #v do v[j] = nil end
    else
      _occupants[k] = nil
    end
  end
  for i, player in ipairs(players) do
    assert(player ~= nil, "missing player: " .. tostring(i))
    if not player.eliminated then
      local idx, _, pid = _resolve_active_player_base(state, player, i)
      local list = _occupants[idx]
      if not list then
        list = {}
        _occupants[idx] = list
      end
      list[#list + 1] = pid
    end
  end
  return _occupants
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
  if _should_debug_log() then
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

M.build_snapshot = _build_snapshot

-- Exported for testing
M._resolve_occupant_slot = _resolve_occupant_slot

return M

--[[ mutate4lua-manifest
version=2
projectHash=394fb5dddda7a413
scope.0.id=chunk:src/ui/render/board/placement.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=222
scope.0.semanticHash=51d1d1d43963dea4
scope.1.id=function:_stop_player_motion:14
scope.1.kind=function
scope.1.startLine=14
scope.1.endLine=17
scope.1.semanticHash=ed266c880f72fa1e
scope.2.id=function:_resolve_player_id:19
scope.2.kind=function
scope.2.startLine=19
scope.2.endLine=21
scope.2.semanticHash=9fefa90c69b3580b
scope.3.id=function:_resolve_active_player_base:23
scope.3.kind=function
scope.3.startLine=23
scope.3.endLine=29
scope.3.semanticHash=49328da38383c0b5
scope.4.id=function:M.resolve_min_player_y:91
scope.4.kind=function
scope.4.startLine=91
scope.4.endLine=102
scope.4.semanticHash=5bc16e2e450021a6
scope.5.id=function:_calc_y_offset:134
scope.5.kind=function
scope.5.startLine=134
scope.5.endLine=139
scope.5.semanticHash=0d7a54786081b9bc
scope.6.id=function:_resolve_target_position:141
scope.6.kind=function
scope.6.startLine=141
scope.6.endLine=143
scope.6.semanticHash=16bc3717a1b5f5ba
scope.7.id=function:_publish_follow_target:147
scope.7.kind=function
scope.7.startLine=147
scope.7.endLine=151
scope.7.semanticHash=95d085f4a0d0380c
scope.8.id=function:_place_player_unit:153
scope.8.kind=function
scope.8.startLine=153
scope.8.endLine=156
scope.8.semanticHash=85ed1756b1aa0a09
scope.9.id=function:_hide_eliminated_player:160
scope.9.kind=function
scope.9.startLine=160
scope.9.endLine=172
scope.9.semanticHash=57707ce064228e10
scope.10.id=function:_stop_and_log_player_motion:174
scope.10.kind=function
scope.10.startLine=174
scope.10.endLine=177
scope.10.semanticHash=514607304163879b
scope.11.id=function:_place_single_player:179
scope.11.kind=function
scope.11.startLine=179
scope.11.endLine=203
scope.11.semanticHash=88db93d5831ebb02
]]

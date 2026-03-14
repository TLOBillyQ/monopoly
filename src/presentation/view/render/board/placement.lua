local gameplay_read_port = require("src.presentation.model.gameplay_read_port")
local gameplay_rules = require("src.config.gameplay.gameplay_rules")
local runtime_state = require("src.core.state_access.runtime_state")
local runtime_ports = require("src.core.ports.runtime_ports")
local logger = require("src.core.utils.logger")
local move_anim = require("src.presentation.view.render.move_anim")

local M = {}

local function _should_debug_log()
  return logger.is_anim_debug_enabled() or gameplay_rules.move_anim_debug_log_enabled == true
end

local function _debug_log(...)
  if not _should_debug_log() then
    return
  end
  logger.info_unlimited("[MoveAnim]", ...)
end

local function _stop_player_motion(pid, seat_id, unit, vehicle, stop_synthetic_ai)
  return move_anim.stop_player_presentation(pid, unit, {
    stop_vehicle = seat_id ~= nil,
    emit_vehicle_stop = vehicle and vehicle.emit_vehicle_stop or nil,
    stop_synthetic_ai = stop_synthetic_ai == true,
  })
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

local function _build_snapshot(players)
  local snapshot = {}
  for i, player in ipairs(players) do
    assert(player ~= nil, "missing player: " .. tostring(i))
    local pid = _resolve_player_id(player, i)
    local pos = player.position
    local eliminated = player.eliminated and 1 or 0
    snapshot[pid] = tostring(pos) .. ":" .. tostring(eliminated)
  end
  return snapshot
end

function M.compute_need_sync(state, snapshot, vehicle_resync_seq)
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
  if not need_sync and board_runtime.board_last_vehicle_resync_seq ~= vehicle_resync_seq then
    need_sync = true
  end
  return need_sync
end

function M.build_occupants(state, players)
  local occupants = {}
  for i, player in ipairs(players) do
    assert(player ~= nil, "missing player: " .. tostring(i))
    if not player.eliminated then
      local idx, _, pid = _resolve_active_player_base(state, player, i)
      local list = occupants[idx]
      if not list then
        list = {}
        occupants[idx] = list
      end
      list[#list + 1] = pid
    end
  end
  return occupants
end

function M.resolve_min_player_y(scene)
  assert(scene.ground ~= nil, "missing board_scene.ground")
  assert(scene.ground.get_position ~= nil, "missing board_scene.ground.get_position")
  local ground_pos = scene.ground.get_position()
  assert(ground_pos ~= nil and ground_pos.y ~= nil, "missing ground position")
  local board_cfg = gameplay_rules.board or {}
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

local function _resolve_vehicle_emit_set_position(seat_id, vehicle)
  if seat_id and vehicle and vehicle.emit_vehicle_set_position then
    return vehicle.emit_vehicle_set_position
  end
  return nil
end

local function _place_player_unit(pid, unit, target_pos, seat_id, vehicle)
  local emit_set_position = _resolve_vehicle_emit_set_position(seat_id, vehicle)
  if emit_set_position then
    emit_set_position(pid, target_pos)
  else
    assert(unit.set_position ~= nil, "missing unit.set_position: " .. tostring(pid))
    unit.set_position(target_pos)
  end
end

local function _stop_and_log_player_motion(state, pid, seat_id, unit, vehicle)
  local stop_synthetic_ai = move_anim.peek_pending_synthetic_ai_stop(state.board_scene, pid)
  move_anim.clear_player_token(state.board_scene, pid, "board_sync_place_players")
  local stop_result = _stop_player_motion(pid, seat_id, unit, vehicle, stop_synthetic_ai)
  if stop_synthetic_ai == true then
    move_anim.consume_pending_synthetic_ai_stop(state.board_scene, pid)
  end
  return stop_result
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
  local seat_id = gameplay_read_port.resolve_vehicle_seat_id(player.seat_id)
  local vehicle = runtime_ports.resolve_vehicle_helper()
  local stop_result = _stop_and_log_player_motion(state, pid, seat_id, unit, vehicle)
  _debug_log(
    "board_refresh_stop_and_snap",
    "player_id=" .. tostring(pid),
    "position=" .. tostring(idx),
    "seat_id=" .. tostring(seat_id or "nil"),
    "vehicle_stop=" .. tostring(stop_result.vehicle_stop_path or "none"),
    "motion_stop=" .. tostring(stop_result.motion_stop_path or "none"),
    "anim_stop=" .. tostring(stop_result.anim_stop_path or "none"),
    "target_pos=" .. tostring(target_pos)
  )
  _place_player_unit(pid, unit, target_pos, seat_id, vehicle)
end

function M.place_players(state, players, occupants, spacing, min_player_y)
  for i, player in ipairs(players) do
    assert(player ~= nil, "missing player: " .. tostring(i))
    if not player.eliminated then
      _place_single_player(state, player, i, occupants, spacing, min_player_y)
    end
  end
end

M.build_snapshot = _build_snapshot

-- Exported for testing
M._resolve_occupant_slot = _resolve_occupant_slot

return M

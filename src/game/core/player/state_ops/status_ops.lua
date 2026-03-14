local common = require("src.game.core.player.state_ops.common")
local feature_toggles = require("src.config.gameplay.feature_toggles")
local runtime_ports = require("src.core.ports.runtime_ports")
local logger = require("src.core.utils.logger")

local status_ops = {}

local function _resolve_seat_id(seat_id)
  if not feature_toggles.is_vehicle_enabled() then
    return nil
  end
  return seat_id
end

function status_ops.set_player_status(self, player, key, value)
  local status = common.player_status_table(player)
  status[key] = value
  common.mark_players(self)
end

local function _clear_seat_when_vehicle_disabled(self, player)
  if feature_toggles.is_vehicle_enabled() then
    return false
  end
  player.seat_id = nil
  common.mark_players(self)
  return true
end

local function _normalize_known_seat_id(player, seat_id)
  if seat_id ~= nil and not common.vehicle_catalog.has(seat_id) then
    logger.warn("[Eggy]", "ignore unknown vehicle seat_id", tostring(seat_id), "for player", tostring(player and player.id))
    return nil
  end
  return seat_id
end

local function _mark_enter_wait(vehicle, player_id)
  if vehicle and vehicle.needs_enter_wait_by_player then
    vehicle.needs_enter_wait_by_player[player_id] = true
  end
end

local function _sync_vehicle_seat_events(vehicle, player, old_seat_id, new_seat_id)
  if old_seat_id == new_seat_id or not vehicle then
    return
  end
  if old_seat_id ~= nil and vehicle.emit_vehicle_exit then
    vehicle.emit_vehicle_exit(player.id)
  end
  if new_seat_id ~= nil and vehicle.emit_vehicle_enter then
    vehicle.emit_vehicle_enter(player.id, new_seat_id)
    _mark_enter_wait(vehicle, player.id)
  end
end

function status_ops.set_player_seat(self, player, seat_id)
  seat_id = _resolve_seat_id(seat_id)
  if _clear_seat_when_vehicle_disabled(self, player) then
    return
  end
  seat_id = _normalize_known_seat_id(player, seat_id)

  local old_seat_id = player.seat_id
  local vehicle = runtime_ports.resolve_vehicle_helper()
  _sync_vehicle_seat_events(vehicle, player, old_seat_id, seat_id)
  player.seat_id = seat_id
  common.mark_players(self)
end

function status_ops.set_player_eliminated(self, player, eliminated)
  player.eliminated = eliminated == true
  common.mark_players(self)
end

function status_ops.set_player_property(self, player, tile_id, owned)
  player.properties = player.properties or {}
  if owned then
    player.properties[tile_id] = true
  else
    player.properties[tile_id] = nil
  end
  common.mark_players(self)
end

function status_ops.clear_player_temporal_flags(self, player)
  local status = common.player_status_table(player)
  status.pending_dice_multiplier = 1
  status.pending_free_rent = false
  status.pending_tax_free = false
  status.pending_remote_dice = nil
  common.mark_players(self)
end

local function _clear_player_move_dir(player)
  local status = common.player_status_table(player)
  if status.move_dir == nil then
    return false
  end
  status.move_dir = nil
  return true
end

local function _can_emit_vehicle_stop(vehicle, player, emit_stop)
  local seat_id = _resolve_seat_id(player.seat_id)
  if not (vehicle and emit_stop and seat_id ~= nil) then
    return false
  end
  if not vehicle.resolve_role then
    return true
  end
  return vehicle.resolve_role(player.id) ~= nil
end

local function _stop_player_movement(vehicle, emit_stop, player)
  local dirty = _clear_player_move_dir(player)
  if _can_emit_vehicle_stop(vehicle, player, emit_stop) then
    emit_stop(player.id)
  end
  return dirty
end

local function _stop_all_players(players, vehicle, emit_stop)
  local players_dirty = false
  for _, player in ipairs(players or {}) do
    if _stop_player_movement(vehicle, emit_stop, player) then
      players_dirty = true
    end
  end
  return players_dirty
end

local function _mark_vehicle_resync(self)
  if not self.turn then
    return
  end
  self.turn.vehicle_resync_seq = (self.turn.vehicle_resync_seq or 0) + 1
  self.dirty.turn = true
  self.dirty.any = true
end

function status_ops.stop_all_players_movement(self)
  local vehicle = runtime_ports.resolve_vehicle_helper()
  local emit_stop = vehicle and vehicle.emit_vehicle_stop or nil
  local players_dirty = _stop_all_players(self.players, vehicle, emit_stop)
  if players_dirty then
    common.mark_players(self)
  end
  _mark_vehicle_resync(self)
end

return status_ops

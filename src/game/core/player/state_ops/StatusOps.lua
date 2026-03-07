local common = require("src.game.core.player.state_ops.Common")
local vehicle_feature = require("src.game.systems.vehicle.VehicleFeature")
local runtime_ports = require("src.core.ports.RuntimePorts")
local logger = require("src.core.utils.Logger")

local status_ops = {}

function status_ops.set_player_status(self, player, key, value)
  local status = common.player_status_table(player)
  status[key] = value
  common.mark_players(self)
end

function status_ops.set_player_seat(self, player, seat_id)
  seat_id = vehicle_feature.resolve_seat_id(seat_id)
  if not vehicle_feature.is_enabled() then
    player.seat_id = nil
    common.mark_players(self)
    return
  end
  if seat_id ~= nil and not common.vehicle_catalog.has(seat_id) then
    logger.warn("[Eggy]", "ignore unknown vehicle seat_id", tostring(seat_id), "for player", tostring(player and player.id))
    seat_id = nil
  end

  local old_seat_id = player.seat_id
  local vehicle = runtime_ports.resolve_vehicle_helper()
  local emit_exit = vehicle and vehicle.emit_vehicle_exit or nil
  local emit_enter = vehicle and vehicle.emit_vehicle_enter or nil
  if old_seat_id ~= seat_id and vehicle then
    if old_seat_id ~= nil and emit_exit then
      emit_exit(player.id)
    end
    if seat_id ~= nil and emit_enter then
      emit_enter(player.id, seat_id)
      if vehicle.needs_enter_wait_by_player then
        vehicle.needs_enter_wait_by_player[player.id] = true
      end
    end
  end
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

function status_ops.stop_all_players_movement(self)
  local players = self.players or {}
  local vehicle = runtime_ports.resolve_vehicle_helper()
  local emit_stop = vehicle and vehicle.emit_vehicle_stop or nil
  local players_dirty = false
  for _, player in ipairs(players) do
    local status = common.player_status_table(player)
    if status.move_dir ~= nil then
      status.move_dir = nil
      players_dirty = true
    end
    local seat_id = vehicle_feature.resolve_seat_id(player.seat_id)
    if vehicle and emit_stop and seat_id ~= nil then
      local role_ok = true
      if vehicle.resolve_role then
        role_ok = vehicle.resolve_role(player.id) ~= nil
      end
      if role_ok then
        emit_stop(player.id)
      end
    end
  end
  if players_dirty then
    common.mark_players(self)
  end
  if self.turn then
    self.turn.vehicle_resync_seq = (self.turn.vehicle_resync_seq or 0) + 1
    self.dirty.turn = true
    self.dirty.any = true
  end
end

return status_ops

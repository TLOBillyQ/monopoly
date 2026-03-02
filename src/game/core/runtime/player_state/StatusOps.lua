local common = require("src.game.core.runtime.player_state.Common")
local vehicle_feature = require("src.game.systems.vehicle.VehicleFeature")
local runtime_ports = require("src.core.RuntimePorts")

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

  local old_seat_id = player.seat_id
  local vehicle = runtime_ports.resolve_vehicle_helper()
  if old_seat_id ~= seat_id and vehicle then
    if old_seat_id ~= nil and vehicle.forward_eca_event_exit then
      vehicle.forward_eca_event_exit(player.id)
    end
    if seat_id ~= nil and vehicle.forward_eca_event_enter then
      vehicle.forward_eca_event_enter(player.id, seat_id)
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
  local players_dirty = false
  for _, player in ipairs(players) do
    local status = common.player_status_table(player)
    if status.move_dir ~= nil then
      status.move_dir = nil
      players_dirty = true
    end
    local seat_id = vehicle_feature.resolve_seat_id(player.seat_id)
    if vehicle and vehicle.forward_eca_event_stop and seat_id ~= nil then
      local role_ok = true
      if vehicle.resolve_role then
        role_ok = vehicle.resolve_role(player.id) ~= nil
      end
      if role_ok then
        vehicle.forward_eca_event_stop(player.id)
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

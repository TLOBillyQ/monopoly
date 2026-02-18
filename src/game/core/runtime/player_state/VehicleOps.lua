local common = require("src.game.core.runtime.player_state.Common")
local vehicle_feature = require("src.game.systems.vehicle.VehicleFeature")

local vehicle_ops = {}

function vehicle_ops.player_vehicle_cfg(_self, player)
  local seat_id = vehicle_feature.resolve_seat_id(player.seat_id)
  if seat_id then
    local cfg = common.vehicle_by_id[seat_id]
    assert(cfg ~= nil, "missing vehicle cfg: " .. tostring(seat_id))
    return cfg
  end
  return common.default_vehicle_cfg
end

function vehicle_ops.player_vehicle_name(self, player)
  return self:player_vehicle_cfg(player).name
end

function vehicle_ops.player_dice_count(self, player)
  return self:player_vehicle_cfg(player).dice_count
end

function vehicle_ops.player_is_vehicle_indestructible(self, player)
  return self:player_vehicle_cfg(player).indestructible == true
end

return vehicle_ops

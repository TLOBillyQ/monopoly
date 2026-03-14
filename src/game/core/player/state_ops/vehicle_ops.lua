local common = require("src.game.core.player.state_ops.common")
local feature_toggles = require("src.config.gameplay.feature_toggles")

local vehicle_ops = {}

function vehicle_ops.player_vehicle_cfg(_self, player)
  local seat_id = nil
  if feature_toggles.is_vehicle_enabled() then
    seat_id = player.seat_id
  end
  if seat_id then
    local cfg = common.vehicle_catalog.find(seat_id)
    if cfg ~= nil then
      return cfg
    end
    return common.default_vehicle_cfg
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

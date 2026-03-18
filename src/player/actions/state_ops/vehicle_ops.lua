local common = require("src.player.actions.state_ops.common")

local vehicle_ops = {}

function vehicle_ops.player_vehicle_cfg(_self, _player)
  return {
    id = 0,
    name = "",
    dice_count = common.constants.default_dice_count,
    indestructible = false,
  }
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

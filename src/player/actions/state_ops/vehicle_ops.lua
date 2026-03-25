local common = require("src.player.actions.state_ops.common")
local vehicle_catalog = require("src.config.gameplay.vehicle_catalog")

local vehicle_ops = {}

local function _default_vehicle_cfg()
  return {
    id = 0,
    name = "",
    dice_count = common.constants.default_dice_count,
    indestructible = false,
  }
end

function vehicle_ops.player_vehicle_cfg(_self, player)
  local seat_id = player and player.seat_id or nil
  if seat_id == nil then
    return _default_vehicle_cfg()
  end
  local entry = vehicle_catalog.find(seat_id)
  if entry == nil then
    return _default_vehicle_cfg()
  end
  return {
    id = entry.id,
    name = entry.name,
    dice_count = entry.dice_count or common.constants.default_dice_count,
    indestructible = entry.indestructible == true,
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

local constants = require("src.config.constants")
local vehicles_cfg = require("src.config.vehicles")

local vehicle_by_id = {}
for _, cfg in ipairs(vehicles_cfg) do
  vehicle_by_id[cfg.id] = cfg
end

local Vehicle = {}

function Vehicle:vehicle_cfg()
  if not self.seat_id then
    return nil
  end
  return vehicle_by_id[self.seat_id]
end

function Vehicle:vehicle_name()
  local cfg = self:vehicle_cfg()
  return cfg and cfg.name or nil
end

function Vehicle:dice_count()
  local cfg = self:vehicle_cfg()
  if cfg and cfg.dice_count then
    return cfg.dice_count
  end
  return constants.default_dice_count
end

function Vehicle:is_vehicle_indestructible()
  local cfg = self:vehicle_cfg()
  return cfg and cfg.indestructible or false
end

return Vehicle
local gameplay_rules = require("src.config.gameplay.gameplay_rules")

local feature_toggles = {}

function feature_toggles.is_vehicle_enabled()
  return gameplay_rules.vehicle_enabled == true
end

return feature_toggles

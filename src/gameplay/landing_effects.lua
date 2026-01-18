local landing_defs = require("src.config.landing_effects")
local land_defs = require("src.config.land_effects")

local defs = {}
for _, eff in ipairs(landing_defs or {}) do
  table.insert(defs, eff)
end
for _, eff in ipairs(land_defs or {}) do
  table.insert(defs, eff)
end

return { defs = defs }

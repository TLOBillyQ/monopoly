local pricing = require("src.game.systems.land.pricing")

local property_value = {}

function property_value.total_invested(tile, level)
  assert(tile ~= nil, "missing tile")
  return pricing.total_invested(tile, level or 0)
end

return property_value

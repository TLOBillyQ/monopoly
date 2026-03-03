local chance_cfg = require("Config.Generated.ChanceCards")
local market_cfg = require("Config.Generated.Market")
local vehicle_catalog = require("src.core.config.VehicleCatalog")

local config_sanity = {}

local validated = false

local function _validate_chance_vehicle_refs()
  for _, card in ipairs(chance_cfg) do
    if card.effect == "set_vehicle" then
      assert(
        vehicle_catalog.has(card.vehicle_id),
        "chance card references unknown vehicle_id: " .. tostring(card.vehicle_id) .. " (card_id=" .. tostring(card.id) .. ")"
      )
    end
  end
end

local function _validate_market_vehicle_refs()
  for _, entry in ipairs(market_cfg) do
    if entry.kind == "vehicle" then
      assert(
        vehicle_catalog.has(entry.product_id),
        "market entry references unknown vehicle product_id: " .. tostring(entry.product_id)
      )
    end
  end
end

function config_sanity.validate()
  if validated then
    return true
  end
  _validate_chance_vehicle_refs()
  _validate_market_vehicle_refs()
  validated = true
  return true
end

function config_sanity.reset_for_tests()
  validated = false
end

return config_sanity

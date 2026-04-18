local item_ids = require("src.config.gameplay.item_ids")

local function _test_market_context_entry_name_vehicle_cfg()
  local context = require("src.rules.market.query.context")
  local name = context.entry_name({ kind = "vehicle", product_id = 5001 })
  assert(type(name) == "string" and name ~= "", "vehicle entry should resolve configured vehicle name")
end

local function _test_market_context_entry_name_item_cfg_and_fallback()
  local context = require("src.rules.market.query.context")
  local configured = context.entry_name({ kind = "item", product_id = item_ids.free_rent })
  local fallback = context.entry_name({ kind = "item", product_id = 999999, name = "FallbackName" })
  assert(type(configured) == "string" and configured ~= "", "item entry should resolve configured item name")
  assert(fallback == "FallbackName", "unknown item should fallback to entry.name")
end

return {
  name = "choices_market",
  tests = {
    { name = "_test_market_context_entry_name_vehicle_cfg", run = _test_market_context_entry_name_vehicle_cfg },
    { name = "_test_market_context_entry_name_item_cfg_and_fallback", run = _test_market_context_entry_name_item_cfg_and_fallback },
  },
}

local market_cfg = require("src.config.content.market")

local market_catalog = {}

local function _build_entries_by_id()
  local entries_by_id = {}
  local first_index_by_id = {}
  for index, entry in ipairs(market_cfg) do
    local product_id = entry and entry.product_id or nil
    if product_id ~= nil then
      local first_index = first_index_by_id[product_id]
      assert(
        first_index == nil,
        "duplicate market product_id: "
          .. tostring(product_id)
          .. " (first_index="
          .. tostring(first_index)
          .. ", duplicate_index="
          .. tostring(index)
          .. ")"
      )
      first_index_by_id[product_id] = index
      entries_by_id[product_id] = entry
    end
  end
  return entries_by_id
end

function market_catalog.entries()
  return market_cfg
end

function market_catalog.entry_by_id(product_id)
  return _build_entries_by_id()[product_id]
end

function market_catalog.assert_valid()
  _build_entries_by_id()
  return true
end

return market_catalog

local items_cfg = require("src.config.content.items")

local item_ids = {}

for _, cfg in ipairs(items_cfg) do
  local key = cfg and cfg.key or nil
  local id = cfg and cfg.id or nil
  if key ~= nil and key ~= "" then
    assert(item_ids[key] == nil, "duplicate item key in items config: " .. tostring(key))
    item_ids[key] = id
  end
end

return item_ids

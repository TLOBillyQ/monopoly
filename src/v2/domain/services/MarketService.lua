local market_cfg = require("Config.Generated.Market")
local items_cfg = require("Config.Generated.Items")
local vehicles_cfg = require("Config.Generated.Vehicles")

local common = require("src.v2.domain.services.Common")

local market_service = {}

local items_by_id = {}
for _, cfg in ipairs(items_cfg) do
  items_by_id[cfg.id] = cfg
end

local vehicles_by_id = {}
for _, cfg in ipairs(vehicles_cfg) do
  vehicles_by_id[cfg.id] = cfg
end

local entries_by_id = {}
for _, entry in ipairs(market_cfg) do
  entries_by_id[entry.product_id] = entry
end

local function _entry_name(entry)
  if entry.kind == "vehicle" then
    local cfg = vehicles_by_id[entry.product_id]
    return (cfg and cfg.name) or entry.name or tostring(entry.product_id)
  end
  local cfg = items_by_id[entry.product_id]
  return (cfg and cfg.name) or entry.name or tostring(entry.product_id)
end

local function _entry_price(entry)
  return entry.price or 0
end

local function _entry_currency(entry)
  return (entry.currency and entry.currency ~= "") and entry.currency or "金币"
end

local function _remaining_limit(state, product_id)
  return (state.market and state.market.global_limits and state.market.global_limits[product_id]) or 0
end

function market_service.can_buy_entry(state, seat, entry)
  local player = state.players[seat]
  if not player then
    return false
  end
  if entry.kind == "item" and common.count_item(player) >= (player.inventory.max_slots or 5) then
    return false
  end
  if _remaining_limit(state, entry.product_id) <= 0 then
    return false
  end
  return common.balance_of(player, _entry_currency(entry)) >= _entry_price(entry)
end

function market_service.list_buyable(state, seat)
  local list = {}
  for _, entry in ipairs(market_cfg) do
    if market_service.can_buy_entry(state, seat, entry) then
      list[#list + 1] = entry
    end
  end
  table.sort(list, function(a, b)
    return (a.order or 0) < (b.order or 0)
  end)
  return list
end

function market_service.build_choice(state, seat)
  local options = {}
  local body_lines = {}
  for _, entry in ipairs(market_service.list_buyable(state, seat)) do
    local label = _entry_name(entry) .. " - " .. tostring(_entry_price(entry)) .. " " .. _entry_currency(entry)
    options[#options + 1] = { id = entry.product_id, label = label }
    body_lines[#body_lines + 1] = label
  end
  if #options == 0 then
    return nil
  end
  return {
    kind = "market_buy",
    title = "黑市",
    body_lines = body_lines,
    options = options,
    allow_cancel = true,
    cancel_label = "不买",
    meta = { owner_seat = seat },
  }
end

function market_service.entry(product_id)
  return entries_by_id[product_id]
end

function market_service.entry_name(product_id)
  local entry = entries_by_id[product_id]
  if not entry then
    return tostring(product_id)
  end
  return _entry_name(entry)
end

function market_service.entry_currency(product_id)
  local entry = entries_by_id[product_id]
  if not entry then
    return "金币"
  end
  return _entry_currency(entry)
end

function market_service.entry_price(product_id)
  local entry = entries_by_id[product_id]
  if not entry then
    return 0
  end
  return _entry_price(entry)
end

return market_service

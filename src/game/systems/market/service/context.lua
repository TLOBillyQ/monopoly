local market_cfg = require("Config.generated.market")
local items_cfg = require("Config.generated.items")
local paid_currency_bridge = require("src.game.systems.commerce.paid_currency_bridge")
local vehicle_feature = require("src.game.systems.vehicle.vehicle_feature")
local vehicle_catalog = require("src.core.config.vehicle_catalog")

local context = {}

local items_by_id = {}
for _, cfg in ipairs(items_cfg) do
  items_by_id[cfg.id] = cfg
end

local entries_by_id = {}
for _, entry in ipairs(market_cfg) do
  entries_by_id[entry.product_id] = entry
end

function context.entries()
  return market_cfg
end

function context.entry_by_id(product_id)
  return entries_by_id[product_id]
end

function context.entry_name(entry)
  if entry.kind == "vehicle" then
    local cfg = vehicle_catalog.find(entry.product_id)
    if cfg then
      return cfg.name
    end
    if entry.name then
      return entry.name
    end
    return tostring(entry.product_id)
  end
  local cfg = items_by_id[entry.product_id]
  if cfg then
    return cfg.name
  end
  if entry.name then
    return entry.name
  end
  return tostring(entry.product_id)
end

function context.vehicle_name(seat_id)
  if seat_id then
    local cfg = vehicle_catalog.find(seat_id)
    if cfg then
      return cfg.name
    end
    return tostring(seat_id)
  end
  return "无"
end

function context.entry_price(entry)
  return entry.price or 0
end

function context.entry_currency(entry)
  local currency = entry.currency
  if currency and currency ~= "" then
    return currency
  end
  return "金币"
end

function context.entry_market_enabled(entry)
  assert(entry ~= nil, "missing market entry")
  return entry.market_enabled ~= false
end

function context.entry_vehicle_enabled(entry)
  if not vehicle_feature.is_vehicle_market_entry(entry) then
    return true
  end
  return vehicle_feature.is_enabled()
end

function context.remaining_global_limit(game, product_id)
  assert(game ~= nil, "missing game")
  assert(product_id ~= nil, "missing product_id")
  return game.market_limits[product_id]
end

function context.sync_managed_balance(game, player, currency)
  if paid_currency_bridge.is_managed_currency(game, currency) then
    paid_currency_bridge.sync_player_currency(game, player, currency)
  end
end

function context.is_paid_currency(currency)
  return paid_currency_bridge.is_paid_currency(currency)
end

function context.try_charge_player(game, player, currency, price)
  if paid_currency_bridge.is_managed_currency(game, currency) then
    return paid_currency_bridge.consume_currency(game, player, currency, price)
  end
  game:deduct_player_balance(player, currency, price)
  return true
end

function context.consume_global_limit(game, product_id)
  assert(game ~= nil, "missing game")
  assert(product_id ~= nil, "missing product_id")
  local remaining = assert(game.market_limits[product_id], "missing global limit")
  local next_remaining = remaining - 1
  if next_remaining < 0 then
    next_remaining = 0
  end
  game.market_limits[product_id] = next_remaining
  game.dirty.market = true
  game.dirty.any = true
end

return context

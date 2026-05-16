local market_catalog = require("src.config.content.market_catalog")
local items_cfg = require("src.config.content.items")
local paid_currency_bridge = require("src.rules.commerce.paid_currency_bridge")
local dirty_tracker = require("src.state.dirty_tracker")
local inventory = require("src.rules.items.inventory")
local paid_purchase_port = require("src.rules.ports.paid_purchase")

local context = {}

local items_by_id = {}
for _, cfg in ipairs(items_cfg) do
  items_by_id[cfg.id] = cfg
end

local _entries = market_catalog.entries
context.entry_by_id = market_catalog.entry_by_id

function context.entry_name(entry)
  local cfg = items_by_id[entry.product_id]
  if cfg then
    return cfg.name
  end
  if entry.name then
    return entry.name
  end
  return tostring(entry.product_id)
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

function context.remaining_global_limit(game, product_id)
  assert(game ~= nil, "missing game")
  assert(product_id ~= nil, "missing product_id")
  return game.market_limits[product_id]
end

context.is_paid_currency = paid_currency_bridge.is_paid_currency

function context.try_charge_player(game, player, currency, price, opts)
  game:deduct_player_balance(player, currency, price, opts)
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
  dirty_tracker.mark(game.dirty, "market")
end

local eligibility = {}

function eligibility.can_buy_entry(game, player, entry)
  if not context.entry_market_enabled(entry) then
    return false
  end
  if entry.kind == "item" and inventory.is_full(player) then
    return false
  end
  local remaining = context.remaining_global_limit(game, entry.product_id)
  if remaining <= 0 then
    return false
  end
  local price = context.entry_price(entry)
  local currency = context.entry_currency(entry)
  if context.is_paid_currency(currency) then
    local ok = paid_purchase_port.can_start(game, player, entry)
    return ok == true
  end
  return game:player_balance(player, currency) >= price
end

function eligibility.is_sold_out(game, entry)
  return context.remaining_global_limit(game, entry.product_id) <= 0
end

function eligibility.sorted_entries()
  local entries = {}
  for _, entry in ipairs(_entries()) do
    entries[#entries + 1] = entry
  end
  table.sort(entries, function(a, b)
    return (a.order or 0) < (b.order or 0)
  end)
  return entries
end

function eligibility.list_available(player, game)
  local list = {}
  for _, entry in ipairs(eligibility.sorted_entries()) do
    if eligibility.can_buy_entry(game, player, entry) then
      list[#list + 1] = entry
    end
  end
  return list
end

local function _split_entries_by_buyable(player, game)
  local buyable = {}
  local unbuyable = {}
  for _, entry in ipairs(eligibility.sorted_entries()) do
    if eligibility.can_buy_entry(game, player, entry) then
      buyable[#buyable + 1] = entry
    else
      unbuyable[#unbuyable + 1] = entry
    end
  end
  return buyable, unbuyable
end

local function _append_visible_entries(visible, entries, can_buy, limit)
  for _, entry in ipairs(entries) do
    visible[#visible + 1] = { entry = entry, can_buy = can_buy }
    if limit and #visible >= limit then
      return true
    end
  end
  return false
end

eligibility._split_entries_by_buyable = _split_entries_by_buyable
eligibility._append_visible_entries = _append_visible_entries

return {
  context = context,
  eligibility = eligibility,
}

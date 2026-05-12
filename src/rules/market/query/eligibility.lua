local inventory = require("src.rules.items.inventory")
local context = require("src.rules.market.query.context")
local paid_purchase_port = require("src.rules.ports.paid_purchase")

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
  for _, entry in ipairs(context.entries()) do
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

-- Export helpers for testability
eligibility._split_entries_by_buyable = _split_entries_by_buyable
eligibility._append_visible_entries = _append_visible_entries

return eligibility

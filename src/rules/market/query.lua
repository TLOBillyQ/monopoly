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

function context.try_charge_player(game, player, price, opts)
  game:deduct_player_cash(player, price, opts)
  return true
end

function context.consume_global_limit(game, product_id)
  assert(game ~= nil, "missing game")
  assert(product_id ~= nil, "missing product_id")
  local remaining = assert(game.market_limits[product_id], "missing global limit")
  game.market_limits[product_id] = math.max(remaining - 1, 0)
  dirty_tracker.mark(game.dirty, "market")
end

local eligibility = {}

local function _is_market_item(entry)
  return entry ~= nil and entry.kind == "item"
end

function eligibility.can_buy_entry(game, player, entry)
  if not _is_market_item(entry) then
    return false
  end
  if not context.entry_market_enabled(entry) then
    return false
  end
  if inventory.is_full(player) then
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
  return game:player_cash(player) >= price
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

--[[ mutate4lua-manifest
version=2
projectHash=67636cc788938aaf
scope.0.id=chunk:src/rules/market/query.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=151
scope.0.semanticHash=aa2723decc6b3988
scope.0.lastMutatedAt=2026-05-25T07:32:34Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=28
scope.0.lastMutationKilled=28
scope.1.id=function:context.entry_name:18
scope.1.kind=function
scope.1.startLine=18
scope.1.endLine=27
scope.1.semanticHash=68ed5f5cbfa99e72
scope.1.lastMutatedAt=2026-05-25T07:32:34Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=1
scope.1.lastMutationKilled=1
scope.2.id=function:context.entry_price:29
scope.2.kind=function
scope.2.startLine=29
scope.2.endLine=31
scope.2.semanticHash=f25afdacc32b7dc6
scope.2.lastMutatedAt=2026-05-25T07:32:34Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=2
scope.2.lastMutationKilled=2
scope.3.id=function:context.entry_currency:33
scope.3.kind=function
scope.3.startLine=33
scope.3.endLine=39
scope.3.semanticHash=54168c1ed1c0beb7
scope.3.lastMutatedAt=2026-05-25T07:32:34Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=4
scope.3.lastMutationKilled=4
scope.4.id=function:context.entry_market_enabled:41
scope.4.kind=function
scope.4.startLine=41
scope.4.endLine=44
scope.4.semanticHash=8d52ea3e07898e28
scope.4.lastMutatedAt=2026-05-25T07:32:34Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=3
scope.4.lastMutationKilled=3
scope.5.id=function:context.remaining_global_limit:46
scope.5.kind=function
scope.5.startLine=46
scope.5.endLine=50
scope.5.semanticHash=da4987ef9d6d6a8d
scope.5.lastMutatedAt=2026-05-25T07:32:34Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=2
scope.5.lastMutationKilled=2
scope.6.id=function:context.try_charge_player:54
scope.6.kind=function
scope.6.startLine=54
scope.6.endLine=57
scope.6.semanticHash=fbf3f3051f233719
scope.6.lastMutatedAt=2026-05-25T07:32:34Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=2
scope.6.lastMutationKilled=2
scope.7.id=function:context.consume_global_limit:59
scope.7.kind=function
scope.7.startLine=59
scope.7.endLine=65
scope.7.semanticHash=0918831cb9438187
scope.7.lastMutatedAt=2026-05-25T07:32:34Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=5
scope.7.lastMutationKilled=5
scope.8.id=function:_is_market_item:69
scope.8.kind=function
scope.8.startLine=69
scope.8.endLine=71
scope.8.semanticHash=a91c1c900b7bc987
scope.8.lastMutatedAt=2026-05-25T07:32:34Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=4
scope.8.lastMutationKilled=4
scope.9.id=function:eligibility.can_buy_entry:73
scope.9.kind=function
scope.9.startLine=73
scope.9.endLine=94
scope.9.semanticHash=2f012deb75fad11c
scope.9.lastMutatedAt=2026-05-25T07:32:34Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=20
scope.9.lastMutationKilled=20
scope.10.id=function:eligibility.is_sold_out:96
scope.10.kind=function
scope.10.startLine=96
scope.10.endLine=98
scope.10.semanticHash=72885b8dd8e5dbe4
scope.10.lastMutatedAt=2026-05-25T07:32:34Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=3
scope.10.lastMutationKilled=3
scope.11.id=function:anonymous@105:105
scope.11.kind=function
scope.11.startLine=105
scope.11.endLine=107
scope.11.semanticHash=5f0d19215f03e09b
scope.11.lastMutatedAt=2026-05-25T07:32:34Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=no_sites
scope.11.lastMutationSites=0
scope.11.lastMutationKilled=0
]]

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

local _DEFAULT_ENTRY_CURRENCY = "金币"

function context.entry_currency(entry)
  local currency = entry.currency
  if currency and currency ~= "" then
    return currency
  end
  return _DEFAULT_ENTRY_CURRENCY
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

-- 收银防线：本地读扣路径只认默认金币币种。付费币种或未知币种必须硬失败，
-- 不得静默按金币读扣（保持既有 unsupported currency 的 fail-fast 语义）。
function context.assert_cash_currency(currency)
  assert(not context.is_paid_currency(currency) and currency == _DEFAULT_ENTRY_CURRENCY,
    "unsupported market currency: " .. tostring(currency))
end

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

-- 与货币无关的准入闸门:是商品、已上架、背包有位、全局限量未售罄。
local function _entry_available(game, player, entry)
  if not _is_market_item(entry) then
    return false
  end
  if not context.entry_market_enabled(entry) then
    return false
  end
  if inventory.is_full(player) then
    return false
  end
  return context.remaining_global_limit(game, entry.product_id) > 0
end

-- 付费货币走宿主下单校验,现金货币比 player_cash。
local function _can_afford_entry(game, player, entry)
  local price = context.entry_price(entry)
  local currency = context.entry_currency(entry)
  if context.is_paid_currency(currency) then
    local ok = paid_purchase_port.can_start(game, player, entry)
    return ok == true
  end
  context.assert_cash_currency(currency)
  return game:player_cash(player) >= price
end

function eligibility.can_buy_entry(game, player, entry)
  if not _entry_available(game, player, entry) then
    return false
  end
  return _can_afford_entry(game, player, entry)
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
version=4
projectHash=fbc1d0321bc3d70c
scope.0.id=chunk:src/rules/market/query.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=170
scope.0.semanticHash=cda57d352884aade
scope.1.id=function:context.entry_name
scope.1.kind=function
scope.1.startLine=18
scope.1.endLine=27
scope.1.semanticHash=05d7e2fcfd2b7b1a
scope.2.id=function:context.entry_price
scope.2.kind=function
scope.2.startLine=29
scope.2.endLine=31
scope.2.semanticHash=02a5d1f3afa31722
scope.3.id=function:context.entry_currency
scope.3.kind=function
scope.3.startLine=35
scope.3.endLine=41
scope.3.semanticHash=7e8d08a44c0d60df
scope.4.id=function:context.entry_market_enabled
scope.4.kind=function
scope.4.startLine=43
scope.4.endLine=46
scope.4.semanticHash=12d8100e372b33e8
scope.5.id=function:context.remaining_global_limit
scope.5.kind=function
scope.5.startLine=48
scope.5.endLine=52
scope.5.semanticHash=14f0ba097824d353
scope.6.id=function:context.assert_cash_currency
scope.6.kind=function
scope.6.startLine=58
scope.6.endLine=61
scope.6.semanticHash=fb71abf49148087f
scope.7.id=function:context.try_charge_player
scope.7.kind=function
scope.7.startLine=63
scope.7.endLine=66
scope.7.semanticHash=b08d4a180ecd4811
scope.8.id=function:context.consume_global_limit
scope.8.kind=function
scope.8.startLine=68
scope.8.endLine=74
scope.8.semanticHash=d9dd058ce02f6552
scope.9.id=function:_is_market_item
scope.9.kind=function
scope.9.startLine=78
scope.9.endLine=80
scope.9.semanticHash=812996efe26ec454
scope.10.id=function:_entry_available
scope.10.kind=function
scope.10.startLine=83
scope.10.endLine=94
scope.10.semanticHash=0e8287c14203a7eb
scope.11.id=function:_can_afford_entry
scope.11.kind=function
scope.11.startLine=97
scope.11.endLine=106
scope.11.semanticHash=1767a7123293adea
scope.12.id=function:eligibility.can_buy_entry
scope.12.kind=function
scope.12.startLine=108
scope.12.endLine=113
scope.12.semanticHash=249adc89863132e1
scope.13.id=function:eligibility.is_sold_out
scope.13.kind=function
scope.13.startLine=115
scope.13.endLine=117
scope.13.semanticHash=b34dd9e6b8ccbdc2
scope.14.id=function:eligibility.sorted_entries
scope.14.kind=function
scope.14.startLine=119
scope.14.endLine=128
scope.14.semanticHash=78848e64ab4a1c87
scope.15.id=function:<anonymous>
scope.15.kind=function
scope.15.startLine=124
scope.15.endLine=126
scope.15.semanticHash=a249536bc5d6a466
scope.16.id=function:eligibility.list_available
scope.16.kind=function
scope.16.startLine=130
scope.16.endLine=138
scope.16.semanticHash=3a86d13c52ddde5f
scope.17.id=function:_split_entries_by_buyable
scope.17.kind=function
scope.17.startLine=140
scope.17.endLine=151
scope.17.semanticHash=d3da1c5c60c6dc40
scope.18.id=function:_append_visible_entries
scope.18.kind=function
scope.18.startLine=153
scope.18.endLine=161
scope.18.semanticHash=e68ce64462655e13
]]

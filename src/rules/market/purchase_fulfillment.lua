local fulfillment = {}

local function _query_context()
  return require("src.rules.market.query").context
end

local function _emit_bought_item(game, payload)
  local monopoly_event = require("src.foundation.events")
  local event_feed = require("src.rules.ports.event_feed")
  local event_kinds = require("src.config.gameplay.event_kinds")

  monopoly_event.emit(monopoly_event.market.bought_item, payload)
  event_feed.publish(game, {
    kind = event_kinds.item_acquired,
    text = payload.text,
  })
end

local function _success_text(player, entry, price, currency, priced)
  local query_context = _query_context()
  local name = query_context.entry_name(entry)
  if priced then
    local number_utils = require("src.foundation.number")
    return player.name .. " 在黑市购买 " .. name .. " 花费 " .. number_utils.format_integer_part(price) .. " " .. currency
  end
  return player.name .. " 在黑市购买 " .. name .. " 成功"
end

local function _charge_if_needed(game, player, price, opts)
  if opts and opts.skip_charge == true then
    return true
  end
  return _query_context().try_charge_player(game, player, price, {
    suppress_cash_receive_anim = true,
  })
end

local function _fulfill_item(game, player, entry, opts)
  local inventory = require("src.rules.items.inventory")
  local query_context = _query_context()
  if inventory.is_full(player) then
    return { ok = false, reason = "inventory_full", body = player.name .. " 卡槽已满" }
  end
  if not _charge_if_needed(game, player, opts.price, opts) then
    return { ok = false, reason = "charge_failed", body = player.name .. " 支付失败" }
  end
  local given = inventory.give(player, entry.product_id, { game = game })
  if given == true then
    require("src.rules.items.gain_reveal").queue(game, player, entry.product_id, { source = "market" })
  end
  query_context.consume_global_limit(game, entry.product_id)
  _emit_bought_item(game, {
    player = player,
    entry = entry,
    price = opts.price,
    currency = opts.currency,
    text = _success_text(player, entry, opts.price, opts.currency, opts.priced_text),
  })
  require("src.rules.ports.achievement_progress").market_item_bought(game, player)
  return {
    ok = true,
    kind = "item",
    product_id = entry.product_id,
    inventory_full_after = inventory.is_full(player),
    fulfilled_now = true,
  }
end

function fulfillment.apply(game, player, entry, opts)
  local resolved_opts = {
    skip_charge = opts and opts.skip_charge == true,
    price = opts and opts.price,
    currency = opts and opts.currency,
    priced_text = opts and opts.priced_text == true,
  }
  return _fulfill_item(game, player, entry, resolved_opts)
end

return fulfillment

--[[ mutate4lua-manifest
version=2
projectHash=36b7627f8518582d
scope.0.id=chunk:src/rules/market/purchase_fulfillment.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=80
scope.0.semanticHash=f4d0c77463bf8245
scope.0.lastMutatedAt=2026-06-23T13:53:12Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=no_sites
scope.0.lastMutationSites=0
scope.0.lastMutationKilled=0
scope.1.id=function:_query_context:3
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=5
scope.1.semanticHash=3e0688406cd6c484
scope.1.lastMutatedAt=2026-06-23T13:53:12Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=1
scope.1.lastMutationKilled=1
scope.2.id=function:_emit_bought_item:7
scope.2.kind=function
scope.2.startLine=7
scope.2.endLine=17
scope.2.semanticHash=3678ee5a79006d80
scope.2.lastMutatedAt=2026-06-23T13:53:12Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=5
scope.2.lastMutationKilled=5
scope.3.id=function:_success_text:19
scope.3.kind=function
scope.3.startLine=19
scope.3.endLine=27
scope.3.semanticHash=65f5eba522b1d7e6
scope.3.lastMutatedAt=2026-06-23T13:53:12Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=9
scope.3.lastMutationKilled=9
scope.4.id=function:_charge_if_needed:29
scope.4.kind=function
scope.4.startLine=29
scope.4.endLine=36
scope.4.semanticHash=028e2951d9a01aeb
scope.4.lastMutatedAt=2026-06-23T13:53:12Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=6
scope.4.lastMutationKilled=6
scope.5.id=function:_fulfill_item:38
scope.5.kind=function
scope.5.startLine=38
scope.5.endLine=67
scope.5.semanticHash=6628bf16e8d10ea9
scope.5.lastMutatedAt=2026-06-23T13:53:12Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=24
scope.5.lastMutationKilled=24
scope.6.id=function:fulfillment.apply:69
scope.6.kind=function
scope.6.startLine=69
scope.6.endLine=77
scope.6.semanticHash=6714636abdd27495
scope.6.lastMutatedAt=2026-06-23T13:53:12Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=9
scope.6.lastMutationKilled=9
]]

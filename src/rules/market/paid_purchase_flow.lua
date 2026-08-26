local paid_purchase_flow = {}

local IN_FLIGHT_FIELD = "_market_paid_in_flight"
local IN_FLIGHT_TIMEOUT = 12.0

local function _in_flight_key(player_id, product_id)
  return tostring(player_id) .. ":" .. tostring(product_id)
end

function paid_purchase_flow.clear_in_flight(game, player, entry)
  local map = game[IN_FLIGHT_FIELD]
  if map then
    map[_in_flight_key(player.id, entry.product_id)] = nil
  end
end

local function _ensure_in_flight_map(game)
  local in_flight = game[IN_FLIGHT_FIELD]
  if not in_flight then
    in_flight = {}
    game[IN_FLIGHT_FIELD] = in_flight
  end
  return in_flight
end

local function _reject_in_flight_purchase(player, entry)
  local choice_feedback = require("src.rules.market.choice").feedback
  choice_feedback.emit_buy_failed(player, entry, "purchase_in_flight", player.name .. " 正在购买中，请稍候")
  return { ok = false, reason = "purchase_in_flight" }
end

local function _fail_paid_purchase_start(player, entry, product_id, reason)
  local logger = require("src.foundation.log")
  local choice_feedback = require("src.rules.market.choice").feedback
  local failed_reason = reason or "paid_purchase_start_failed"
  logger.warn(
    "market paid purchase blocked:",
    "product_id=" .. tostring(product_id),
    "name=" .. tostring(entry.name or ""),
    "reason=" .. tostring(reason or "unknown")
  )
  choice_feedback.emit_buy_failed(player, entry, failed_reason, player.name .. " 购买通道暂不可用")
  return { ok = false, reason = failed_reason }
end

local function _schedule_in_flight_clear(game, key)
  local runtime_ports = require("src.foundation.ports.runtime_ports")
  runtime_ports.schedule(IN_FLIGHT_TIMEOUT, function()
    local map = game[IN_FLIGHT_FIELD]
    if map then
      map[key] = nil
    end
  end)
end

function paid_purchase_flow.handle(game, player, entry, product_id, setup_for_game)
  local in_flight = _ensure_in_flight_map(game)
  local key = _in_flight_key(player.id, product_id)
  if in_flight[key] then
    return _reject_in_flight_purchase(player, entry)
  end
  in_flight[key] = true

  setup_for_game(game)
  local paid_purchase_gateway = require("src.rules.ports.paid_purchase")
  local ok_start, reason = paid_purchase_gateway.start(game, player, entry)
  if not ok_start then
    in_flight[key] = nil
    return _fail_paid_purchase_start(player, entry, product_id, reason)
  end

  _schedule_in_flight_clear(game, key)

  return {
    ok = true,
    kind = entry.kind,
    product_id = product_id,
    deferred_fulfillment = true,
  }
end

return paid_purchase_flow

--[[ mutate4lua-manifest
version=4
projectHash=daf5b79bb6df9a7b
scope.0.id=chunk:src/rules/market/paid_purchase_flow.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=83
scope.0.semanticHash=e17b11e27f8242f5
scope.1.id=function:_in_flight_key
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=8
scope.1.semanticHash=5f9ffb10335863b9
scope.2.id=function:paid_purchase_flow.clear_in_flight
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=15
scope.2.semanticHash=e34a1cc8878d37a0
scope.3.id=function:_ensure_in_flight_map
scope.3.kind=function
scope.3.startLine=17
scope.3.endLine=24
scope.3.semanticHash=a218fb2d0b1ced9b
scope.4.id=function:_reject_in_flight_purchase
scope.4.kind=function
scope.4.startLine=26
scope.4.endLine=30
scope.4.semanticHash=82a7206e30d7db70
scope.5.id=function:_fail_paid_purchase_start
scope.5.kind=function
scope.5.startLine=32
scope.5.endLine=44
scope.5.semanticHash=cb2cd847407f0166
scope.6.id=function:_schedule_in_flight_clear
scope.6.kind=function
scope.6.startLine=46
scope.6.endLine=54
scope.6.semanticHash=52e81b168cfc0e61
scope.7.id=function:<anonymous>
scope.7.kind=function
scope.7.startLine=48
scope.7.endLine=53
scope.7.semanticHash=6bfe3c3a83a78646
scope.8.id=function:paid_purchase_flow.handle
scope.8.kind=function
scope.8.startLine=56
scope.8.endLine=80
scope.8.semanticHash=574206e1f6c9a1b0
]]

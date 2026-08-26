-- 市场提示事件处理器(自 event_handlers.lua 拆分,行为保持):购买失败与卡槽
-- 满载的 tip 队列消息。
local tip_queue = require("src.foundation.tips")

local market_tip_handlers = {}
local MARKET_TIP_MIN_SECONDS = 3.0

local _enqueue_tip = tip_queue.enqueue

local function _event_data(data)
  if type(data) == "table" then
    return data
  end
  return nil
end

local function _popup_body(event_data)
  local popup = event_data and event_data.popup or nil
  return popup and popup.body or nil
end

local function _resolve_market_buy_failed_tip(event_data)
  local body = _popup_body(event_data)
  if type(body) == "string" and body ~= "" then
    return body
  end
  return "黑市购买失败"
end

function market_tip_handlers.install(register_handler, monopoly_event)
  register_handler(monopoly_event.market.buy_failed, function(data)
    local event_data = _event_data(data)
    local tip_text = _resolve_market_buy_failed_tip(event_data)
    _enqueue_tip({
      text = tip_text,
      duration = MARKET_TIP_MIN_SECONDS,
      dedupe_key = "market_buy_failed:" .. tostring(tip_text),
      blocks_inter_turn = false,
      source = "market.buy_failed",
    })
  end)

  register_handler(monopoly_event.market.inventory_full, function(data)
    local event_data = _event_data(data)
    local tip_text = (event_data and event_data.body) or "卡槽已满，无法继续购买"
    _enqueue_tip({
      text = tip_text,
      duration = MARKET_TIP_MIN_SECONDS,
      dedupe_key = "market_inventory_full",
      blocks_inter_turn = false,
      source = "market.inventory_full",
    })
  end)
end

return market_tip_handlers

--[[ mutate4lua-manifest
version=4
projectHash=92cb8aabdc388bfc
scope.0.id=chunk:src/ui/coord/market_tip_handlers.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=57
scope.0.semanticHash=3bb02cb99e124ff2
scope.1.id=function:_event_data
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=15
scope.1.semanticHash=e5984887eaa027c5
scope.2.id=function:_popup_body
scope.2.kind=function
scope.2.startLine=17
scope.2.endLine=20
scope.2.semanticHash=93c839897afe61e5
scope.3.id=function:_resolve_market_buy_failed_tip
scope.3.kind=function
scope.3.startLine=22
scope.3.endLine=28
scope.3.semanticHash=01b31a7dc4cc9282
scope.4.id=function:market_tip_handlers.install
scope.4.kind=function
scope.4.startLine=30
scope.4.endLine=54
scope.4.semanticHash=3d8f946d2703ff29
scope.5.id=function:<anonymous>
scope.5.kind=function
scope.5.startLine=31
scope.5.endLine=41
scope.5.semanticHash=1dc387f4af5566d4
scope.6.id=function:<anonymous>#2
scope.6.kind=function
scope.6.startLine=43
scope.6.endLine=53
scope.6.semanticHash=5f67a0f2984d3007
]]

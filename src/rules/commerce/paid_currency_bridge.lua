local paid_goods_cfg = require("src.rules.commerce.paid_goods")

local bridge = {}

local function _currency_entry(currency)
  if paid_goods_cfg.enabled ~= true then
    return nil
  end
  local key = currency and tostring(currency) or nil
  if not key then
    return nil
  end
  local currencies = paid_goods_cfg.currencies or {}
  return currencies[key]
end

function bridge.is_managed_currency(_, currency)
  local entry = _currency_entry(currency)
  if not entry then
    return false
  end
  return entry.source == "commodity"
end

function bridge.is_paid_currency(currency)
  return _currency_entry(currency) ~= nil
end

function bridge.is_currency_channel_ready(_, _currency)
  return true
end

function bridge.unavailable_reason(_, _currency)
  return nil
end

function bridge.setup_for_game(_)
  return true
end

return bridge

--[[ mutate4lua-manifest
version=2
projectHash=1eebc371417c7f74
scope.0.id=chunk:src/rules/commerce/paid_currency_bridge.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=42
scope.0.semanticHash=ce467f92e7bd06b8
scope.1.id=function:_currency_entry:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=15
scope.1.semanticHash=0938301df1bacf8b
scope.2.id=function:bridge.is_managed_currency:17
scope.2.kind=function
scope.2.startLine=17
scope.2.endLine=23
scope.2.semanticHash=094e864f6fdfc008
scope.3.id=function:bridge.is_paid_currency:25
scope.3.kind=function
scope.3.startLine=25
scope.3.endLine=27
scope.3.semanticHash=a961e3e7b6113807
scope.4.id=function:bridge.is_currency_channel_ready:29
scope.4.kind=function
scope.4.startLine=29
scope.4.endLine=31
scope.4.semanticHash=9c7a2dcb0c6fb0c1
scope.5.id=function:bridge.unavailable_reason:33
scope.5.kind=function
scope.5.startLine=33
scope.5.endLine=35
scope.5.semanticHash=acc7c49771098ca9
scope.6.id=function:bridge.setup_for_game:37
scope.6.kind=function
scope.6.startLine=37
scope.6.endLine=39
scope.6.semanticHash=860f39dd85bd98b9
]]

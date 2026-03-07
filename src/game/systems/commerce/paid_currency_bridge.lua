local paid_goods_cfg = require("src.game.systems.commerce.specs.paid_goods")

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

function bridge.is_channel_enforced()
  return false
end

function bridge.is_currency_channel_ready(_, currency)
  if not bridge.is_paid_currency(currency) then
    return true
  end
  return true
end

function bridge.unavailable_reason(_, _currency)
  return nil
end

function bridge.sync_player_currency(_, _, _)
  return false
end

function bridge.consume_currency(_, _, _, _)
  return false
end

function bridge.setup_for_game(_)
  return true
end

return bridge

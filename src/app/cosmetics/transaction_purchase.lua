local logger = require("src.foundation.log")
local paid_purchase_port = require("src.rules.ports.paid_purchase")
local transaction_context = require("src.app.cosmetics.transaction_context")
local transaction_state = require("src.app.cosmetics.transaction_state")

local purchase = {}

local function _resolve_player(root_state, role_id)
  local game = root_state and root_state.game or nil
  if game == nil then
    return nil, nil, "missing_game"
  end
  if type(game.find_player_by_id) ~= "function" then
    return game, nil, "missing_player_lookup"
  end
  local player = game:find_player_by_id(role_id)
  if player == nil then
    return game, nil, "missing_player"
  end
  return game, player, nil
end

local function _purchase_entry(root_state, role_id, skin, complete_purchase)
  return {
    kind = "skin",
    product_id = skin.product_id,
    name = skin.name,
    currency = skin.currency,
    price = skin.price,
    on_purchase = function()
      local result = complete_purchase(root_state, role_id, skin.product_id, {
        source = "paid_purchase",
      })
      return result.accepted == true
    end,
  }
end

local function _start_via_paid_port(root_state, role_id, skin, entry)
  local game, player, player_reason = _resolve_player(root_state, role_id)
  if player_reason ~= nil then
    return false, player_reason
  end
  local ok, started, reason = pcall(paid_purchase_port.start, game, player, entry)
  if not ok then
    return false, "paid_gateway_missing"
  end
  if started ~= true then
    return false, reason or "paid_gateway_rejected"
  end
  return true, nil
end

local function _start_via_legacy_adapter(root_state, role_id, skin, complete_purchase)
  local adapter = transaction_context.purchase_adapter()
  if type(adapter) ~= "function" then
    return nil, nil
  end
  local completed = nil
  local on_success = function()
    completed = complete_purchase(root_state, role_id, skin.product_id, {
      source = "purchase_callback",
    })
    return completed.accepted == true
  end
  local ok, started = pcall(adapter, role_id, skin, on_success, root_state)
  if not ok then
    logger.warn(
      "skin_panel: purchase callback failed",
      "role_id=" .. tostring(role_id),
      tostring(started)
    )
    return false, "purchase_callback_failed"
  end
  if started == false then
    return false, "purchase_callback_rejected"
  end
  return true, nil, completed
end

local function _record_pending(panel, role_id, skin)
  local key = transaction_state.role_key(role_id)
  if key == nil then
    return nil
  end
  panel.pending_skin_purchase_by_role[key] = {
    role_id = role_id,
    product_id = skin.product_id,
  }
  return key
end

function purchase.clear_pending(panel, role_id)
  local key = transaction_state.role_key(role_id)
  if key ~= nil and panel.pending_skin_purchase_by_role then
    panel.pending_skin_purchase_by_role[key] = nil
  end
end

local function _invalid_skin_rejection(panel, skin)
  if skin == nil then
    return transaction_state.rejected(panel, "missing_skin")
  end
  if skin.unlock ~= "purchase" then
    return transaction_state.rejected(panel, "invalid_purchase_skin", {
      notification = "皮肤尚未解锁",
    })
  end
  if skin.product_id == nil then
    return transaction_state.rejected(panel, "invalid_purchase_skin", {
      notification = "皮肤尚未解锁",
    })
  end
  return nil
end

local function _pending_key_or_rejection(panel, role_id)
  local key = transaction_state.role_key(role_id)
  if key == nil then
    return nil, transaction_state.rejected(panel, "missing_role")
  end
  if panel.pending_skin_purchase_by_role[key] ~= nil then
    return nil, transaction_state.rejected(panel, "purchase_in_flight")
  end
  return key, nil
end

local function _invalid_purchase_rejection(panel, role_id, skin)
  local skin_rejected = _invalid_skin_rejection(panel, skin)
  if skin_rejected ~= nil then
    return skin_rejected
  end
  local _, pending_rejected = _pending_key_or_rejection(panel, role_id)
  if pending_rejected ~= nil then
    return pending_rejected
  end
  return nil
end

local function _start_request(root_state, role_id, skin, complete_purchase)
  local started, reason, completed = _start_via_legacy_adapter(root_state, role_id, skin, complete_purchase)
  if started ~= nil then
    return started, reason, completed
  end
  local entry = _purchase_entry(root_state, role_id, skin, complete_purchase)
  return _start_via_paid_port(root_state, role_id, skin, entry)
end

function purchase.start(root_state, panel, role_id, skin, complete_purchase)
  local rejected = _invalid_purchase_rejection(panel, role_id, skin)
  if rejected ~= nil then
    return rejected
  end
  _record_pending(panel, role_id, skin)
  local started, reason, completed = _start_request(root_state, role_id, skin, complete_purchase)
  if started ~= true then
    purchase.clear_pending(panel, role_id)
    return transaction_state.rejected(panel, reason or "purchase_start_failed", {
      notification = "皮肤尚未解锁",
    })
  end
  if completed ~= nil then
    return completed
  end
  return transaction_state.accepted(panel, {
    action = "purchase_start",
    pending_purchase = true,
    product_id = skin.product_id,
    host_action_attempted = true,
    notification = nil,
  })
end

return purchase

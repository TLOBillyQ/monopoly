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

--[[ mutate4lua-manifest
version=2
projectHash=d1715555bed0aa01
scope.0.id=chunk:src/app/cosmetics/transaction_purchase.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=175
scope.0.semanticHash=4955f26944bd0c19
scope.0.lastMutatedAt=2026-06-24T16:13:11Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=4
scope.0.lastMutationKilled=4
scope.1.id=function:_resolve_player:8
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=21
scope.1.semanticHash=6fdf1d826a1f11cd
scope.1.lastMutatedAt=2026-06-24T16:13:11Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=11
scope.1.lastMutationKilled=11
scope.2.id=function:anonymous@30:30
scope.2.kind=function
scope.2.startLine=30
scope.2.endLine=35
scope.2.semanticHash=837c07d561414586
scope.2.lastMutatedAt=2026-06-24T16:13:11Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=3
scope.2.lastMutationKilled=3
scope.3.id=function:_purchase_entry:23
scope.3.kind=function
scope.3.startLine=23
scope.3.endLine=37
scope.3.semanticHash=296b485430c9b5af
scope.3.lastMutatedAt=2026-06-24T16:13:11Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=1
scope.3.lastMutationKilled=1
scope.4.id=function:_start_via_paid_port:39
scope.4.kind=function
scope.4.startLine=39
scope.4.endLine=52
scope.4.semanticHash=cb3a813941a47112
scope.4.lastMutatedAt=2026-06-24T16:13:11Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=13
scope.4.lastMutationKilled=13
scope.5.id=function:anonymous@60:60
scope.5.kind=function
scope.5.startLine=60
scope.5.endLine=65
scope.5.semanticHash=ce260dc520023034
scope.5.lastMutatedAt=2026-06-24T16:13:11Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=3
scope.5.lastMutationKilled=3
scope.6.id=function:_start_via_legacy_adapter:54
scope.6.kind=function
scope.6.startLine=54
scope.6.endLine=79
scope.6.semanticHash=468d9c21a8ba8681
scope.6.lastMutatedAt=2026-06-24T16:13:11Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=14
scope.6.lastMutationKilled=14
scope.7.id=function:_record_pending:81
scope.7.kind=function
scope.7.startLine=81
scope.7.endLine=91
scope.7.semanticHash=7cfe8c32ff700588
scope.7.lastMutatedAt=2026-06-24T16:13:11Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=2
scope.7.lastMutationKilled=2
scope.8.id=function:purchase.clear_pending:93
scope.8.kind=function
scope.8.startLine=93
scope.8.endLine=98
scope.8.semanticHash=4937661586c2da47
scope.8.lastMutatedAt=2026-06-24T16:13:11Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=3
scope.8.lastMutationKilled=3
scope.9.id=function:_invalid_skin_rejection:100
scope.9.kind=function
scope.9.startLine=100
scope.9.endLine=115
scope.9.semanticHash=61123dd4c5f4aa2d
scope.9.lastMutatedAt=2026-06-24T16:13:11Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=7
scope.9.lastMutationKilled=7
scope.10.id=function:_pending_key_or_rejection:117
scope.10.kind=function
scope.10.startLine=117
scope.10.endLine=126
scope.10.semanticHash=698f91807e0f4d95
scope.10.lastMutatedAt=2026-06-24T16:13:11Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=5
scope.10.lastMutationKilled=5
scope.11.id=function:_invalid_purchase_rejection:128
scope.11.kind=function
scope.11.startLine=128
scope.11.endLine=138
scope.11.semanticHash=6d792088b7fa29c9
scope.11.lastMutatedAt=2026-06-24T16:13:11Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=4
scope.11.lastMutationKilled=4
scope.12.id=function:_start_request:140
scope.12.kind=function
scope.12.startLine=140
scope.12.endLine=147
scope.12.semanticHash=adb9c05124058ff2
scope.12.lastMutatedAt=2026-06-24T16:13:11Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=passed
scope.12.lastMutationSites=4
scope.12.lastMutationKilled=4
scope.13.id=function:purchase.start:149
scope.13.kind=function
scope.13.startLine=149
scope.13.endLine=172
scope.13.semanticHash=8a5ac780e69f9393
scope.13.lastMutatedAt=2026-06-24T16:13:11Z
scope.13.lastMutationLane=behavior
scope.13.lastMutationStatus=passed
scope.13.lastMutationSites=10
scope.13.lastMutationKilled=10
]]

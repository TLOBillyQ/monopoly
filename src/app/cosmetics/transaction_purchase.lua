local paid_purchase_port = require("src.rules.ports.paid_purchase")
local transaction_context = require("src.app.cosmetics.transaction_context")
local transaction_state = require("src.app.cosmetics.transaction_state")

local purchase = {}

local function _game_of(root_state)
  return root_state and root_state.game or nil
end

local function _resolve_player(root_state, role_id)
  local game = _game_of(root_state)
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
      -- #293:source 标记无人读取(complete_skin_purchase 只收 3 参),死参数,
      -- 等价变异体处置——删冗余。
      local result = complete_purchase(root_state, role_id, skin.product_id)
      transaction_context.call_transaction_result_applier(root_state, result)
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
  local entry = _purchase_entry(root_state, role_id, skin, complete_purchase)
  return _start_via_paid_port(root_state, role_id, skin, entry)
end

function purchase.start(root_state, panel, role_id, skin, complete_purchase)
  local rejected = _invalid_purchase_rejection(panel, role_id, skin)
  if rejected ~= nil then
    return rejected
  end
  _record_pending(panel, role_id, skin)
  local started, reason = _start_request(root_state, role_id, skin, complete_purchase)
  if started ~= true then
    purchase.clear_pending(panel, role_id)
    -- #293:reason 恒非 nil(_start_via_paid_port 永远给 paid_gateway_*),
    -- `or "purchase_start_failed"` 是永不可达兜底,等价变异体——删冗余。
    return transaction_state.rejected(panel, reason, {
      notification = "皮肤尚未解锁",
    })
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
version=4
projectHash=c1826f579d936a9a
scope.0.id=chunk:src/app/cosmetics/transaction_purchase.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=147
scope.0.semanticHash=1c3eed6bc4b58175
scope.1.id=function:_game_of
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=9
scope.1.semanticHash=616a2ca60599c94f
scope.2.id=function:_resolve_player
scope.2.kind=function
scope.2.startLine=11
scope.2.endLine=24
scope.2.semanticHash=7cc4c1e84b4fc2c3
scope.3.id=function:_purchase_entry
scope.3.kind=function
scope.3.startLine=26
scope.3.endLine=41
scope.3.semanticHash=8ada563899e879dd
scope.4.id=function:<anonymous>
scope.4.kind=function
scope.4.startLine=33
scope.4.endLine=39
scope.4.semanticHash=18ee04d71a395902
scope.5.id=function:_start_via_paid_port
scope.5.kind=function
scope.5.startLine=43
scope.5.endLine=56
scope.5.semanticHash=9fc49371db0f3886
scope.6.id=function:_record_pending
scope.6.kind=function
scope.6.startLine=58
scope.6.endLine=68
scope.6.semanticHash=bcf440603d496168
scope.7.id=function:purchase.clear_pending
scope.7.kind=function
scope.7.startLine=70
scope.7.endLine=75
scope.7.semanticHash=ef22113d12f5a821
scope.8.id=function:_invalid_skin_rejection
scope.8.kind=function
scope.8.startLine=77
scope.8.endLine=92
scope.8.semanticHash=66d73e0042a26a53
scope.9.id=function:_pending_key_or_rejection
scope.9.kind=function
scope.9.startLine=94
scope.9.endLine=103
scope.9.semanticHash=8d3d2c89ca54178e
scope.10.id=function:_invalid_purchase_rejection
scope.10.kind=function
scope.10.startLine=105
scope.10.endLine=115
scope.10.semanticHash=355ba5f258a6c029
scope.11.id=function:_start_request
scope.11.kind=function
scope.11.startLine=117
scope.11.endLine=120
scope.11.semanticHash=960bb096df8f71ea
scope.12.id=function:purchase.start
scope.12.kind=function
scope.12.startLine=122
scope.12.endLine=144
scope.12.semanticHash=fbe215877a6e851c
]]

local purchase = require("src.app.cosmetics.transaction_purchase")
local transaction_result = require("src.app.cosmetics.transaction_result")
local transaction_state = require("src.app.cosmetics.transaction_state")

local completion = {}

local function _pending_or_rejection(panel, role_id, product_id)
  local key = transaction_state.role_key(role_id)
  local pending = key and panel.pending_skin_purchase_by_role[key] or nil
  if pending == nil then
    return nil, transaction_state.rejected(panel, "pending_purchase_missing")
  end
  if pending.product_id ~= product_id then
    return nil, transaction_state.rejected(panel, "pending_purchase_mismatch")
  end
  return pending, nil
end

local function _product_or_rejection(panel, product_id)
  return transaction_result.value_or_rejection(panel, transaction_state.skin_by_product(product_id), "missing_product")
end

local function _accepted_purchase_complete(panel, role_id, skin)
  return transaction_result.accepted_equipped_skin(panel, role_id, skin, {
    action = "purchase_complete",
    purchase_fulfilled = true,
    ownership_changed = true,
  })
end

function completion.complete_skin_purchase(root_state, role_id, product_id)
  local panel, rejected = transaction_result.panel_or_rejection(root_state)
  if rejected ~= nil then
    return rejected
  end
  local _, pending_rejected = _pending_or_rejection(panel, role_id, product_id)
  if pending_rejected ~= nil then
    return pending_rejected
  end
  local skin, product_rejected = _product_or_rejection(panel, product_id)
  if product_rejected ~= nil then
    return product_rejected
  end
  purchase.clear_pending(panel, role_id)
  transaction_state.mark_owned(panel, role_id, skin, "purchase")
  return _accepted_purchase_complete(panel, role_id, skin)
end

return completion

--[[ mutate4lua-manifest
version=4
projectHash=721c7fe6e3bb25f1
scope.0.id=chunk:src/app/cosmetics/transaction_completion.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=50
scope.0.semanticHash=5e02d6c6b9545145
scope.1.id=function:_pending_or_rejection
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=17
scope.1.semanticHash=d149ceb08c2ae1f4
scope.2.id=function:_product_or_rejection
scope.2.kind=function
scope.2.startLine=19
scope.2.endLine=21
scope.2.semanticHash=65f10eefc59e4037
scope.3.id=function:_accepted_purchase_complete
scope.3.kind=function
scope.3.startLine=23
scope.3.endLine=29
scope.3.semanticHash=d4a801d7f6a44731
scope.4.id=function:completion.complete_skin_purchase
scope.4.kind=function
scope.4.startLine=31
scope.4.endLine=47
scope.4.semanticHash=1cc1b7642f445e12
]]

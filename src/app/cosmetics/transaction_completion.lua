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
version=2
projectHash=4ce187f0dfb70b95
scope.0.id=chunk:src/app/cosmetics/transaction_completion.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=50
scope.0.semanticHash=39e87336e13dff21
scope.0.lastMutatedAt=2026-06-24T16:13:32Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=3
scope.0.lastMutationKilled=3
scope.1.id=function:_pending_or_rejection:7
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=17
scope.1.semanticHash=4fc2da57982f9f54
scope.1.lastMutatedAt=2026-06-24T16:13:32Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=7
scope.1.lastMutationKilled=7
scope.2.id=function:_product_or_rejection:19
scope.2.kind=function
scope.2.startLine=19
scope.2.endLine=21
scope.2.semanticHash=8b830b2c64b4a555
scope.2.lastMutatedAt=2026-06-24T16:13:32Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=1
scope.2.lastMutationKilled=1
scope.3.id=function:_accepted_purchase_complete:23
scope.3.kind=function
scope.3.startLine=23
scope.3.endLine=29
scope.3.semanticHash=9025cd30615aea44
scope.3.lastMutatedAt=2026-06-24T16:13:32Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=1
scope.3.lastMutationKilled=1
scope.4.id=function:completion.complete_skin_purchase:31
scope.4.kind=function
scope.4.startLine=31
scope.4.endLine=47
scope.4.semanticHash=0c5cecc3de5bfa4a
scope.4.lastMutatedAt=2026-06-24T16:13:32Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=9
scope.4.lastMutationKilled=9
]]

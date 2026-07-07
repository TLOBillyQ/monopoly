local transaction_state = require("src.app.cosmetics.transaction_state")

local queries = {}

function queries.is_slot_equipped(root_state, slot_index)
  local panel = root_state and root_state.ui and root_state.ui.skin_panel or nil
  if panel == nil or panel.role_id == nil then
    return false
  end
  local skin = transaction_state.skin_at(panel, slot_index)
  if skin == nil then
    return false
  end
  return transaction_state.equipped_product(panel, panel.role_id) == skin.product_id
end

function queries.slot_view_model(root_state, slot_index, catalog)
  local panel = root_state and root_state.ui and root_state.ui.skin_panel or nil
  return transaction_state.slot_view_model(panel, panel and panel.role_id or nil, slot_index, catalog)
end

function queries.slot_view_models(root_state, catalog)
  local panel = root_state and root_state.ui and root_state.ui.skin_panel or nil
  return transaction_state.slot_view_models(panel, panel and panel.role_id or nil, catalog)
end

function queries.equipped_product(root_state, role_id)
  local panel = root_state and root_state.ui and root_state.ui.skin_panel or nil
  return transaction_state.equipped_product(panel, role_id)
end

return queries

--[[ mutate4lua-manifest
version=2
projectHash=cd2b2d91d0aca780
scope.0.id=chunk:src/app/cosmetics/transaction_queries.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=33
scope.0.semanticHash=67410c0f4e5b2694
scope.0.lastMutatedAt=2026-07-07T03:14:54Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=1
scope.0.lastMutationKilled=1
scope.1.id=function:queries.is_slot_equipped:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=15
scope.1.semanticHash=132c87ad017ba44a
scope.1.lastMutatedAt=2026-07-07T03:14:54Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=12
scope.1.lastMutationKilled=12
scope.2.id=function:queries.slot_view_model:17
scope.2.kind=function
scope.2.startLine=17
scope.2.endLine=20
scope.2.semanticHash=d6a7428dbd9d48e9
scope.2.lastMutatedAt=2026-07-07T03:14:54Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=4
scope.2.lastMutationKilled=4
scope.3.id=function:queries.slot_view_models:22
scope.3.kind=function
scope.3.startLine=22
scope.3.endLine=25
scope.3.semanticHash=0bb50045abdcd693
scope.3.lastMutatedAt=2026-07-07T03:14:54Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=4
scope.3.lastMutationKilled=4
scope.4.id=function:queries.equipped_product:27
scope.4.kind=function
scope.4.startLine=27
scope.4.endLine=30
scope.4.semanticHash=1f4497c51993c63c
scope.4.lastMutatedAt=2026-07-07T03:14:54Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=4
scope.4.lastMutationKilled=4
]]

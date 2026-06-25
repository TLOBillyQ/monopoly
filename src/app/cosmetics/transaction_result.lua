local transaction_context = require("src.app.cosmetics.transaction_context")
local transaction_state = require("src.app.cosmetics.transaction_state")

local result = {}

function result.panel_or_rejection(root_state)
  local panel, err = transaction_state.ensure_panel(root_state)
  if panel == nil then
    return nil, transaction_state.rejected(nil, err)
  end
  return panel, nil
end

function result.value_or_rejection(panel, value, reason)
  if value == nil then
    return nil, transaction_state.rejected(panel, reason)
  end
  return value, nil
end

local function _equipped_skin_fields(fields, skin, applied)
  fields.equipped_product = skin.product_id
  fields.panel_should_close = true
  fields.slot_view_dirty = true
  fields.host_action_attempted = transaction_context.has_equip_adapter()
  fields.host_action_result = applied
  fields.notification = "已换装 " .. tostring(skin.name)
  return fields
end

function result.accepted_equipped_skin(panel, role_id, skin, fields)
  local applied = transaction_state.apply_equip(panel, role_id, skin)
  panel.open = false
  return transaction_state.accepted(panel, _equipped_skin_fields(fields, skin, applied))
end

return result

--[[ mutate4lua-manifest
version=2
projectHash=4824d17a85286226
scope.0.id=chunk:src/app/cosmetics/transaction_result.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=38
scope.0.semanticHash=4f97886ecd7d3879
scope.0.lastMutatedAt=2026-06-24T16:18:39Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=2
scope.0.lastMutationKilled=2
scope.1.id=function:result.panel_or_rejection:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=12
scope.1.semanticHash=0f7cdad454c8ba8a
scope.1.lastMutatedAt=2026-06-24T16:18:39Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=3
scope.1.lastMutationKilled=3
scope.2.id=function:result.value_or_rejection:14
scope.2.kind=function
scope.2.startLine=14
scope.2.endLine=19
scope.2.semanticHash=b390c0b60bc16987
scope.2.lastMutatedAt=2026-06-24T16:18:39Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=2
scope.2.lastMutationKilled=2
scope.3.id=function:_equipped_skin_fields:21
scope.3.kind=function
scope.3.startLine=21
scope.3.endLine=29
scope.3.semanticHash=ebacabd62859e4d5
scope.3.lastMutatedAt=2026-06-24T16:18:39Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=5
scope.3.lastMutationKilled=5
scope.4.id=function:result.accepted_equipped_skin:31
scope.4.kind=function
scope.4.startLine=31
scope.4.endLine=35
scope.4.semanticHash=e97d08df8f62b183
scope.4.lastMutatedAt=2026-06-24T16:18:39Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=3
scope.4.lastMutationKilled=3
]]

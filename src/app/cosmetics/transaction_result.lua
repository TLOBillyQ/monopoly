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
version=4
projectHash=87e3c3cbdc8e9ff9
scope.0.id=chunk:src/app/cosmetics/transaction_result.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=38
scope.0.semanticHash=b358404a572d73da
scope.1.id=function:result.panel_or_rejection
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=12
scope.1.semanticHash=5875887962bfc1dd
scope.2.id=function:result.value_or_rejection
scope.2.kind=function
scope.2.startLine=14
scope.2.endLine=19
scope.2.semanticHash=54d46eab4bb6d243
scope.3.id=function:_equipped_skin_fields
scope.3.kind=function
scope.3.startLine=21
scope.3.endLine=29
scope.3.semanticHash=c6f0a80dfcf0d3f9
scope.4.id=function:result.accepted_equipped_skin
scope.4.kind=function
scope.4.startLine=31
scope.4.endLine=35
scope.4.semanticHash=75e727df759ece13
]]

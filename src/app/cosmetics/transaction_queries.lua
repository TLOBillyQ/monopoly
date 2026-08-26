local transaction_state = require("src.app.cosmetics.transaction_state")

local queries = {}

local function _skin_panel(root_state)
  return root_state and root_state.ui and root_state.ui.skin_panel or nil
end

function queries.is_slot_equipped(root_state, slot_index)
  local panel = _skin_panel(root_state)
  if panel == nil or panel.role_id == nil then
    return false
  end
  local skin = transaction_state.skin_at(panel, slot_index)
  if skin == nil then
    return false
  end
  return transaction_state.equipped_product(panel, panel.role_id) == skin.product_id
end

-- role_id 兜底只住 read_model 一处(`role_id or (panel and panel.role_id)`,
-- transaction_state 直连 read_model):这里再写 `panel.role_id or nil` 是冗余
-- 兜底,or→and 变异观测等价(#293 等价变异体,删冗余源码处置)。
function queries.slot_view_model(root_state, slot_index, catalog)
  local panel = _skin_panel(root_state)
  return transaction_state.slot_view_model(panel, nil, slot_index, catalog)
end

function queries.slot_view_models(root_state, catalog)
  local panel = _skin_panel(root_state)
  return transaction_state.slot_view_models(panel, nil, catalog)
end

function queries.equipped_product(root_state, role_id)
  local panel = _skin_panel(root_state)
  return transaction_state.equipped_product(panel, role_id)
end

return queries

--[[ mutate4lua-manifest
version=4
projectHash=b66fb14b9d5b2220
scope.0.id=chunk:src/app/cosmetics/transaction_queries.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=40
scope.0.semanticHash=d6466debefc279d3
scope.1.id=function:_skin_panel
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=7
scope.1.semanticHash=c250138038aa193a
scope.2.id=function:queries.is_slot_equipped
scope.2.kind=function
scope.2.startLine=9
scope.2.endLine=19
scope.2.semanticHash=60b7a0cc0f1c8521
scope.3.id=function:queries.slot_view_model
scope.3.kind=function
scope.3.startLine=24
scope.3.endLine=27
scope.3.semanticHash=6275d1f374bcc37f
scope.4.id=function:queries.slot_view_models
scope.4.kind=function
scope.4.startLine=29
scope.4.endLine=32
scope.4.semanticHash=c6b8ad6f79cd9e35
scope.5.id=function:queries.equipped_product
scope.5.kind=function
scope.5.startLine=34
scope.5.endLine=37
scope.5.semanticHash=9777cac48bf200bb
]]

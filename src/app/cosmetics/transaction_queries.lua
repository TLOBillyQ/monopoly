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

local core = require("src.presentation.api.ui_view_service.core")

local M = {}

function M.refresh_item_slots(state, ui_model, opts)
  local ui = state.ui
  assert(ui ~= nil and ui.item_slots ~= nil, "missing ui item slots")
  opts = opts or {}

  local slots = ui.item_slots
  local item_ids = {}
  local role_id = opts.role_id
  local display_player_id = opts.display_player_id or ui_model.current_player_id
  local allow_interact = opts.allow_interact ~= false
  local by_player = ui_model.item_slots_by_player_id or ui_model.item_slots_by_player or {}
  local items = by_player[display_player_id] or ui_model.item_slots or {}
  local allow_use = ui_model and ui_model.choice and ui_model.choice.kind == "item_phase_choice"
  local choice_owner_id = ui_model and ui_model.item_choice_owner_id or ui_model.current_player_id
  local refs = state.ui_refs
  local empty_key = refs["Empty"]
  local allow_slot_click = allow_use == true
    and allow_interact == true
    and display_player_id ~= nil
    and choice_owner_id == display_player_id

  for index, slot_name in ipairs(slots) do
    local item_id = items[index]
    if item_id then
      local image_key = refs[tostring(item_id)] or refs[item_id] or empty_key
      core.set_item_slot_image(slot_name, image_key)
      ui:set_touch_enabled(slot_name, allow_slot_click)
      item_ids[index] = item_id
    else
      core.set_item_slot_image(slot_name, empty_key)
      ui:set_touch_enabled(slot_name, false)
    end
  end

  if role_id ~= nil then
    if type(ui.item_slot_item_ids_by_role) ~= "table" then
      ui.item_slot_item_ids_by_role = {}
    end
    ui.item_slot_item_ids_by_role[role_id] = item_ids
  end
  ui.item_slot_item_ids = item_ids
end

return M

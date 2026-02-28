local core = require("src.presentation.api.ui_view_service.core")

local M = {}

local function _build_option_id_set(choice)
  local out = {}
  if not (choice and type(choice.options) == "table") then
    return out
  end
  for _, option in ipairs(choice.options) do
    local option_id = option
    if type(option) == "table" then
      option_id = option.id
    end
    if option_id ~= nil then
      out[tostring(option_id)] = true
    end
  end
  return out
end

local function _set_outline_visible(ui, outline_name, visible)
  if outline_name and ui and ui.set_visible then
    ui:set_visible(outline_name, visible == true)
  end
end

local function _set_outline_touch_enabled(ui, outline_name, enabled)
  if outline_name and ui and ui.set_touch_enabled then
    ui:set_touch_enabled(outline_name, enabled == true)
  end
end

function M.refresh_item_slots(state, ui_model, opts)
  local ui = state.ui
  assert(ui ~= nil and ui.item_slots ~= nil, "missing ui item slots")
  opts = opts or {}

  local slots = ui.item_slots
  local outlines = ui.card_outlines or {}
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
  local option_id_set = _build_option_id_set(ui_model and ui_model.choice or nil)

  for index, slot_name in ipairs(slots) do
    local item_id = items[index]
    local outline_name = outlines[index]
    local can_pick = false
    if item_id then
      local image_key = refs[tostring(item_id)] or refs[item_id] or empty_key
      core.set_item_slot_image(slot_name, image_key)
      can_pick = allow_slot_click and option_id_set[tostring(item_id)] == true
      ui:set_touch_enabled(slot_name, can_pick)
      item_ids[index] = item_id
    else
      core.set_item_slot_image(slot_name, empty_key)
      ui:set_touch_enabled(slot_name, false)
    end
    _set_outline_visible(ui, outline_name, can_pick)
    _set_outline_touch_enabled(ui, outline_name, can_pick)
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

local core = require("src.presentation.adapter.ui_view_service.core")
local runtime = require("src.presentation.adapter.ui_runtime_port")
local ui_events = require("src.presentation.shared.ui_events")
local runtime_ports = require("src.core.ports.runtime_ports")
local gameplay_rules = require("src.core.config.gameplay_rules")
local role_id_utils = require("src.core.utils.role_id")
local choice_common = require("src.presentation.widgets.choice_screen_service.common")

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

local function _emit_slot_animation(index, event_prefix)
  local event_name = event_prefix .. tostring(index)
  local role = runtime.get_client_role()
  if role then
    ui_events.send_to_role(role, event_name, {})
    return
  end
  ui_events.send_to_all(event_name, {})
end

local function _emit_global_reset_animation()
  local role = runtime.get_client_role()
  local event_name = "重置高亮"
  if role then
    ui_events.send_to_role(role, event_name, {})
    return
  end
  ui_events.send_to_all(event_name, {})
end

local function _reset_slot_animation(index)
  _emit_slot_animation(index, "重置高亮道具槽位牌")
end

local function _build_pickable_signature(slot_pickable)
  local out = {}
  for index, can_pick in ipairs(slot_pickable) do
    if can_pick then
      out[#out + 1] = tostring(index)
    end
  end
  return table.concat(out, ",")
end

local function _resolve_gate_key(choice_id, role_id, display_player_id)
  return table.concat({
    tostring(choice_id or "none"),
    tostring(role_id or "global"),
    tostring(display_player_id or "none"),
  }, "|")
end

local function _ensure_gate_store(state)
  local gate = state._item_slot_highlight_gate
  if type(gate) ~= "table" then
    gate = {}
    state._item_slot_highlight_gate = gate
  end
  return gate
end

local function _emit_pickable_slot_animation(slot_pickable)
  _emit_global_reset_animation()
  for index, can_pick in ipairs(slot_pickable) do
    if not can_pick then
      _reset_slot_animation(index)
    end
  end
  for index, can_pick in ipairs(slot_pickable) do
    if can_pick then
      _emit_slot_animation(index, "高亮道具槽位牌")
    end
  end
end

local function _apply_outline_state(ui, outlines, slot_pickable, visible_enabled)
  local enabled = visible_enabled == true
  for index, outline_name in ipairs(outlines) do
    local can_pick = slot_pickable[index] == true
    local visible = enabled and can_pick
    _set_outline_visible(ui, outline_name, visible)
    _set_outline_touch_enabled(ui, outline_name, visible)
  end
end

function M.refresh_item_slots(state, ui_model, opts)
  local ui = state.ui
  assert(ui ~= nil and ui.item_slots ~= nil, "missing ui item slots")
  opts = opts or {}

  local slots = ui.item_slots
  local outlines = ui.card_outlines or {}
  local item_ids = {}
  local role_id = role_id_utils.normalize(opts.role_id)
  local display_player_id = role_id_utils.normalize(opts.display_player_id or ui_model.current_player_id)
  local allow_interact = opts.allow_interact ~= false
  local by_player = ui_model.item_slots_by_player_id or ui_model.item_slots_by_player or {}
  local items = role_id_utils.read(by_player, display_player_id) or ui_model.item_slots or {}
  local choice = ui_model and ui_model.choice or nil
  local allow_use = choice_common.uses_item_slots(choice)
  local choice_owner_id = role_id_utils.normalize(ui_model and ui_model.item_choice_owner_id or ui_model.current_player_id)
  local refs = state.ui_refs or {}
  local image_refs = refs.images or {}
  local empty_key = image_refs["Empty"]
  local allow_slot_click = allow_use == true
    and allow_interact == true
    and display_player_id ~= nil
    and role_id_utils.equals(choice_owner_id, display_player_id)
  local option_id_set = _build_option_id_set(choice)
  local slot_pickable = {}
  local choice_id = choice and choice.id or nil
  local suppress_flag = state._suppress_item_slot_highlight_until_pick == true

  for index, slot_name in ipairs(slots) do
    local item_id = items[index]
    local outline_name = outlines[index]
    local can_pick = false
    if item_id then
      local image_key = image_refs[tostring(item_id)] or image_refs[item_id] or empty_key
      core.set_item_slot_image(slot_name, image_key)
      can_pick = allow_slot_click and option_id_set[tostring(item_id)] == true
      ui:set_touch_enabled(slot_name, can_pick)
      item_ids[index] = item_id
    else
      core.set_item_slot_image(slot_name, empty_key)
      ui:set_touch_enabled(slot_name, false)
    end
    slot_pickable[index] = can_pick
  end

  local is_item_phase_ask = choice_common.requires_item_slot_pre_confirm(choice) and state._item_phase_ask_active == true
  local gate_store = _ensure_gate_store(state)
  local gate_key = _resolve_gate_key(choice_id, role_id, display_player_id)

  if is_item_phase_ask then
    local signature = _build_pickable_signature(slot_pickable)
    local gate = gate_store[gate_key]
    local needs_replay = gate == nil
      or gate.slot_signature ~= signature
      or gate.choice_id ~= choice_id

    if needs_replay then
      local token = (gate and gate.timer_token or 0) + 1
      gate = {
        choice_id = choice_id,
        slot_signature = signature,
        timer_token = token,
        ready = false,
      }
      gate_store[gate_key] = gate
      _emit_pickable_slot_animation(slot_pickable)

      local delay_seconds = gameplay_rules.item_slot_highlight_anim_delay_seconds or 0.35
      runtime_ports.schedule(delay_seconds, function()
        local current_gate = state and state._item_slot_highlight_gate and state._item_slot_highlight_gate[gate_key] or nil
        if current_gate and current_gate.timer_token == token then
          current_gate.ready = true
          state.ui_dirty = true
        end
      end)
    end

    _apply_outline_state(ui, outlines, slot_pickable, gate.ready == true)
  else
    gate_store[gate_key] = nil

  local suppress_slot_highlight_anim = suppress_flag
      and choice_common.uses_item_slots(choice)
    local skip_replay_for_confirmed_item_phase = choice_common.uses_item_slots(choice)
      and state._skip_item_slot_highlight_replay_choice_id ~= nil
      and tostring(state._skip_item_slot_highlight_replay_choice_id) == tostring(choice_id)
    if not suppress_slot_highlight_anim and not skip_replay_for_confirmed_item_phase then
      _emit_pickable_slot_animation(slot_pickable)
    end
    if not (choice_common.uses_item_slots(choice)
      and tostring(state._skip_item_slot_highlight_replay_choice_id) == tostring(choice_id)) then
      state._skip_item_slot_highlight_replay_choice_id = nil
    end
    _apply_outline_state(ui, outlines, slot_pickable, true)
  end

  if role_id ~= nil then
    if type(ui.item_slot_item_ids_by_role) ~= "table" then
      ui.item_slot_item_ids_by_role = {}
    end
    role_id_utils.write(ui.item_slot_item_ids_by_role, role_id, item_ids)
  end
  ui.item_slot_item_ids = item_ids
end

return M

local ui_nodes = require("src.ui.render.node_ops")
local runtime = require("src.ui.render.runtime_ui")
local ui_events = require("src.ui.coord.ui_events")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local runtime_state = require("src.ui.state.runtime")
local timing = require("src.config.gameplay.timing")
local role_id_utils = require("src.foundation.identity")
local choice_support = require("src.ui.view.choice_support")

local M = {}

local _option_id_set = {}
local _cached_option_choice_ref

local function _build_option_id_set(choice)
  if not (choice and type(choice.options) == "table") then
    return _option_id_set
  end
  if choice.options == _cached_option_choice_ref then
    return _option_id_set
  end
  _cached_option_choice_ref = choice.options
  for k in pairs(_option_id_set) do
    _option_id_set[k] = nil
  end
  for _, option in ipairs(choice.options) do
    local option_id = option
    if type(option) == "table" then
      option_id = option.id
    end
    if option_id ~= nil then
      _option_id_set[tostring(option_id)] = true
    end
  end
  return _option_id_set
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

local _empty_event_payload = {}

local function _emit_ui_event(event_name)
  local role = runtime.get_client_role()
  if role then
    ui_events.send_to_role(role, event_name, _empty_event_payload)
    return
  end
  ui_events.send_to_all(event_name, _empty_event_payload)
end

local function _emit_slot_animation(index, event_prefix)
  _emit_ui_event(event_prefix .. tostring(index))
end

local function _emit_global_reset_animation()
  _emit_ui_event("重置高亮")
end

local _sig_parts = {}

local function _build_pickable_signature(slot_pickable)
  local n = 0
  for index, can_pick in ipairs(slot_pickable) do
    if can_pick then
      n = n + 1
      _sig_parts[n] = tostring(index)
    end
  end
  for i = n + 1, #_sig_parts do
    _sig_parts[i] = nil
  end
  return table.concat(_sig_parts, ",")
end

local function _resolve_gate_key(choice_id, role_id, display_player_id)
  return tostring(choice_id or "none") .. "|" .. tostring(role_id or "global") .. "|" .. tostring(display_player_id or "none")
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
      _emit_slot_animation(index, "重置高亮道具槽位牌")
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

local function _allow_slot_click(choice, opts, ui_model, display_player_id)
  if not choice_support.uses_item_slots(choice) then
    return false
  end
  if opts.allow_interact == false or display_player_id == nil then
    return false
  end
  local owner_id = role_id_utils.normalize(ui_model and ui_model.item_choice_owner_id or ui_model.current_player_id)
  return role_id_utils.equals(owner_id, display_player_id)
end

local _empty_items_fallback = {}

local function _resolve_item_slot_items(ui_model, display_player_id)
  local by_player = ui_model.item_slots_by_player_id or ui_model.item_slots_by_player or _empty_items_fallback
  return role_id_utils.read(by_player, display_player_id) or ui_model.item_slots or _empty_items_fallback
end

local _cached_ctx = {}
local _empty_outlines = {}
local _item_ids_pool = {}
local _nil_role_key = {}

local function _pool_item_ids(role_id)
  local key = role_id ~= nil and role_id or _nil_role_key
  local ids = _item_ids_pool[key]
  if ids == nil then
    ids = {}
    _item_ids_pool[key] = ids
  else
    for k in pairs(ids) do ids[k] = nil end
  end
  return ids
end

local function _fill_refresh_context(ui, state, ui_model, opts, choice, display_player_id, image_refs)
  local role_id = role_id_utils.normalize(opts.role_id)
  _cached_ctx.ui = ui
  _cached_ctx.slots = ui.item_slots
  _cached_ctx.outlines = ui.card_outlines or _empty_outlines
  _cached_ctx.item_ids = _pool_item_ids(role_id)
  _cached_ctx.role_id = role_id
  _cached_ctx.display_player_id = display_player_id
  _cached_ctx.items = _resolve_item_slot_items(ui_model, display_player_id)
  _cached_ctx.choice = choice
  _cached_ctx.allow_slot_click = _allow_slot_click(choice, opts, ui_model, display_player_id)
  _cached_ctx.option_id_set = _build_option_id_set(choice)
  _cached_ctx.empty_key = image_refs["Empty"]
  _cached_ctx.choice_id = choice and choice.id or nil
  _cached_ctx.suppress_flag = state._suppress_item_slot_highlight_until_pick == true
  return _cached_ctx
end

local function _build_refresh_context(state, ui_model, opts)
  local ui = state.ui
  assert(ui ~= nil and ui.item_slots ~= nil, "missing ui item slots")
  opts = opts or {}
  local choice = ui_model and ui_model.choice or nil
  local refs = state.ui_refs or {}
  local image_refs = refs.images or {}
  local display_player_id = role_id_utils.normalize(opts.display_player_id or ui_model.current_player_id)
  return _fill_refresh_context(ui, state, ui_model, opts, choice, display_player_id, image_refs)
end

local _slot_pickable = {}

local function _sync_one_slot(ctx, slot_name, item_id, slot_state, index, slot_pickable)
  if item_id then
    local image_key = (ctx.image_refs and (ctx.image_refs[tostring(item_id)] or ctx.image_refs[item_id])) or ctx.empty_key
    ui_nodes.set_item_slot_image(slot_name, image_key)
    local is_pickable = ctx.allow_slot_click and ctx.option_id_set[tostring(item_id)] == true
    ctx.ui:set_touch_enabled(slot_name, is_pickable or (slot_state and slot_state.item_id ~= nil and not slot_state.available))
    ctx.item_ids[index] = item_id
    slot_pickable[index] = is_pickable
  else
    ui_nodes.set_item_slot_image(slot_name, ctx.empty_key)
    ctx.ui:set_touch_enabled(slot_name, false)
    slot_pickable[index] = false
  end
end

local function _sync_slot_images(ctx)
  for i = 1, #_slot_pickable do _slot_pickable[i] = nil end
  local slot_pickable = _slot_pickable
  for index, slot_name in ipairs(ctx.slots) do
    local slot_state = ctx.choice and ctx.choice.slot_states and ctx.choice.slot_states[index]
    local item_id = (slot_state and slot_state.item_id) or ctx.items[index]
    _sync_one_slot(ctx, slot_name, item_id, slot_state, index, slot_pickable)
  end
  return slot_pickable
end

local function _schedule_highlight_ready(state, gate_key, token)
  local delay_seconds = timing.item_slot_highlight_anim_delay_seconds or 0.35
  runtime_ports.schedule(delay_seconds, function()
    local current_gate = state and state._item_slot_highlight_gate and state._item_slot_highlight_gate[gate_key] or nil
    if current_gate and current_gate.timer_token == token then
      current_gate.ready = true
      runtime_state.set_ui_dirty(state, true)
    end
  end)
end

local function _refresh_item_phase_gate(state, gate_store, gate_key, choice_id, slot_pickable)
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
    _schedule_highlight_ready(state, gate_key, token)
  end
  return gate
end

local function _should_skip_highlight_replay(state, choice, choice_id)
  return choice_support.uses_item_slots(choice)
    and state._skip_item_slot_highlight_replay_choice_id ~= nil
    and tostring(state._skip_item_slot_highlight_replay_choice_id) == tostring(choice_id)
end

local function _refresh_highlight_state(state, ctx, slot_pickable)
  local is_item_phase_ask = choice_support.requires_item_slot_pre_confirm(ctx.choice)
    and state._item_phase_ask_active == true
  local gate_store = _ensure_gate_store(state)
  local gate_key = _resolve_gate_key(ctx.choice_id, ctx.role_id, ctx.display_player_id)
  local passive_gate_key = gate_key .. "|passive"
  if is_item_phase_ask then
    local gate = _refresh_item_phase_gate(state, gate_store, gate_key, ctx.choice_id, slot_pickable)
    _apply_outline_state(ctx.ui, ctx.outlines, slot_pickable, gate.ready == true)
    return
  end
  gate_store[gate_key] = nil
  local suppress_slot_highlight_anim = ctx.suppress_flag and choice_support.uses_item_slots(ctx.choice)
  local skip_replay = _should_skip_highlight_replay(state, ctx.choice, ctx.choice_id)
  local passive_signature = _build_pickable_signature(slot_pickable)
  local passive_gate = gate_store[passive_gate_key]
  local should_replay_passive = passive_gate == nil
    or passive_gate.slot_signature ~= passive_signature
    or passive_gate.choice_id ~= ctx.choice_id
  if not suppress_slot_highlight_anim and not skip_replay and should_replay_passive then
    _emit_pickable_slot_animation(slot_pickable)
    gate_store[passive_gate_key] = {
      choice_id = ctx.choice_id,
      slot_signature = passive_signature,
    }
  end
  if not skip_replay then
    state._skip_item_slot_highlight_replay_choice_id = nil
  end
  _apply_outline_state(ctx.ui, ctx.outlines, slot_pickable, true)
end

local function _store_item_ids(ui, role_id, item_ids)
  if role_id ~= nil then
    if type(ui.item_slot_item_ids_by_role) ~= "table" then
      ui.item_slot_item_ids_by_role = {}
    end
    role_id_utils.write(ui.item_slot_item_ids_by_role, role_id, item_ids)
  end
  ui.item_slot_item_ids = item_ids
end

local function _maybe_emit_phase_advance_reset(state)
  local turn = state and state.game and state.game.turn or nil
  if turn == nil then
    return
  end
  local signature = tostring(turn.phase or "") .. "|" .. tostring(turn.item_phase_active or "")
  if state._last_observed_turn_phase_signature == signature then
    return
  end
  state._last_observed_turn_phase_signature = signature
  _emit_global_reset_animation()
end

function M.refresh_item_slots(state, ui_model, opts)
  _maybe_emit_phase_advance_reset(state)
  local ctx = _build_refresh_context(state, ui_model, opts)
  ctx.image_refs = state.ui_refs and state.ui_refs.images or {}
  local slot_pickable = _sync_slot_images(ctx)
  _refresh_highlight_state(state, ctx, slot_pickable)
  _store_item_ids(ctx.ui, ctx.role_id, ctx.item_ids)
end

return M

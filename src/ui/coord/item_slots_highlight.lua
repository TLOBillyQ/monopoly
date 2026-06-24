local runtime_ports = require("src.foundation.ports.runtime_ports")
local runtime_state = require("src.ui.state.runtime")
local timing = require("src.config.gameplay.timing")
local choice_support = require("src.ui.view.choice_support")
local events = require("src.ui.coord.item_slots_events")

local M = {}

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

local function _phase_gate_needs_replay(gate, signature, choice_id)
  if gate == nil then
    return true
  end
  if gate.slot_signature ~= signature then
    return true
  end
  return gate.choice_id ~= choice_id
end

local function _new_phase_gate(choice_id, signature, token)
  return {
    choice_id = choice_id,
    slot_signature = signature,
    timer_token = token,
    ready = false,
  }
end

local function _refresh_item_phase_gate(state, gate_store, gate_key, choice_id, slot_pickable)
  local signature = events.build_pickable_signature(slot_pickable)
  local gate = gate_store[gate_key]
  if _phase_gate_needs_replay(gate, signature, choice_id) then
    local token = (gate and gate.timer_token or 0) + 1
    gate = _new_phase_gate(choice_id, signature, token)
    gate_store[gate_key] = gate
    events.emit_pickable_slot_animation(slot_pickable)
    _schedule_highlight_ready(state, gate_key, token)
  end
  return gate
end

local function _should_skip_highlight_replay(state, choice, choice_id)
  return choice_support.uses_item_slots(choice)
    and state._skip_item_slot_highlight_replay_choice_id ~= nil
    and tostring(state._skip_item_slot_highlight_replay_choice_id) == tostring(choice_id)
end

local function _refresh_item_phase_ask_highlight(state, ctx, slot_pickable, gate_store, gate_key)
  local gate = _refresh_item_phase_gate(state, gate_store, gate_key, ctx.choice_id, slot_pickable)
  events.apply_outline_state(ctx.ui, ctx.outlines, slot_pickable, gate.ready == true)
end

local function _should_replay_passive_animation(gate_store, passive_gate_key, passive_signature, choice_id)
  local passive_gate = gate_store[passive_gate_key]
  if passive_gate == nil then
    return true
  end
  if passive_gate.slot_signature ~= passive_signature then
    return true
  end
  return passive_gate.choice_id ~= choice_id
end

local function _update_passive_gate(gate_store, passive_gate_key, state, ctx, slot_pickable)
  local suppress_slot_highlight_anim = ctx.suppress_flag and choice_support.uses_item_slots(ctx.choice)
  local skip_replay = _should_skip_highlight_replay(state, ctx.choice, ctx.choice_id)
  local passive_signature = events.build_pickable_signature(slot_pickable)
  if not suppress_slot_highlight_anim and not skip_replay
      and _should_replay_passive_animation(gate_store, passive_gate_key, passive_signature, ctx.choice_id) then
    events.emit_pickable_slot_animation(slot_pickable)
    gate_store[passive_gate_key] = {
      choice_id = ctx.choice_id,
      slot_signature = passive_signature,
    }
  end
  if not skip_replay then
    state._skip_item_slot_highlight_replay_choice_id = nil
  end
end

function M.refresh_highlight_state(state, ctx, slot_pickable)
  local is_item_phase_ask = choice_support.requires_item_slot_pre_confirm(ctx.choice)
    and state._item_phase_ask_active == true
  local gate_store = _ensure_gate_store(state)
  local gate_key = _resolve_gate_key(ctx.choice_id, ctx.role_id, ctx.display_player_id)
  if is_item_phase_ask then
    _refresh_item_phase_ask_highlight(state, ctx, slot_pickable, gate_store, gate_key)
    return
  end
  gate_store[gate_key] = nil
  local passive_gate_key = gate_key .. "|passive"
  _update_passive_gate(gate_store, passive_gate_key, state, ctx, slot_pickable)
  events.apply_outline_state(ctx.ui, ctx.outlines, slot_pickable, true)
end

function M.maybe_emit_phase_advance_reset(state)
  local turn = state and state.game and state.game.turn or nil
  if turn == nil then
    return
  end
  local signature = tostring(turn.phase or "") .. "|" .. tostring(turn.item_phase_active or "")
  if state._last_observed_turn_phase_signature == signature then
    return
  end
  state._last_observed_turn_phase_signature = signature
  events.emit_global_reset_animation()
end

return M

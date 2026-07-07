local runtime_ports = require("src.foundation.ports.runtime_ports")
local runtime_state = require("src.ui.state.runtime")
local timing = require("src.config.gameplay.timing")
local choice_support = require("src.ui.view.choice_support")
local pending_confirmation = require("src.ui.state.pending_confirmation")
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
    and pending_confirmation.is_source_active(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
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

--[[ mutate4lua-manifest
version=2
projectHash=073619db91f21cba
scope.0.id=chunk:src/ui/coord/item_slots_highlight.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=133
scope.0.semanticHash=0e6ab66e49b8c13c
scope.0.lastMutatedAt=2026-06-24T20:10:28Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=5
scope.0.lastMutationKilled=5
scope.1.id=function:_resolve_gate_key:9
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=11
scope.1.semanticHash=b1bc7b5f345bc691
scope.1.lastMutatedAt=2026-06-24T20:10:28Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=5
scope.1.lastMutationKilled=5
scope.2.id=function:_ensure_gate_store:13
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=20
scope.2.semanticHash=f22f6488e2bbb859
scope.2.lastMutatedAt=2026-06-24T20:10:28Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=3
scope.2.lastMutationKilled=3
scope.3.id=function:anonymous@24:24
scope.3.kind=function
scope.3.startLine=24
scope.3.endLine=30
scope.3.semanticHash=b8995c6da87c4c89
scope.4.id=function:_schedule_highlight_ready:22
scope.4.kind=function
scope.4.startLine=22
scope.4.endLine=31
scope.4.semanticHash=e6edfa6e783b4a10
scope.4.lastMutatedAt=2026-06-24T20:10:28Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=survived
scope.4.lastMutationSites=2
scope.4.lastMutationKilled=1
scope.5.id=function:_phase_gate_needs_replay:33
scope.5.kind=function
scope.5.startLine=33
scope.5.endLine=41
scope.5.semanticHash=1326efaaf42339f2
scope.5.lastMutatedAt=2026-06-24T20:10:28Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=survived
scope.5.lastMutationSites=5
scope.5.lastMutationKilled=4
scope.6.id=function:_new_phase_gate:43
scope.6.kind=function
scope.6.startLine=43
scope.6.endLine=50
scope.6.semanticHash=e80aabd23ec7a9e5
scope.6.lastMutatedAt=2026-06-24T20:10:28Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=1
scope.6.lastMutationKilled=1
scope.7.id=function:_refresh_item_phase_gate:52
scope.7.kind=function
scope.7.startLine=52
scope.7.endLine=63
scope.7.semanticHash=a3f7484b31c31aa5
scope.7.lastMutatedAt=2026-06-24T20:10:28Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=survived
scope.7.lastMutationSites=10
scope.7.lastMutationKilled=6
scope.8.id=function:_should_skip_highlight_replay:65
scope.8.kind=function
scope.8.startLine=65
scope.8.endLine=69
scope.8.semanticHash=d8f7e191ec60f817
scope.8.lastMutatedAt=2026-06-24T20:10:28Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=7
scope.8.lastMutationKilled=7
scope.9.id=function:_refresh_item_phase_ask_highlight:71
scope.9.kind=function
scope.9.startLine=71
scope.9.endLine=74
scope.9.semanticHash=33cdbdf1c61961ed
scope.9.lastMutatedAt=2026-06-24T20:10:28Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=2
scope.9.lastMutationKilled=2
scope.10.id=function:_should_replay_passive_animation:76
scope.10.kind=function
scope.10.startLine=76
scope.10.endLine=85
scope.10.semanticHash=535cdcfdc16a641f
scope.10.lastMutatedAt=2026-06-24T20:10:28Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=5
scope.10.lastMutationKilled=5
scope.11.id=function:_update_passive_gate:87
scope.11.kind=function
scope.11.startLine=87
scope.11.endLine=102
scope.11.semanticHash=9658cc5ca372a87a
scope.11.lastMutatedAt=2026-06-24T20:10:28Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=survived
scope.11.lastMutationSites=11
scope.11.lastMutationKilled=10
scope.12.id=function:M.refresh_highlight_state:104
scope.12.kind=function
scope.12.startLine=104
scope.12.endLine=117
scope.12.semanticHash=7e568557106a4855
scope.12.lastMutatedAt=2026-06-24T20:10:28Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=passed
scope.12.lastMutationSites=10
scope.12.lastMutationKilled=10
scope.13.id=function:M.maybe_emit_phase_advance_reset:119
scope.13.kind=function
scope.13.startLine=119
scope.13.endLine=130
scope.13.semanticHash=3cc1f3b6a21c069d
scope.13.lastMutatedAt=2026-06-24T20:10:28Z
scope.13.lastMutationLane=behavior
scope.13.lastMutationStatus=passed
scope.13.lastMutationSites=9
scope.13.lastMutationKilled=9
]]

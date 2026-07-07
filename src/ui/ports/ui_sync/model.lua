local runtime_state = require("src.ui.state.runtime")
local turn_ui_sync_shared = require("src.state.ui_sync_shared")
local landing_visual_hold = require("src.ui.visual_hold")
local modal = require("src.ui.coord.modal")
local main_view = require("src.ui.coord.ui_runtime")
local view_model = require("src.ui.view")
local choice_ui_state = require("src.ui.ports.ui_sync.choice_state")
local ui_gate_sync = require("src.ui.ports.ui_sync.gate")

local ui_model_sync = {}
local _close_modal_gate = {}

local function _mark_ui_dirty_from_runtime(state, dirty)
  if runtime_state.is_ui_dirty(state) then
    dirty.ui = true
  end
end

local function _defer_refresh_for_landing_hold(state, dirty)
  if not landing_visual_hold.should_defer(state) then
    return false
  end
  landing_visual_hold.freeze_active_ui(state)
  if dirty.any or dirty.ui then
    landing_visual_hold.defer_dirty(state, dirty)
  end
  return true
end

local function _update_runtime_ui_model(state, game, dirty)
  local env = turn_ui_sync_shared.build_ui_env(state, game)
  local next_model = view_model.update(runtime_state.get_ui_model(state), game, env, dirty)
  runtime_state.set_ui_model(state, next_model)
  return next_model
end

local function _refresh_turn_label(state, next_model)
  local panel = next_model and next_model.panel or nil
  main_view.refresh_turn_label(
    state,
    panel and panel.turn_label or "",
    panel and panel.countdown_visible
  )
end

local function _should_open_choice_modal(game, state, next_model, dirty)
  local phase = game and game.turn and game.turn.phase or nil
  if not (next_model and next_model.choice) then
    return false
  end
  if choice_ui_state.is_phase_input_blocked(phase) then
    return false
  end
  local route_key = choice_ui_state.resolve_route_key(next_model.choice)
  if route_key == "base_inline" or route_key == "item_phase_passive" then
    return true
  end
  if route_key == "market" and next_model.market ~= nil then
    if dirty and dirty.market == true then
      return true
    end
    return choice_ui_state.should_reconcile(game, state, next_model.choice)
  end
  return choice_ui_state.should_reconcile(game, state, next_model.choice)
end

local function _should_close_choice_modal(state, next_model)
  local gate = ui_gate_sync.snapshot(state and state.ui or nil, _close_modal_gate)
  if not gate.choice_active then
    return false
  end
  return not (next_model and next_model.choice)
end

local function _render_ui_model(game, state, next_model, dirty, common)
  main_view.render(state, next_model, common.log_once, common.build_log_prefix)
  if _should_close_choice_modal(state, next_model) then
    modal.close_choice_modal(state)
    return
  end
  if _should_open_choice_modal(game, state, next_model, dirty) then
    modal.open_choice_modal(state, next_model.choice, next_model.market)
  end
end

function ui_model_sync.apply_input_lock(state)
  main_view.apply_input_lock(state)
end

function ui_model_sync.build_model(state, game)
  local env = turn_ui_sync_shared.build_ui_env(state, game)
  return view_model.build(game, env)
end

function ui_model_sync.refresh_from_dirty(game, state, dirty, common)
  landing_visual_hold.sync_state_from_game(state, game)
  _mark_ui_dirty_from_runtime(state, dirty)
  if _defer_refresh_for_landing_hold(state, dirty) then
    return false
  end
  if not (dirty.any or dirty.ui) then
    return false
  end
  local only_countdown = turn_ui_sync_shared.is_only_turn_countdown(dirty)
  local next_model = _update_runtime_ui_model(state, game, dirty)
  if only_countdown then
    _refresh_turn_label(state, next_model)
  else
    _render_ui_model(game, state, next_model, dirty, common)
  end
  runtime_state.set_ui_dirty(state, false)
  return not only_countdown
end

local function _resolve_reconciled_choice_model(game, state, pending)
  local model = runtime_state.get_ui_model(state)
  if model and model.choice and model.choice.id == pending.id then
    return model
  end

  model = ui_model_sync.build_model(state, game)
  runtime_state.set_ui_model(state, model)
  return model
end

function ui_model_sync.reopen_choice_modal_if_needed(game, state, pending)
  if not choice_ui_state.should_reconcile(game, state, pending) then
    return false
  end
  local model = _resolve_reconciled_choice_model(game, state, pending)
  if not (model and model.choice) then
    return false
  end
  modal.open_choice_modal(state, model.choice, model.market)
  return true
end

return ui_model_sync

--[[ mutate4lua-manifest
version=2
projectHash=4753472a5dcea604
scope.0.id=chunk:src/ui/ports/ui_sync/model.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=140
scope.0.semanticHash=7b546b846e2a56f2
scope.0.lastMutatedAt=2026-05-29T14:23:36Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=7
scope.0.lastMutationKilled=7
scope.1.id=function:_mark_ui_dirty_from_runtime:11
scope.1.kind=function
scope.1.startLine=11
scope.1.endLine=15
scope.1.semanticHash=695be1b4c792fd8c
scope.1.lastMutatedAt=2026-05-29T14:23:36Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=2
scope.1.lastMutationKilled=2
scope.2.id=function:_defer_refresh_for_landing_hold:17
scope.2.kind=function
scope.2.startLine=17
scope.2.endLine=26
scope.2.semanticHash=90938e2cc6c26ff0
scope.2.lastMutatedAt=2026-05-29T14:23:36Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=7
scope.2.lastMutationKilled=7
scope.3.id=function:_update_runtime_ui_model:28
scope.3.kind=function
scope.3.startLine=28
scope.3.endLine=33
scope.3.semanticHash=70f00b6773374ed3
scope.3.lastMutatedAt=2026-05-29T14:23:36Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=3
scope.3.lastMutationKilled=3
scope.4.id=function:_refresh_turn_label:35
scope.4.kind=function
scope.4.startLine=35
scope.4.endLine=42
scope.4.semanticHash=8510242be7bd446f
scope.4.lastMutatedAt=2026-05-29T14:23:36Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=3
scope.4.lastMutationKilled=3
scope.5.id=function:_should_open_choice_modal:44
scope.5.kind=function
scope.5.startLine=44
scope.5.endLine=63
scope.5.semanticHash=8be66c3eb9822460
scope.5.lastMutatedAt=2026-05-29T14:23:36Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=25
scope.5.lastMutationKilled=25
scope.6.id=function:_should_close_choice_modal:65
scope.6.kind=function
scope.6.startLine=65
scope.6.endLine=74
scope.6.semanticHash=07f1d9fb02fb3223
scope.6.lastMutatedAt=2026-05-29T14:23:36Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=8
scope.6.lastMutationKilled=8
scope.7.id=function:_render_ui_model:76
scope.7.kind=function
scope.7.startLine=76
scope.7.endLine=85
scope.7.semanticHash=9aad7c81987b9d63
scope.7.lastMutatedAt=2026-05-29T14:23:36Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=5
scope.7.lastMutationKilled=5
scope.8.id=function:ui_model_sync.apply_input_lock:87
scope.8.kind=function
scope.8.startLine=87
scope.8.endLine=89
scope.8.semanticHash=421627ac44666cf1
scope.8.lastMutatedAt=2026-05-29T14:23:36Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=1
scope.8.lastMutationKilled=1
scope.9.id=function:ui_model_sync.build_model:91
scope.9.kind=function
scope.9.startLine=91
scope.9.endLine=94
scope.9.semanticHash=28845b00dae4700d
scope.9.lastMutatedAt=2026-05-29T14:23:36Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=2
scope.9.lastMutationKilled=2
scope.10.id=function:ui_model_sync.refresh_from_dirty:96
scope.10.kind=function
scope.10.startLine=96
scope.10.endLine=114
scope.10.semanticHash=06f51446f8d5b02c
scope.10.lastMutatedAt=2026-05-29T14:23:36Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=13
scope.10.lastMutationKilled=13
scope.11.id=function:_resolve_reconciled_choice_model:116
scope.11.kind=function
scope.11.startLine=116
scope.11.endLine=125
scope.11.semanticHash=b9a9ea3a8f43ab94
scope.11.lastMutatedAt=2026-05-29T14:23:36Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=6
scope.11.lastMutationKilled=6
scope.12.id=function:ui_model_sync.reopen_choice_modal_if_needed:127
scope.12.kind=function
scope.12.startLine=127
scope.12.endLine=137
scope.12.semanticHash=d639a87ae018ee86
scope.12.lastMutatedAt=2026-05-29T14:23:36Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=passed
scope.12.lastMutationSites=9
scope.12.lastMutationKilled=9
]]

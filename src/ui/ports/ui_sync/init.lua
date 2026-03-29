local ui_model_sync = require("src.ui.ports.ui_sync.model")
local camera_sync = require("src.ui.ports.ui_sync.camera")
local ui_gate_sync = require("src.ui.ports.ui_sync.gate")
local choice_ui_state = require("src.ui.ports.ui_sync.choice_state")
local target_choice_effects = require("src.ui.ctl.target_choice_effects")
local modal = require("src.ui.ctl.modal")
local runtime_state = require("src.ui.state")

local ui_sync_ports = {}

local function _resolve_reconciled_choice_model(game, state, pending)
  local model = runtime_state.get_ui_model(state)
  if model and model.choice and model.choice.id == pending.id then
    return model
  end

  model = ui_model_sync.build_model(state, game)
  runtime_state.set_ui_model(state, model)
  return model
end

local function _reopen_choice_modal_if_needed(game, state, pending)
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

function ui_sync_ports.build(common)
  return {
    apply_input_lock = ui_model_sync.apply_input_lock,
    on_pending_choice = function(game, state, pending)
      runtime_state.set_ui_dirty(state, true)
      _reopen_choice_modal_if_needed(game, state, pending)
    end,
    resolve_choice_ui_state = function(game, state, choice)
      return choice_ui_state.resolve_gate_state(game, state, choice)
    end,
    step_target_selection = function(game, state, dt)
      return target_choice_effects.step(game, state, dt)
    end,
    build_model = ui_model_sync.build_model,
    refresh_from_dirty = function(game, state, dirty)
      return ui_model_sync.refresh_from_dirty(game, state, dirty, common)
    end,
    follow_camera = function(state, player_id)
      return camera_sync.follow_camera(state, player_id)
    end,
    sync_camera_position = function(state)
      return camera_sync.sync_camera_position(state)
    end,
    get_ui_state = function(state)
      return ui_gate_sync.get_ui_state(state, common)
    end,
    resolve_ui_gate = function(state)
      return ui_gate_sync.resolve_ui_gate(state, common)
    end,
    is_input_blocked = function(state)
      return ui_gate_sync.is_input_blocked(state, common)
    end,
    is_popup_active = function(state)
      return ui_gate_sync.is_popup_active(state, common)
    end,
    is_choice_active = function(state)
      return ui_gate_sync.is_choice_active(state, common)
    end,
    is_market_active = function(state)
      return ui_gate_sync.is_market_active(state, common)
    end,
    get_popup_owner_index = function(state)
      return ui_gate_sync.get_popup_owner_index(state, common)
    end,
    set_input_blocked = function(state, blocked)
      return ui_gate_sync.set_input_blocked(state, blocked, common)
    end,
  }
end

return ui_sync_ports

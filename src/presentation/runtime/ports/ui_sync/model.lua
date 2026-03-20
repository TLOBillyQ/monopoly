local turn_ui_sync_shared = require("src.core.ui_sync.turn_ui_sync_shared")
local runtime_state = require("src.ui.runtime.state")
local landing_visual_hold = require("src.ui.runtime.landing_visual_hold")
local choice_ui_state = require("src.presentation.runtime.ports.ui_sync.choice_state")
local modal_controller = require("src.ui.ctl.modal_controller")
local main_view = require("src.ui.ctl.ui_runtime")

local ui_model_sync = {}

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
  local model = require("src.ui.pres")
  local env = turn_ui_sync_shared.build_ui_env(state, game)
  local next_model = model.update(runtime_state.get_ui_model(state), game, env, dirty)
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

local function _should_open_choice_modal(game, state, next_model)
  local phase = game and game.turn and game.turn.phase or nil
  if not (next_model and next_model.choice) then
    return false
  end
  if phase == "wait_action_anim" or phase == "wait_move_anim" then
    return false
  end
  local route_key = choice_ui_state.resolve_route_key(next_model.choice)
  if route_key == "base_inline" then
    return true
  end
  if route_key == "market" and next_model.market ~= nil then
    return true
  end
  return choice_ui_state.should_reconcile(game, state, next_model.choice)
end

local function _render_ui_model(game, state, next_model, common)
  main_view.render(state, next_model, common.log_once, common.build_log_prefix)
  if _should_open_choice_modal(game, state, next_model) then
    modal_controller.open_choice_modal(state, next_model.choice, next_model.market)
  end
end

function ui_model_sync.apply_input_lock(state)
  main_view.apply_input_lock(state)
end

function ui_model_sync.build_model(state, game)
  local model = require("src.ui.pres")
  local env = turn_ui_sync_shared.build_ui_env(state, game)
  return model.build(game, env)
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
    _render_ui_model(game, state, next_model, common)
  end
  runtime_state.set_ui_dirty(state, false)
  return not only_countdown
end

return ui_model_sync

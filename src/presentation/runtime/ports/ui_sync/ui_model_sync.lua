local turn_ui_sync_shared = require("src.core.ui_sync.turn_ui_sync_shared")
local runtime_state = require("src.core.state_access.runtime_state")
local landing_visual_hold = require("src.core.state_access.landing_visual_hold")
local choice_ui_state = require("src.presentation.runtime.ports.ui_sync.choice_ui_state")

local ui_model_sync = {}

function ui_model_sync.apply_input_lock(state)
  local ui_view = require("src.presentation.runtime.view")
  ui_view.apply_input_lock(state)
end

function ui_model_sync.build_model(state, game)
  local model = require("src.presentation.model")
  local env = turn_ui_sync_shared.build_ui_env(state, game)
  return model.build(game, env)
end

function ui_model_sync.refresh_from_dirty(game, state, dirty, common)
  landing_visual_hold.sync_state_from_game(state, game)
  if runtime_state.is_ui_dirty(state) then
    dirty.ui = true
  end
  if landing_visual_hold.is_active_state(state) then
    landing_visual_hold.freeze_active_ui(state)
    if dirty.any or dirty.ui then
      landing_visual_hold.defer_dirty(state, dirty)
    end
    return false
  end
  local only_countdown = turn_ui_sync_shared.is_only_turn_countdown(dirty)
  local ui_refreshed = false
  if dirty.any or dirty.ui then
    local model = require("src.presentation.model")
    local ui_view = require("src.presentation.runtime.view")
    local env = turn_ui_sync_shared.build_ui_env(state, game)
    local next_model = model.update(runtime_state.get_ui_model(state), game, env, dirty)
    runtime_state.set_ui_model(state, next_model)
    if only_countdown then
      ui_view.refresh_turn_label(state, next_model.panel and next_model.panel.turn_label or "")
    else
      ui_view.render(state, next_model, common.log_once, common.build_log_prefix)
      ui_refreshed = true
      local phase = game and game.turn and game.turn.phase or nil
      if next_model.choice and phase ~= "wait_action_anim" and phase ~= "wait_move_anim" then
        local route_key = choice_ui_state.resolve_route_key(next_model.choice)
        if route_key == "base_inline" or choice_ui_state.should_reconcile(game, state, next_model.choice) then
          ui_view.open_choice_modal(state, next_model.choice, next_model.market)
        end
      end
    end
    runtime_state.set_ui_dirty(state, false)
  end
  return ui_refreshed
end

return ui_model_sync

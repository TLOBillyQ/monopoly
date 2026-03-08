local turn_ui_sync_shared = require("src.core.ui_sync.turn_ui_sync_shared")
local runtime_state = require("src.core.state_access.runtime_state")

local ui_model_sync = {}

function ui_model_sync.apply_input_lock(state)
  local ui_view = require("src.presentation.runtime.view_service")
  ui_view.apply_input_lock(state)
end

function ui_model_sync.build_model(state, game)
  local model = require("src.presentation.model.model")
  local env = turn_ui_sync_shared.build_ui_env(state, game)
  return model.build(game, env)
end

function ui_model_sync.refresh_from_dirty(game, state, dirty, common)
  if runtime_state.is_ui_dirty(state) then
    dirty.ui = true
  end
  local only_countdown = turn_ui_sync_shared.is_only_turn_countdown(dirty)
  local ui_refreshed = false
  if dirty.any or dirty.ui then
    local model = require("src.presentation.model.model")
    local ui_view = require("src.presentation.runtime.view_service")
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
        ui_view.open_choice_modal(state, next_model.choice, next_model.market)
      end
    end
    runtime_state.set_ui_dirty(state, false)
  end
  return ui_refreshed
end

return ui_model_sync

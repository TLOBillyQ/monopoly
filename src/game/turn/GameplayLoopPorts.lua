local ui_view = require("src.presentation.api.UIView")
local tick_timeout = require("src.game.turn.TickTimeout")
local tick_ui_sync = require("src.game.turn.TickUISync")
local move_anim = require("src.presentation.render.MoveAnim")

local gameplay_loop_ports = {}

local _action_anim_player = nil

local function _load_action_anim_player()
  if _action_anim_player then
    return _action_anim_player
  end
  _action_anim_player = require("src.presentation.render.ActionAnim")
  return _action_anim_player
end

local function _default_close_choice_modal(state)
  ui_view.close_choice_modal(state)
end

local function _default_open_choice_modal(state, choice, market)
  ui_view.open_choice_modal(state, choice, market)
end

local function _default_apply_input_lock(state)
  ui_view.apply_input_lock(state)
end

local function _apply_role_control_lock_suppress(state, enabled)
  if state.role_control_lock_suppress == nil then
    state.role_control_lock_suppress = 0
  end
  if enabled == true then
    state.role_control_lock_suppress = math.max(0, state.role_control_lock_suppress - 1)
  else
    state.role_control_lock_suppress = state.role_control_lock_suppress + 1
  end
  local should_lock = state.role_control_lock_suppress == 0
  ui_view.apply_role_control_lock(state, should_lock)
end

local function _default_apply_role_control_lock(state, enabled)
  ui_view.apply_role_control_lock(state, enabled)
end

local function _default_play_move_anim(state, anim_ctx)
  if anim_ctx then
    local prev = anim_ctx.on_step_lock
    anim_ctx.on_step_lock = function(enabled, step_time, meta)
      if prev then
        prev(enabled, step_time, meta)
      end
      _apply_role_control_lock_suppress(state, enabled)
    end
  end
  return move_anim.play_sequence(state.board_scene, anim_ctx)
end

local function _default_play_action_anim(state, anim_ctx)
  local player = _load_action_anim_player()
  return player.play(state, anim_ctx)
end

local function _default_step_choice_timeout(game, state, dt)
  tick_timeout.step_default_choice(game, state, dt)
end

local function _default_step_modal_timeout(game, state, dt)
  tick_timeout.step_default_modal(game, state, dt)
end

local function _default_update_countdown(game, state)
  tick_ui_sync.update_countdown(game, state)
end

local function _default_build_model(state, game)
  return tick_ui_sync.build_model(state, game)
end

local function _default_refresh_from_dirty(game, state, dirty)
  return tick_ui_sync.refresh_from_dirty(game, state, dirty)
end

local function _default_log_status(view)
  tick_ui_sync.log_status(view)
end

local function _default_sync_debug_log(state)
  tick_ui_sync.sync_debug_log_panel(state)
end

local function _default_reset_status_3d(state)
  tick_ui_sync.reset_status_3d(state)
end

local function _default_sync_status_3d(game, state, dirty)
  tick_ui_sync.sync_status_3d(game, state, dirty)
end

local default_ports = {
  close_choice_modal = _default_close_choice_modal,
  open_choice_modal = _default_open_choice_modal,
  apply_input_lock = _default_apply_input_lock,
  apply_role_control_lock = _default_apply_role_control_lock,
  play_move_anim = _default_play_move_anim,
  play_action_anim = _default_play_action_anim,
  step_choice_timeout = _default_step_choice_timeout,
  step_modal_timeout = _default_step_modal_timeout,
  update_countdown = _default_update_countdown,
  build_model = _default_build_model,
  refresh_from_dirty = _default_refresh_from_dirty,
  log_status = _default_log_status,
  sync_debug_log = _default_sync_debug_log,
  reset_status_3d = _default_reset_status_3d,
  sync_status_3d = _default_sync_status_3d,
}

function gameplay_loop_ports.resolve(override_ports)
  if not override_ports then
    return default_ports
  end
  local resolved = {}
  for key, fn in pairs(default_ports) do
    if type(override_ports[key]) == "function" then
      resolved[key] = override_ports[key]
    else
      resolved[key] = fn
    end
  end
  return resolved
end

return gameplay_loop_ports

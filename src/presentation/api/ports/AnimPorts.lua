local move_anim = require("src.presentation.render.MoveAnim")

local M = {}

local _action_anim_player = nil

local function _load_action_anim_player()
  if _action_anim_player then
    return _action_anim_player
  end
  _action_anim_player = require("src.presentation.render.ActionAnim")
  return _action_anim_player
end

local function _apply_role_control_lock(state, enabled)
  local ui_view = require("src.presentation.api.UIView")
  ui_view.apply_role_control_lock(state, enabled)
end

local function _apply_role_control_lock_suppress(state, enabled, lock_fn)
  if state.role_control_lock_suppress == nil then
    state.role_control_lock_suppress = 0
  end
  if enabled == true then
    state.role_control_lock_suppress = math.max(0, state.role_control_lock_suppress - 1)
  else
    state.role_control_lock_suppress = state.role_control_lock_suppress + 1
  end
  local should_lock = state.role_control_lock_suppress == 0
  lock_fn(state, should_lock)
end

function M.build()
  return {
    play_move_anim = function(state, anim_ctx)
      if anim_ctx then
        local prev = anim_ctx.on_step_lock
        anim_ctx.on_step_lock = function(enabled, step_time, meta)
          if prev then
            prev(enabled, step_time, meta)
          end
          _apply_role_control_lock_suppress(state, enabled, _apply_role_control_lock)
        end
      end
      return move_anim.play_sequence(state.board_scene, anim_ctx)
    end,
    play_action_anim = function(state, anim_ctx)
      local player = _load_action_anim_player()
      return player.play(state, anim_ctx)
    end,
    reset_status_3d = function(state)
      local ui_status_3d = require("src.presentation.render.UIStatus3DLayer")
      ui_status_3d.reset(state)
    end,
    sync_status_3d = function(game, state, dirty)
      local ui_status_3d = require("src.presentation.render.UIStatus3DLayer")
      ui_status_3d.sync(game, state, dirty)
    end,
  }
end

return M

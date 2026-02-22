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
  local ui_view = require("src.presentation.api.UIViewService")
  ui_view.apply_role_control_lock(state, enabled)
end

local function _update_role_control_lock_exempt(state, enabled, meta, lock_fn)
  local role_id = meta and meta.player_id or nil
  if role_id == nil then
    lock_fn(state, state.role_control_lock_active == true)
    return
  end

  local counts = state.role_control_lock_exempt_count_by_role
  if type(counts) ~= "table" then
    counts = {}
    state.role_control_lock_exempt_count_by_role = counts
  end

  local exempt_by_role = state.role_control_lock_exempt_by_role
  if type(exempt_by_role) ~= "table" then
    exempt_by_role = {}
    state.role_control_lock_exempt_by_role = exempt_by_role
  end

  local current = counts[role_id] or 0
  if enabled == true then
    current = math.max(0, current - 1)
  else
    current = current + 1
  end

  if current <= 0 then
    counts[role_id] = nil
    exempt_by_role[role_id] = nil
  else
    counts[role_id] = current
    exempt_by_role[role_id] = true
  end

  lock_fn(state, state.role_control_lock_active == true)
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
          _update_role_control_lock_exempt(state, enabled, meta, _apply_role_control_lock)
        end
      end
      return move_anim.play_sequence(state.board_scene, anim_ctx)
    end,
    play_action_anim = function(state, anim_ctx)
      local player = _load_action_anim_player()
      return player.play(state, anim_ctx)
    end,
    reset_status_3d = function(state)
      local ui_status_3d = require("src.presentation.render.Status3DService")
      ui_status_3d.reset(state)
    end,
    sync_status_3d = function(game, state, dirty)
      local ui_status_3d = require("src.presentation.render.Status3DService")
      ui_status_3d.sync(game, state, dirty)
    end,
  }
end

return M

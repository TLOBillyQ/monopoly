local move_anim = require("src.ui.render.move_anim")
local runtime_state = require("src.ui.runtime.state")
local role_id_utils = require("src.core.utils.role_id")

local anim_ports = {}

local _action_anim_player = nil

local function _load_action_anim_player()
  if _action_anim_player then
    return _action_anim_player
  end
  _action_anim_player = require("src.ui.render.action_anim")
  return _action_anim_player
end

local function _apply_role_control_lock(state, enabled)
  local ui_view = require("src.ui.ctl.ui_runtime")
  ui_view.apply_role_control_lock(state, enabled)
end

local function _update_role_control_lock_exempt(state, enabled, meta)
  local turn_runtime = runtime_state.ensure_turn_runtime(state)
  local role_id = role_id_utils.normalize(meta and meta.player_id or nil)
  if role_id == nil then
    _apply_role_control_lock(state, turn_runtime.role_control_lock_active == true)
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

  local current = role_id_utils.read(counts, role_id) or 0
  if enabled == true then
    current = math.max(0, current - 1)
  else
    current = current + 1
  end

  if current <= 0 then
    role_id_utils.write(counts, role_id, nil)
    role_id_utils.write(exempt_by_role, role_id, nil)
  else
    role_id_utils.write(counts, role_id, current)
    role_id_utils.write(exempt_by_role, role_id, true)
  end

  _apply_role_control_lock(state, turn_runtime.role_control_lock_active == true)
end

local function _build_sequence_lock_meta(anim_ctx, meta)
  local payload = meta or {}
  payload.player_id = payload.player_id or (anim_ctx and anim_ctx.player_id) or nil
  return payload
end

function anim_ports.build()
  return {
    play_move_anim = function(state, anim_ctx)
      if anim_ctx then
        anim_ctx.state = anim_ctx.state or state
        local turn_runtime = runtime_state.ensure_turn_runtime(state)
        local prev_step_lock = anim_ctx.on_step_lock
        local prev_sequence_lock = anim_ctx.on_sequence_lock
        anim_ctx.role_control_lock_active = turn_runtime.role_control_lock_active == true
        anim_ctx.role_control_exempt = false
        anim_ctx.on_step_lock = function(enabled, step_time, meta)
          if prev_step_lock then
            prev_step_lock(enabled, step_time, meta)
          end
        end
        anim_ctx.on_sequence_lock = function(enabled, total_time, meta)
          local sequence_meta = _build_sequence_lock_meta(anim_ctx, meta)
          if prev_sequence_lock then
            prev_sequence_lock(enabled, total_time, sequence_meta)
          end
          _update_role_control_lock_exempt(state, enabled, sequence_meta)
          anim_ctx.role_control_exempt = enabled ~= true
        end
      end
      return move_anim.play_sequence(state.board_scene, anim_ctx)
    end,
    play_action_anim = function(state, anim_ctx)
      local player = _load_action_anim_player()
      local delay = player.play(state, anim_ctx, {
        runtime_bundle = state and state.presentation_runtime or nil,
      })
      return delay
    end,
    reset_status_3d = function(state)
      local status3d = require("src.ui.render.status3d")
      status3d.reset(state, state and state.presentation_runtime or nil)
    end,
    sync_status_3d = function(game, state, dirty)
      local status3d = require("src.ui.render.status3d")
      status3d.sync(game, state, dirty, state and state.presentation_runtime or nil)
    end,
  }
end

return anim_ports

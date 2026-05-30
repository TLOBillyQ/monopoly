local move_anim = require("src.ui.render.move_anim")
local runtime_state = require("src.ui.state.runtime")
local role_id_utils = require("src.foundation.identity")
local status3d = require("src.ui.render.status3d")
local action_anim_player = require("src.ui.render.anim")
local ui_runtime = require("src.ui.coord.ui_runtime")

local anim_ports = {}

local function _apply_role_control_lock(state, enabled)
  ui_runtime.apply_role_control_lock(state, enabled)
end

local function _ensure_role_lock_tables(state)
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
  return counts, exempt_by_role
end

local function _next_exempt_count(current, enabled)
  if enabled == true then
    return math.max(0, current - 1)
  end
  return current + 1
end

local function _write_role_exempt_state(counts, exempt_by_role, role_id, current)
  if current <= 0 then
    role_id_utils.write(counts, role_id, nil)
    role_id_utils.write(exempt_by_role, role_id, nil)
    return
  end
  role_id_utils.write(counts, role_id, current)
  role_id_utils.write(exempt_by_role, role_id, true)
end

local function _update_role_control_lock_exempt(state, enabled, meta)
  local turn_runtime = runtime_state.ensure_turn_runtime(state)
  local role_id = role_id_utils.normalize(meta and meta.player_id or nil)
  if role_id == nil then
    _apply_role_control_lock(state, turn_runtime.role_control_lock_active == true)
    return
  end

  local counts, exempt_by_role = _ensure_role_lock_tables(state)
  local current = role_id_utils.read(counts, role_id) or 0
  _write_role_exempt_state(counts, exempt_by_role, role_id, _next_exempt_count(current, enabled))
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
      local player = action_anim_player
      local delay = player.play(state, anim_ctx, {
        runtime_bundle = state and state.presentation_runtime or nil,
      })
      return delay
    end,
    reset_status_3d = function(state)
      status3d.reset(state, state and state.presentation_runtime or nil)
    end,
    sync_status_3d = function(game, state, dirty)
      status3d.sync(game, state, dirty, state and state.presentation_runtime or nil)
    end,
  }
end

return anim_ports

--[[ mutate4lua-manifest
version=2
projectHash=f2d6c7179532c265
scope.0.id=chunk:src/ui/ports/anim.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=108
scope.0.semanticHash=eb454dc93fd1f9b8
scope.1.id=function:_apply_role_control_lock:10
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=12
scope.1.semanticHash=369187a32d77cd56
scope.2.id=function:_ensure_role_lock_tables:14
scope.2.kind=function
scope.2.startLine=14
scope.2.endLine=26
scope.2.semanticHash=2e114ca3260e8db0
scope.3.id=function:_next_exempt_count:28
scope.3.kind=function
scope.3.startLine=28
scope.3.endLine=33
scope.3.semanticHash=17ddfbe71d59c316
scope.4.id=function:_write_role_exempt_state:35
scope.4.kind=function
scope.4.startLine=35
scope.4.endLine=43
scope.4.semanticHash=cf68506e6dd2dafd
scope.5.id=function:_update_role_control_lock_exempt:45
scope.5.kind=function
scope.5.startLine=45
scope.5.endLine=57
scope.5.semanticHash=ecf289282d26e872
scope.6.id=function:_build_sequence_lock_meta:59
scope.6.kind=function
scope.6.startLine=59
scope.6.endLine=63
scope.6.semanticHash=a692bba5796f2dd5
scope.7.id=function:anonymous@75:75
scope.7.kind=function
scope.7.startLine=75
scope.7.endLine=79
scope.7.semanticHash=bab61c957f25e257
scope.8.id=function:anonymous@80:80
scope.8.kind=function
scope.8.startLine=80
scope.8.endLine=87
scope.8.semanticHash=cb4837f78c35c5dd
scope.9.id=function:anonymous@67:67
scope.9.kind=function
scope.9.startLine=67
scope.9.endLine=90
scope.9.semanticHash=10786ec2881e5d2c
scope.10.id=function:anonymous@91:91
scope.10.kind=function
scope.10.startLine=91
scope.10.endLine=97
scope.10.semanticHash=b1d169be91d534c6
scope.11.id=function:anonymous@98:98
scope.11.kind=function
scope.11.startLine=98
scope.11.endLine=100
scope.11.semanticHash=f725b7073a62ddca
scope.12.id=function:anonymous@101:101
scope.12.kind=function
scope.12.startLine=101
scope.12.endLine=103
scope.12.semanticHash=4e49f176c4afa976
scope.13.id=function:anim_ports.build:65
scope.13.kind=function
scope.13.startLine=65
scope.13.endLine=105
scope.13.semanticHash=bb5631209105bfc0
]]

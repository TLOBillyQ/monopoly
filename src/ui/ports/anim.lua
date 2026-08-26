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

local function _reapply_role_control_lock(state, turn_runtime)
  _apply_role_control_lock(state, turn_runtime.role_control_lock_active == true)
end

-- 匿名序列（meta 没带 player_id）只重新落一次锁，不记任何 per-role 豁免账。
local function _update_role_control_lock_exempt(state, enabled, meta)
  local turn_runtime = runtime_state.ensure_turn_runtime(state)
  local role_id = role_id_utils.normalize(meta and meta.player_id or nil)
  if role_id == nil then
    _reapply_role_control_lock(state, turn_runtime)
    return
  end

  local counts, exempt_by_role = _ensure_role_lock_tables(state)
  local current = role_id_utils.read(counts, role_id) or 0
  _write_role_exempt_state(counts, exempt_by_role, role_id, _next_exempt_count(current, enabled))
  _reapply_role_control_lock(state, turn_runtime)
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
version=4
projectHash=8e96fa03e0093a99
scope.0.id=chunk:src/ui/ports/anim.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=113
scope.0.semanticHash=678262cdf67a617d
scope.1.id=function:_apply_role_control_lock
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=12
scope.1.semanticHash=4ad1b5cb81e9ede6
scope.2.id=function:_ensure_role_lock_tables
scope.2.kind=function
scope.2.startLine=14
scope.2.endLine=26
scope.2.semanticHash=be1016c0b61401d0
scope.3.id=function:_next_exempt_count
scope.3.kind=function
scope.3.startLine=28
scope.3.endLine=33
scope.3.semanticHash=ed08b197c9eebdcb
scope.4.id=function:_write_role_exempt_state
scope.4.kind=function
scope.4.startLine=35
scope.4.endLine=43
scope.4.semanticHash=2ed0f052beb2e833
scope.5.id=function:_reapply_role_control_lock
scope.5.kind=function
scope.5.startLine=45
scope.5.endLine=47
scope.5.semanticHash=056baf795190df3b
scope.6.id=function:_update_role_control_lock_exempt
scope.6.kind=function
scope.6.startLine=50
scope.6.endLine=62
scope.6.semanticHash=192deb728b820ede
scope.7.id=function:_build_sequence_lock_meta
scope.7.kind=function
scope.7.startLine=64
scope.7.endLine=68
scope.7.semanticHash=957680f5578f5ab2
scope.8.id=function:anim_ports.build
scope.8.kind=function
scope.8.startLine=70
scope.8.endLine=110
scope.8.semanticHash=14e1b13f226ca3b0
scope.9.id=function:<anonymous>
scope.9.kind=function
scope.9.startLine=72
scope.9.endLine=95
scope.9.semanticHash=d57fe03256129942
scope.10.id=function:anim_ctx.on_step_lock
scope.10.kind=function
scope.10.startLine=80
scope.10.endLine=84
scope.10.semanticHash=30701ea535dc6d92
scope.11.id=function:anim_ctx.on_sequence_lock
scope.11.kind=function
scope.11.startLine=85
scope.11.endLine=92
scope.11.semanticHash=352f2acd03cfd2a7
scope.12.id=function:<anonymous>#2
scope.12.kind=function
scope.12.startLine=96
scope.12.endLine=102
scope.12.semanticHash=850482b8211746f4
scope.13.id=function:<anonymous>#3
scope.13.kind=function
scope.13.startLine=103
scope.13.endLine=105
scope.13.semanticHash=d8155ad9764d323f
scope.14.id=function:<anonymous>#4
scope.14.kind=function
scope.14.startLine=106
scope.14.endLine=108
scope.14.semanticHash=80ffd0d1e71d446f
]]

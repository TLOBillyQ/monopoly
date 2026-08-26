-- 选择超时 tick 引擎(#602 拆分):依赖断言、时长/min_visible 决策与
-- 超时裁定主线。簿记(deadline 同步/清算)在 choice_timeout_tracking,
-- 时长解析在 choice_timeout_duration,默认装配在 choice_timeout 门面。
local number_utils = require("src.foundation.number")
local choice_dispatch = require("src.turn.waits.choice_dispatch")
local choice_owner = require("src.turn.choice.owner")
local choice_ui_sync = require("src.turn.waits.choice_ui_sync")
local afk_signal = require("src.turn.policies.afk_signal")
local choice_scope = require("src.turn.deadlines.choice_scope")
local deadlines = require("src.turn.deadlines")
local resolve_port = require("src.turn.output.resolve_port")
local output_state_adapter = require("src.turn.output.state_adapter")
local tracking = require("src.turn.waits.choice_timeout_tracking")

local M = {}

local _tick_min_visible_payload = { mode = "tick_min_visible", elapsed_seconds = 0, min_visible_seconds = 0 }
local _tick_timeout_payload = { mode = "tick_timeout", elapsed_seconds = 0, timeout_seconds = 0, min_visible_seconds = 0 }

local _REQUIRED_DEPENDENCY_KEYS = {
  "on_pending_choice",
  "is_choice_active",
  "resolve_choice_ui_state",
  "build_action",
  "dispatch_action_with_close_choice",
  "get_timeout_seconds",
  "get_min_visible_seconds",
}

local function _assert_dependencies(dependencies)
  assert(type(dependencies) == "table", "missing dependencies")
  for _, key in ipairs(_REQUIRED_DEPENDENCY_KEYS) do
    assert(dependencies[key] ~= nil, "missing dependencies." .. key)
  end
end

local function _resolve_timeout_seconds(game, state, dependencies)
  local timeout = dependencies.get_timeout_seconds(game, state)
  return number_utils.is_numeric(timeout) and timeout or 0
end

local function _resolve_min_visible_seconds(game, state, active_choice, dependencies)
  local min_visible = dependencies.get_min_visible_seconds(game, state, active_choice)
  if number_utils.is_numeric(min_visible) and min_visible >= 0 then
    return min_visible
  end
  return 0
end

local function _maybe_dispatch_min_visible(game, state, active_choice, output_ports, dependencies, pending_choice_elapsed, min_visible)
  if min_visible > 0 and pending_choice_elapsed >= min_visible then
    _tick_min_visible_payload.elapsed_seconds = pending_choice_elapsed
    _tick_min_visible_payload.min_visible_seconds = min_visible
    return choice_dispatch.dispatch_choice_tick_action(
      game, state, active_choice, output_ports, dependencies, _tick_min_visible_payload
    )
  end
  return false
end

local function _is_dispatchable_timeout_action(action)
  return action ~= nil and action.type ~= "choice_force_skip"
end

local function _maybe_resolve_timeout(game, state, active_choice, output_ports, dependencies, pending_choice_elapsed, timeout, min_visible)
  if pending_choice_elapsed < timeout then
    return
  end
  _tick_timeout_payload.elapsed_seconds = pending_choice_elapsed
  _tick_timeout_payload.timeout_seconds = timeout
  _tick_timeout_payload.min_visible_seconds = min_visible
  local action = dependencies.build_action(game, state, active_choice, _tick_timeout_payload)
  local window_kind = choice_scope.for_choice(active_choice)
  local owner_player = choice_owner.resolve_player(game, active_choice)
  if afk_signal.is_timeout_eligible(owner_player) then
    afk_signal.on_timeout_fallback(game, state, owner_player.id, window_kind)
  end
  if _is_dispatchable_timeout_action(action) then
    choice_dispatch.ensure_action_actor_role_id(game, active_choice, action)
    action.input_source = "timeout"
    output_ports.set_pending_choice_elapsed(state, 0)
    dependencies.dispatch_action_with_close_choice(game, state, action)
    return
  end
  output_ports.set_pending_choice_elapsed(state, 0)
  deadlines.resolve_choice(game, state, active_choice, "tick_timeout", action)
end

local function _active_choice_missing(active, active_choice)
  return not active or active_choice == nil
end

local function _is_choice_ui_active(state, dependencies)
  return dependencies.is_choice_active(state) == true
end

local function _resolve_output_ports(state)
  return resolve_port.resolve(state, "output", output_state_adapter)
end

local function _step(dependencies, game, state, dt)
  assert(game ~= nil, "missing game")
  local output_ports = _resolve_output_ports(state)
  local timeout = _resolve_timeout_seconds(game, state, dependencies)
  if timeout <= 0 then
    tracking.reset_tracking(state, output_ports)
    return
  end
  local previous_choice_id = output_ports.get_pending_choice_id(state)
  local pending, active_choice = choice_ui_sync.sync_pending_choice_ui(game, state, dependencies, output_ports)
  local ui_choice_active = _is_choice_ui_active(state, dependencies)
  -- #523:缺屏探针移到 tick 帧 dirty 刷新之后（loop/init.lua _tick_flow 经
  -- probe_choice_ui_missing 端口采样），此处只保留 active 判定做跟踪清算。
  local active = choice_ui_sync.resolve_missing_ui_warning(
    state, game, dependencies, pending, active_choice, ui_choice_active
  )
  if _active_choice_missing(active, active_choice) then
    tracking.reset_tracking(state, output_ports)
    return
  end
  if tracking.maybe_force_skip_owner_missing(game, state, active_choice, output_ports) then
    return
  end
  tracking.sync_tracking(
    state, output_ports, active_choice, previous_choice_id, timeout
  )
  local pending_choice_elapsed = output_ports.get_pending_choice_elapsed(state) + dt
  output_ports.set_pending_choice_elapsed(state, pending_choice_elapsed)
  local min_visible = _resolve_min_visible_seconds(game, state, active_choice, dependencies)
  if _maybe_dispatch_min_visible(
    game, state, active_choice, output_ports, dependencies, pending_choice_elapsed, min_visible
  ) then
    return
  end
  _maybe_resolve_timeout(
    game, state, active_choice, output_ports, dependencies, pending_choice_elapsed, timeout, min_visible
  )
end

function M.new(dependencies)
  _assert_dependencies(dependencies)
  return {
    step = function(game, state, dt)
      return _step(dependencies, game, state, dt)
    end,
  }
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=ff860452a634402a
scope.0.id=chunk:src/turn/waits/choice_timeout_engine.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=150
scope.0.semanticHash=939614b41628777a
scope.1.id=function:_assert_dependencies
scope.1.kind=function
scope.1.startLine=30
scope.1.endLine=35
scope.1.semanticHash=d954925bd94be2a1
scope.2.id=function:_resolve_timeout_seconds
scope.2.kind=function
scope.2.startLine=37
scope.2.endLine=40
scope.2.semanticHash=bb698e3dba6bc643
scope.3.id=function:_resolve_min_visible_seconds
scope.3.kind=function
scope.3.startLine=42
scope.3.endLine=48
scope.3.semanticHash=f585c2c0210eeaf7
scope.4.id=function:_maybe_dispatch_min_visible
scope.4.kind=function
scope.4.startLine=50
scope.4.endLine=59
scope.4.semanticHash=17bb91071c033cdd
scope.5.id=function:_is_dispatchable_timeout_action
scope.5.kind=function
scope.5.startLine=61
scope.5.endLine=63
scope.5.semanticHash=79187b1f00c31eed
scope.6.id=function:_maybe_resolve_timeout
scope.6.kind=function
scope.6.startLine=65
scope.6.endLine=87
scope.6.semanticHash=9676a18e028a3ec4
scope.7.id=function:_active_choice_missing
scope.7.kind=function
scope.7.startLine=89
scope.7.endLine=91
scope.7.semanticHash=1ec0fc5fa6fbccb2
scope.8.id=function:_is_choice_ui_active
scope.8.kind=function
scope.8.startLine=93
scope.8.endLine=95
scope.8.semanticHash=af3e0ea56f9402ec
scope.9.id=function:_resolve_output_ports
scope.9.kind=function
scope.9.startLine=97
scope.9.endLine=99
scope.9.semanticHash=2a83785a68b42a92
scope.10.id=function:_step
scope.10.kind=function
scope.10.startLine=101
scope.10.endLine=138
scope.10.semanticHash=2ac6afa900e11cda
scope.11.id=function:M.new
scope.11.kind=function
scope.11.startLine=140
scope.11.endLine=147
scope.11.semanticHash=f779cc64782e362e
scope.12.id=function:<anonymous>
scope.12.kind=function
scope.12.startLine=143
scope.12.endLine=145
scope.12.semanticHash=609439c0a328e2dc
]]

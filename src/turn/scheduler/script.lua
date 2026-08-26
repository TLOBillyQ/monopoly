-- 回合脚本协程 runner：wait 处理器表、phase 执行与 yield/finish 状态机。
-- 信号泵与 session 构造均由 src.turn.scheduler.runtime 私有协调。
local turn_decision = require("src.turn.waits.decision")
local default_await_handlers = require("src.turn.scheduler.await")
local move_followup = require("src.turn.phases.move_followup")

local M = {}

---@param await_handlers TurnAwaitHandlers?
---@return TurnAwaitHandlers
local function _wait_handlers(await_handlers)
  local await = await_handlers or default_await_handlers
  return {
    wait_action = await.action,
    wait_choice = await.choice,
    wait_move_anim = await.move_anim,
    wait_action_anim = await.action_anim,
    wait_landing_visual = await.landing_visual,
    detained_wait = await.detained,
    inter_turn_wait = await.inter_turn,
    wait_seconds = function(session, args)
      return await.seconds(session, args and args.seconds, args)
    end,
  }
end

local function _resolve_phase_handler(phases, state_name)
  local handler = phases[state_name]
  if handler ~= nil or state_name ~= "move_followup" then
    return handler
  end
  return move_followup.run
end

local function _call_metamethod(value)
  local metatable = type(value) == "table" and getmetatable(value) or nil
  return metatable and metatable.__call or nil
end

local function _is_callable(value)
  return type(value) == "function" or type(_call_metamethod(value)) == "function"
end

local function _run_phase(session, state_name, args)
  local phases = session.phases
  assert(type(phases) == "table", "missing session phases")
  local handler = _resolve_phase_handler(phases, state_name)
  assert(_is_callable(handler), "missing phase handler: " .. tostring(state_name))
  if state_name == "start" then
    turn_decision.log_turn_start(session.game)
  end
  session:mark_phase(state_name)
  local turn_mgr = session.turn_mgr or session
  ---@cast handler function
  return handler(turn_mgr, args)
end

local function _run_wait(session, state_name, args, await_handlers)
  local handler = _wait_handlers(await_handlers)[state_name]
  if handler == nil then
    return nil
  end
  return handler(session, args)
end

local function _set_current_state(session, state_name, state_args)
  session.current_state = state_name
  session.current_args = state_args
end

local _yield_payload = { kind = "wait", wait_state = nil }

local function _yield_wait(session, state_name)
  session.wait_state = state_name
  _yield_payload.wait_state = state_name
  coroutine.yield(_yield_payload)
end

local function _step_script(session, state_name, state_args, await_handlers)
  _set_current_state(session, state_name, state_args)
  local wait_res = _run_wait(session, state_name, state_args, await_handlers)
  if wait_res == nil then
    return _run_phase(session, state_name, state_args)
  end
  if wait_res.wait then
    _yield_wait(session, state_name)
    return state_name, state_args
  end
  return wait_res.next_state, wait_res.next_args
end

local function _finish_script(session)
  session.current_state = nil
  session.current_args = nil
  session.wait_state = nil
  session.finished = true
end

local function _initial_state(session)
  return session.current_state or "start"
end

---@param session table
---@param await_handlers TurnAwaitHandlers?
---@return thread
function M.create(session, await_handlers)
  assert(session ~= nil, "missing script session")
  return coroutine.create(function()
    local state_name = _initial_state(session)
    local state_args = session.current_args
    while state_name do
      state_name, state_args = _step_script(session, state_name, state_args, await_handlers)
    end
    _finish_script(session)
  end)
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=13416ea72e22a7d7
scope.0.id=chunk:src/turn/scheduler/script.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=119
scope.0.semanticHash=7b6e33664459e07d
scope.1.id=function:_wait_handlers
scope.1.kind=function
scope.1.startLine=11
scope.1.endLine=25
scope.1.semanticHash=c82158b1ab5c0cf3
scope.2.id=function:<anonymous>
scope.2.kind=function
scope.2.startLine=21
scope.2.endLine=23
scope.2.semanticHash=ff3121cd5795b1fe
scope.3.id=function:_resolve_phase_handler
scope.3.kind=function
scope.3.startLine=27
scope.3.endLine=33
scope.3.semanticHash=7abbdc07b1725e22
scope.4.id=function:_call_metamethod
scope.4.kind=function
scope.4.startLine=35
scope.4.endLine=38
scope.4.semanticHash=add7886060d45355
scope.5.id=function:_is_callable
scope.5.kind=function
scope.5.startLine=40
scope.5.endLine=42
scope.5.semanticHash=d1a1f3315c9d806e
scope.6.id=function:_run_phase
scope.6.kind=function
scope.6.startLine=44
scope.6.endLine=56
scope.6.semanticHash=6eb8cc06cc73805b
scope.7.id=function:_run_wait
scope.7.kind=function
scope.7.startLine=58
scope.7.endLine=64
scope.7.semanticHash=dd24a6895df76537
scope.8.id=function:_set_current_state
scope.8.kind=function
scope.8.startLine=66
scope.8.endLine=69
scope.8.semanticHash=6cdf6c5f4ef67baf
scope.9.id=function:_yield_wait
scope.9.kind=function
scope.9.startLine=73
scope.9.endLine=77
scope.9.semanticHash=7f77240d11f26595
scope.10.id=function:_step_script
scope.10.kind=function
scope.10.startLine=79
scope.10.endLine=90
scope.10.semanticHash=1567bca00e3b25be
scope.11.id=function:_finish_script
scope.11.kind=function
scope.11.startLine=92
scope.11.endLine=97
scope.11.semanticHash=4d58963c734b8176
scope.12.id=function:_initial_state
scope.12.kind=function
scope.12.startLine=99
scope.12.endLine=101
scope.12.semanticHash=eeb29eb4a1aa96ce
scope.13.id=function:M.create
scope.13.kind=function
scope.13.startLine=106
scope.13.endLine=116
scope.13.semanticHash=5f0af7f901ac3b0a
scope.14.id=function:<anonymous>#2
scope.14.kind=function
scope.14.startLine=108
scope.14.endLine=115
scope.14.semanticHash=5f0fa8e236bc6f31
]]

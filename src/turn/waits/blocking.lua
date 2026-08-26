-- 回合阻塞/等待判定深模块:唯一判定器。
-- 「回合此刻被什么挡住(current_block)」与「带着一个目标 intent 该进入哪个 wait 态、
-- 如何挂 resume 回调(next_wait_state)」全部收敛于此。原先 land.lua 手搓的
-- anim×hold×move_anim×action_anim 组合路由(约130行 + 孪生 _resolve_finished_landing_state)
-- 迁入本模块;land 降为薄委托,保留其被 characterization 钉死的两个导出 seam。
local runtime_state = require("src.state.runtime")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local wait_callbacks = require("src.turn.waits.callback_registry")

local blocking = {}

local function _has_action_anim(game)
  if not game or not game.turn then
    return false
  end
  if game.turn.action_anim then
    return true
  end
  local queue = game.turn.action_anim_queue
  return type(queue) == "table" and #queue > 0
end

-- hold 状态以 state 为源时读其 active 标志;否则回落到 turn 上的标记。
local function _hold_state_active(game)
  local state = game.landing_visual_hold_state
  if state ~= nil and runtime_state.get_landing_visual_hold_source(state) ~= nil then
    return runtime_state.get_landing_visual_hold_active(state)
  end
  return nil
end

local function _turn_hold_active(game)
  local turn = game.turn or nil
  return turn and turn.landing_visual_hold_active == true or false
end

local function _is_landing_visual_hold_active(game)
  if not game then
    return false
  end
  local from_state = _hold_state_active(game)
  if from_state ~= nil then
    return from_state
  end
  return _turn_hold_active(game)
end

local _is_effect_idle = runtime_ports.is_effect_idle

local callback_keys = wait_callbacks.callback_keys

local function _register_action_anim_resume(game, next_state, next_args, callback)
  wait_callbacks.register(game, callback_keys.after_action_anim, callback)
  if next_state == "move_followup" then
    game.turn.move_followup_pending = true
  end
  return "wait_action_anim", {
    next_state = next_state,
    next_args = next_args,
  }
end

local function _register_landing_visual_resume(game, next_state, next_args, callback)
  wait_callbacks.register(game, callback_keys.after_landing_visual, callback)
  return "wait_landing_visual", {
    next_state = next_state,
    next_args = next_args,
  }
end

local function _resume_wait_choice(next_state, next_args)
  return "wait_choice", {
    next_state = next_state,
    next_args = next_args,
  }
end

local function _wait_for_choice_via(register_fn)
  return function(game, next_state, next_args)
    return register_fn(game, "wait_choice", {
      next_state = next_state,
      next_args = next_args,
    }, function()
      return _resume_wait_choice(next_state, next_args)
    end)
  end
end

local _wait_for_choice_via_action_anim = _wait_for_choice_via(_register_action_anim_resume)
local _wait_for_choice_via_landing_visual = _wait_for_choice_via(_register_landing_visual_resume)

local function _wait_for_choice_via_landing_visual_then_action_anim(game, next_state, next_args)
  local action_anim_state, action_anim_args = _wait_for_choice_via_action_anim(game, next_state, next_args)
  return _register_landing_visual_resume(game, action_anim_state, action_anim_args, function()
    return _wait_for_choice_via_action_anim(game, next_state, next_args)
  end)
end

local function _resolve_wait_move_anim(game, next_state, next_args, has_anim, has_hold_or_pending)
  if next_state == "move_followup" then game.turn.move_followup_pending = true end
  local move_anim_args = { next_state = next_state, next_args = next_args }
  local function _resume() return "wait_move_anim", move_anim_args end
  if has_anim then
    if has_hold_or_pending then
      return _register_landing_visual_resume(game, "wait_action_anim", {
        next_state = "wait_move_anim",
        next_args = move_anim_args,
      }, function()
        return _register_action_anim_resume(game, "wait_move_anim", move_anim_args, _resume)
      end)
    end
    return _register_action_anim_resume(game, "wait_move_anim", move_anim_args, _resume)
  end
  if has_hold_or_pending then return _register_landing_visual_resume(game, "wait_move_anim", move_anim_args, _resume) end
  return "wait_move_anim", move_anim_args
end

local function _resolve_wait_action_anim_state(game, next_state, next_args, has_anim, has_hold_or_pending)
  if has_anim then
    if has_hold_or_pending then
      return _register_landing_visual_resume(game, "wait_action_anim", {
        next_state = next_state,
        next_args = next_args,
      }, function()
        return _register_action_anim_resume(game, next_state, next_args, function() return next_state, next_args end)
      end)
    end
    return _register_action_anim_resume(game, next_state, next_args, function() return next_state, next_args end)
  end
  if has_hold_or_pending then
    return _register_landing_visual_resume(game, next_state, next_args, function() return next_state, next_args end)
  end
  return next_state, next_args
end

local function _route_choice_wait_state(game, has_anim, has_hold_or_pending, next_state, next_args)
  if has_anim then
    if has_hold_or_pending then return _wait_for_choice_via_landing_visual_then_action_anim(game, next_state, next_args) end
    return _wait_for_choice_via_action_anim(game, next_state, next_args)
  end
  if has_hold_or_pending then return _wait_for_choice_via_landing_visual(game, next_state, next_args) end
  return "wait_choice", { next_state = next_state, next_args = next_args }
end

-- 唯一等待判定器:给一个目标 (next_state,next_args) 与 wait 标志,
-- 按 action_anim / landing_visual_hold / effect_idle / move_anim 组合,
-- 决定进入哪个 wait 态并挂好 resume 回调。
function blocking.next_wait_state(game, next_state, next_args, wait_action_anim, wait_move_anim)
  local has_anim = _has_action_anim(game)
  local has_hold_or_pending = _is_landing_visual_hold_active(game) or not _is_effect_idle()
  if wait_move_anim == true then
    return _resolve_wait_move_anim(game, next_state, next_args, has_anim, has_hold_or_pending)
  end
  if wait_action_anim == true then
    return _resolve_wait_action_anim_state(game, next_state, next_args, has_anim, has_hold_or_pending)
  end
  return _route_choice_wait_state(game, has_anim, has_hold_or_pending, next_state, next_args)
end

local _PARKED_KINDS = {
  wait_landing_visual = "landing_visual",
  wait_action_anim = "action_anim",
  wait_move_anim = "move_anim",
  wait_choice = "choice",
  wait_action = "action",
}

-- 唯一「卡在什么上」查询:回合停在某个 wait 相时回报其 kind,否则 nil。
local function _turn_phase(game)
  local turn = game and game.turn or nil
  return turn and turn.phase or nil
end

local function _parked_kind(phase)
  return phase and _PARKED_KINDS[phase] or nil
end

function blocking.current_block(game)
  local kind = _parked_kind(_turn_phase(game))
  if kind == nil then
    return nil
  end
  return { kind = kind }
end

return blocking

--[[ mutate4lua-manifest
version=4
projectHash=9d71a60a056ba2e1
scope.0.id=chunk:src/turn/waits/blocking.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=187
scope.0.semanticHash=a9c6e468d5a09d59
scope.1.id=function:_has_action_anim
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=21
scope.1.semanticHash=90e742964d471097
scope.2.id=function:_hold_state_active
scope.2.kind=function
scope.2.startLine=24
scope.2.endLine=30
scope.2.semanticHash=3dca826e781e990e
scope.3.id=function:_turn_hold_active
scope.3.kind=function
scope.3.startLine=32
scope.3.endLine=35
scope.3.semanticHash=d4c6c405ecca2fd1
scope.4.id=function:_is_landing_visual_hold_active
scope.4.kind=function
scope.4.startLine=37
scope.4.endLine=46
scope.4.semanticHash=f7bba3cf5dbf7185
scope.5.id=function:_register_action_anim_resume
scope.5.kind=function
scope.5.startLine=52
scope.5.endLine=61
scope.5.semanticHash=6b29b532b44c847c
scope.6.id=function:_register_landing_visual_resume
scope.6.kind=function
scope.6.startLine=63
scope.6.endLine=69
scope.6.semanticHash=c2a575c2407fdbfc
scope.7.id=function:_resume_wait_choice
scope.7.kind=function
scope.7.startLine=71
scope.7.endLine=76
scope.7.semanticHash=2ab97b7beb1bd1c6
scope.8.id=function:_wait_for_choice_via
scope.8.kind=function
scope.8.startLine=78
scope.8.endLine=87
scope.8.semanticHash=dea9b35287922435
scope.9.id=function:<anonymous>
scope.9.kind=function
scope.9.startLine=79
scope.9.endLine=86
scope.9.semanticHash=fcadfbebfcdd6630
scope.10.id=function:<anonymous>#2
scope.10.kind=function
scope.10.startLine=83
scope.10.endLine=85
scope.10.semanticHash=5076d53a4090f1e9
scope.11.id=function:_wait_for_choice_via_landing_visual_then_action_anim
scope.11.kind=function
scope.11.startLine=92
scope.11.endLine=97
scope.11.semanticHash=603a0237496e779b
scope.12.id=function:<anonymous>#3
scope.12.kind=function
scope.12.startLine=94
scope.12.endLine=96
scope.12.semanticHash=02ac9a604d6b4840
scope.13.id=function:_resolve_wait_move_anim
scope.13.kind=function
scope.13.startLine=99
scope.13.endLine=116
scope.13.semanticHash=c454ed2fca15ced6
scope.14.id=function:_resume
scope.14.kind=function
scope.14.startLine=102
scope.14.endLine=102
scope.14.semanticHash=d5a72e97ef7f8a36
scope.15.id=function:<anonymous>#4
scope.15.kind=function
scope.15.startLine=108
scope.15.endLine=110
scope.15.semanticHash=4e902b637d534560
scope.16.id=function:_resolve_wait_action_anim_state
scope.16.kind=function
scope.16.startLine=118
scope.16.endLine=134
scope.16.semanticHash=05cacdd6cd232886
scope.17.id=function:<anonymous>#5
scope.17.kind=function
scope.17.startLine=124
scope.17.endLine=126
scope.17.semanticHash=51d3cfad65dcb0ec
scope.18.id=function:<anonymous>#6
scope.18.kind=function
scope.18.startLine=125
scope.18.endLine=125
scope.18.semanticHash=e9fac92fc90b088d
scope.19.id=function:<anonymous>#7
scope.19.kind=function
scope.19.startLine=128
scope.19.endLine=128
scope.19.semanticHash=e9fac92fc90b088d
scope.20.id=function:<anonymous>#8
scope.20.kind=function
scope.20.startLine=131
scope.20.endLine=131
scope.20.semanticHash=e9fac92fc90b088d
scope.21.id=function:_route_choice_wait_state
scope.21.kind=function
scope.21.startLine=136
scope.21.endLine=143
scope.21.semanticHash=a08399fa59670487
scope.22.id=function:blocking.next_wait_state
scope.22.kind=function
scope.22.startLine=148
scope.22.endLine=158
scope.22.semanticHash=7bed5a3592858407
scope.23.id=function:_turn_phase
scope.23.kind=function
scope.23.startLine=169
scope.23.endLine=172
scope.23.semanticHash=93c839897afe61e5
scope.24.id=function:_parked_kind
scope.24.kind=function
scope.24.startLine=174
scope.24.endLine=176
scope.24.semanticHash=1231096b3bce9bc0
scope.25.id=function:blocking.current_block
scope.25.kind=function
scope.25.startLine=178
scope.25.endLine=184
scope.25.semanticHash=e1433fe279d0ae31
]]

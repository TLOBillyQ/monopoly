local turn_anim = {}
local runtime_ports = require("src.foundation.ports.runtime_ports")
local runtime_state = require("src.state.runtime")

local _move_anim_opts = {
  anim_key = "move_anim",
  phase = "wait_move_anim",
  phase_label = "move anim",
  seq_key = "move_anim_seq",
  done_action = "move_anim_done",
  on_anim = nil,
}

local _action_anim_opts = {
  anim_key = "action_anim",
  phase = "wait_action_anim",
  phase_label = "action anim",
  seq_key = "action_anim_seq",
  done_action = "action_anim_done",
  on_anim = nil,
}

local function _step_anim(game, state, opts)
  assert(game, "missing game")
  assert(opts, "missing opts")
  assert(opts.on_anim, "missing opts.on_anim")
  assert(opts.anim_key, "missing opts.anim_key")
  assert(opts.phase, "missing opts.phase")
  assert(opts.seq_key, "missing opts.seq_key")
  assert(opts.done_action, "missing opts.done_action")

  local anim = game.turn[opts.anim_key]
  local phase = game.turn.phase
  assert(anim and anim.seq, "missing " .. tostring(opts.anim_key))

  local phase_label = opts.phase_label or "anim"
  assert(phase == opts.phase, "unexpected " .. phase_label .. " phase: " .. tostring(phase))

  local anim_runtime = runtime_state.ensure_anim_runtime(state)
  if anim_runtime[opts.seq_key] == anim.seq then
    return
  end

  anim_runtime[opts.seq_key] = anim.seq
  local ok, delay = pcall(opts.on_anim, state, anim)
  if ok and delay and delay > 0 then
    runtime_ports.schedule(delay, function()
      assert(game.dispatch_action, "missing game.dispatch_action")
      game:dispatch_action({ type = opts.done_action, seq = anim.seq })
    end)
    return
  end
  assert(game.dispatch_action, "missing game.dispatch_action")
  game:dispatch_action({ type = opts.done_action, seq = anim.seq })
end

local function _step_anim_kind(kind_opts, wait_field, on_anim_key)
  return function(game, state, opts)
    assert(state[wait_field] == true, kind_opts.phase_label .. " disabled")
    assert(opts ~= nil and opts[on_anim_key] ~= nil, "missing opts." .. on_anim_key)
    kind_opts.on_anim = opts[on_anim_key]
    _step_anim(game, state, kind_opts)
  end
end

turn_anim.step_move_anim = _step_anim_kind(_move_anim_opts, "wait_move_anim", "on_move_anim")
turn_anim.step_action_anim = _step_anim_kind(_action_anim_opts, "wait_action_anim", "on_action_anim")

return turn_anim

--[[ mutate4lua-manifest
version=2
projectHash=fb740a1a3f16f8e2
scope.0.id=chunk:src/turn/output/anim.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=70
scope.0.semanticHash=08fb568d8c5f4bed
scope.1.id=function:anonymous@47:47
scope.1.kind=function
scope.1.startLine=47
scope.1.endLine=50
scope.1.semanticHash=822f9dc5f7b59ec4
scope.2.id=function:_step_anim:23
scope.2.kind=function
scope.2.startLine=23
scope.2.endLine=55
scope.2.semanticHash=e181321f2749c4db
scope.3.id=function:anonymous@58:58
scope.3.kind=function
scope.3.startLine=58
scope.3.endLine=63
scope.3.semanticHash=c22bcdb5eeac5ae5
scope.4.id=function:_step_anim_kind:57
scope.4.kind=function
scope.4.startLine=57
scope.4.endLine=64
scope.4.semanticHash=e3e92a377490cf75
]]

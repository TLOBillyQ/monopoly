local turn_anim = {}
local runtime_ports = require("src.core.ports.runtime_ports")
local runtime_state = require("src.core.runtime_facade.runtime_state")

function turn_anim.step_anim(game, state, opts)
  assert(game ~= nil, "missing game")
  assert(opts ~= nil and opts.on_anim ~= nil, "missing opts.on_anim")
  assert(opts.anim_key ~= nil, "missing opts.anim_key")
  assert(opts.phase ~= nil, "missing opts.phase")
  assert(opts.seq_key ~= nil, "missing opts.seq_key")
  assert(opts.done_action ~= nil, "missing opts.done_action")

  local anim = game.turn[opts.anim_key]
  local phase = game.turn.phase
  assert(anim ~= nil and anim.seq ~= nil, "missing " .. tostring(opts.anim_key))

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
      assert(game.dispatch_action ~= nil, "missing game.dispatch_action")
      game:dispatch_action({ type = opts.done_action, seq = anim.seq })
    end)
    return
  end
  assert(game.dispatch_action ~= nil, "missing game.dispatch_action")
  game:dispatch_action({ type = opts.done_action, seq = anim.seq })
end

function turn_anim.step_move_anim(game, state, opts)
  assert(state.wait_move_anim == true, "move anim disabled")
  assert(opts ~= nil and opts.on_move_anim ~= nil, "missing opts.on_move_anim")
  turn_anim.step_anim(game, state, {
    anim_key = "move_anim",
    phase = "wait_move_anim",
    phase_label = "move anim",
    seq_key = "move_anim_seq",
    done_action = "move_anim_done",
    on_anim = opts.on_move_anim,
  })
end

function turn_anim.step_action_anim(game, state, opts)
  assert(state.wait_action_anim == true, "action anim disabled")
  assert(opts ~= nil and opts.on_action_anim ~= nil, "missing opts.on_action_anim")
  turn_anim.step_anim(game, state, {
    anim_key = "action_anim",
    phase = "wait_action_anim",
    phase_label = "action anim",
    seq_key = "action_anim_seq",
    done_action = "action_anim_done",
    on_anim = opts.on_action_anim,
  })
end

return turn_anim

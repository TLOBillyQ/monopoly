local turn_anim = {}
local store_paths = require("src.core.StorePaths")

function turn_anim.step_anim(game, state, opts)
  assert(game ~= nil, "missing game")
  assert(game.store ~= nil, "missing game.store")
  assert(opts ~= nil and opts.on_anim ~= nil, "missing opts.on_anim")
  assert(opts.anim_key ~= nil, "missing opts.anim_key")
  assert(opts.phase ~= nil, "missing opts.phase")
  assert(opts.seq_key ~= nil, "missing opts.seq_key")
  assert(opts.done_action ~= nil, "missing opts.done_action")

  local anim_path = store_paths.turn[opts.anim_key]
  local anim = game.store:get(anim_path)
  local phase = game.store:get(store_paths.turn.phase)
  assert(anim ~= nil and anim.seq ~= nil, "missing " .. tostring(opts.anim_key))

  local phase_label = opts.phase_label or "anim"
  assert(phase == opts.phase, "unexpected " .. phase_label .. " phase: " .. tostring(phase))

  if state[opts.seq_key] == anim.seq then
    return
  end

  state[opts.seq_key] = anim.seq
  local ok, delay = pcall(opts.on_anim, state, anim)
  if ok and delay and delay > 0 then
    SetTimeOut(delay, function()
      assert(game.dispatch_action ~= nil, "missing game.dispatch_action")
      game:dispatch_action({ type = opts.done_action, seq = anim.seq })
    end)
    return
  end
  assert(game.dispatch_action ~= nil, "missing game.dispatch_action")
  game:dispatch_action({ type = opts.done_action, seq = anim.seq })
end

return turn_anim

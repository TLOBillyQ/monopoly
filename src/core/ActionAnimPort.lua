local action_anim_port = {}

function action_anim_port.is_enabled(game)
  if not game then
    return false
  end
  local anim_gate_port = assert(game.anim_gate_port, "missing anim_gate_port")
  return anim_gate_port and anim_gate_port.wait_action_anim == true or false
end

function action_anim_port.queue(game, payload)
  if not action_anim_port.is_enabled(game) then
    return false
  end
  if not (game and game.queue_action_anim) then
    return false
  end
  game:queue_action_anim(payload)
  return true
end

return action_anim_port

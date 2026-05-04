local move_anim = {}

function move_anim.is_enabled(game)
  if not game then
    return false
  end
  local anim_gate_port = assert(game.anim_gate_port, "missing anim_gate_port")
  return anim_gate_port.wait_move_anim == true
end

function move_anim.queue(game, payload)
  if not move_anim.is_enabled(game) then
    return false
  end
  if not game.queue_move_anim then
    return false
  end
  game:queue_move_anim(payload)
  return true
end

return move_anim

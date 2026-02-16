local turn_waits = {}

local function _next_action_anim(game)
  assert(game ~= nil and game.turn ~= nil, "missing game.turn")
  local queue = game.turn.action_anim_queue
  if type(queue) ~= "table" or #queue == 0 then
    return nil
  end
  local anim = table.remove(queue, 1)
  game.turn.action_anim = anim
  game.dirty.turn = true
  game.dirty.any = true
  return anim
end

function turn_waits.make_anim_wait(turn_mgr, state_name, anim_key, done_action_type)
  return function(args)
    turn_mgr.game.turn.phase = state_name
    turn_mgr.game.dirty.turn = true
    turn_mgr.game.dirty.any = true
    local anim = turn_mgr.game.turn[anim_key]
    assert(anim ~= nil, "missing " .. anim_key)

    local action = turn_mgr.pending_action
    turn_mgr.pending_action = nil
    if not action or action.type ~= done_action_type then
      return state_name, args
    end
    if action.seq and anim.seq and action.seq ~= anim.seq then
      return state_name, args
    end
    turn_mgr.game.turn[anim_key] = nil
    turn_mgr.game.dirty.turn = true
    turn_mgr.game.dirty.any = true
    return args.resume_state, args.resume_args
  end
end

function turn_waits.wait_action_anim(turn_mgr, args)
  turn_mgr.game.turn.phase = "wait_action_anim"
  turn_mgr.game.dirty.turn = true
  turn_mgr.game.dirty.any = true
  local anim = turn_mgr.game.turn.action_anim
  if not anim then
    local next_anim = _next_action_anim(turn_mgr.game)
    if next_anim then
      return "wait_action_anim", args
    end
    turn_mgr.pending_action = nil
    return args.resume_state, args.resume_args
  end

  local action = turn_mgr.pending_action
  turn_mgr.pending_action = nil
  if not action or action.type ~= "action_anim_done" then
    return "wait_action_anim", args
  end
  if action.seq and anim.seq and action.seq ~= anim.seq then
    return "wait_action_anim", args
  end

  turn_mgr.game.turn.action_anim = nil
  turn_mgr.game.dirty.turn = true
  turn_mgr.game.dirty.any = true

  if _next_action_anim(turn_mgr.game) then
    return "wait_action_anim", args
  end
  return args.resume_state, args.resume_args
end

return turn_waits

local facing_policy = {}

local valid_modes = {
  fresh_forward = true,
  resume_forward = true,
  relative_forward = true,
  relative_backward = true,
}

local function _player_move_dir(player)
  local status = player and player.status or nil
  return status and status.move_dir or nil
end

function facing_policy.resolve_forward_continuation(board, current_index, facing, parity)
  assert(board ~= nil, "missing board")
  assert(current_index ~= nil, "missing current_index")
  local _next_index, _passed_start, next_facing = board:step_forward_by_facing(current_index, facing, parity)
  return next_facing
end

function facing_policy.resolve_forced_move_reset_facing(board, current_index, parity)
  assert(board ~= nil, "missing board")
  assert(current_index ~= nil, "missing current_index")
  local tile = board:get_tile(current_index)
  assert(tile ~= nil, "missing tile: " .. tostring(current_index))
  if tile.type ~= "market" then
    return nil
  end
  return facing_policy.resolve_forward_continuation(board, current_index, nil, parity)
end

function facing_policy.resolve_initial_facing(mode, player, opts)
  opts = opts or {}
  assert(valid_modes[mode] == true, "invalid facing mode: " .. tostring(mode))

  if mode == "fresh_forward" then
    return nil
  end

  if mode == "resume_forward" then
    assert(opts.direction ~= nil, "resume_forward requires opts.direction")
    return opts.direction
  end

  if opts.direction ~= nil then
    return opts.direction
  end

  return _player_move_dir(player)
end

return facing_policy

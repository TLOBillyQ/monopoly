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

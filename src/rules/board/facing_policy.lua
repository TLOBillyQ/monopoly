local facing_policy = {}
local market_default_move_dir = "right"

local valid_modes = {
  fresh_forward = true,
  resume_forward = true,
  relative_forward = true,
  relative_backward = true,
}

local valid_sync_modes = {
  clear = true,
  preserve = true,
  forced_move = true,
}

local function _player_move_dir(player)
  local status = player and player.status or nil
  return status and status.move_dir or nil
end

local function _set_move_dir(game, player, value)
  assert(game ~= nil and type(game.set_player_status) == "function", "missing game.set_player_status")
  if _player_move_dir(player) == value then
    return false
  end
  game:set_player_status(player, "move_dir", value)
  return true
end

function facing_policy.sync_move_dir_after_position_change(game, player, current_index, mode)
  -- Centralize move_dir updates for teleports/relocations so special handlers
  -- don't each re-encode board-facing rules.
  assert(game ~= nil, "missing game")
  assert(player ~= nil, "missing player")
  assert(current_index ~= nil, "missing current_index")
  mode = mode or "preserve"
  assert(valid_sync_modes[mode] == true, "invalid move_dir sync mode: " .. tostring(mode))

  if mode == "clear" then
    return _set_move_dir(game, player, nil)
  end

  if mode == "preserve" then
    return _set_move_dir(game, player, _player_move_dir(player))
  end

  local board = assert(game.board, "missing game.board")
  local tile = assert(board:get_tile(current_index), "missing tile: " .. tostring(current_index))
  if tile.type == "hospital" or tile.type == "mountain" then
    return _set_move_dir(game, player, nil)
  end
  if tile.type == "market" then
    return _set_move_dir(game, player, market_default_move_dir)
  end
  return _set_move_dir(game, player, _player_move_dir(player))
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

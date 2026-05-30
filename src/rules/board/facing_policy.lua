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
    _set_move_dir(game, player, nil)
    return game:set_player_status(player, "skip_next_inner_entry", false)
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

function facing_policy.should_skip_inner_entry(board, player)
  if not (board and board.map and board.map.entry_points and player and player.position) then
    return false
  end
  local status = player.status or nil
  if not (status and status.skip_next_inner_entry == true) then
    return false
  end
  local tile = board:get_tile(player.position)
  return tile ~= nil and board.map.entry_points[tile.id] ~= nil
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

--[[ mutate4lua-manifest
version=2
projectHash=0387a389f679c198
scope.0.id=chunk:src/rules/board/facing_policy.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=93
scope.0.semanticHash=9cf27f7d2718774a
scope.1.id=function:_player_move_dir:17
scope.1.kind=function
scope.1.startLine=17
scope.1.endLine=20
scope.1.semanticHash=580a9003aab7f269
scope.2.id=function:_set_move_dir:22
scope.2.kind=function
scope.2.startLine=22
scope.2.endLine=29
scope.2.semanticHash=d914b51ffca873e1
scope.3.id=function:facing_policy.sync_move_dir_after_position_change:31
scope.3.kind=function
scope.3.startLine=31
scope.3.endLine=58
scope.3.semanticHash=79ecc58df12492cf
scope.4.id=function:facing_policy.should_skip_inner_entry:60
scope.4.kind=function
scope.4.startLine=60
scope.4.endLine=70
scope.4.semanticHash=ba9f34f1dbc9d196
scope.5.id=function:facing_policy.resolve_initial_facing:72
scope.5.kind=function
scope.5.startLine=72
scope.5.endLine=90
scope.5.semanticHash=283b312fe329b9fb
]]

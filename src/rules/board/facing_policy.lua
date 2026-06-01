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

-- tile types that clear move_dir on relocation; market forces a fixed direction
local _tile_type_move_dir = {
  hospital = false,
  mountain = false,
  market = market_default_move_dir,
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

local function _validate_sync_args(game, player, current_index, mode)
  assert(game ~= nil, "missing game")
  assert(player ~= nil, "missing player")
  assert(current_index ~= nil, "missing current_index")
  mode = mode or "preserve"
  assert(valid_sync_modes[mode] == true, "invalid move_dir sync mode: " .. tostring(mode))
  return mode
end

local function _sync_clear_mode(game, player)
  _set_move_dir(game, player, nil)
  return game:set_player_status(player, "skip_next_inner_entry", false)
end

local function _resolve_tile_move_dir(game, current_index)
  local board = assert(game.board, "missing game.board")
  local tile = assert(board:get_tile(current_index), "missing tile: " .. tostring(current_index))
  return _tile_type_move_dir[tile.type]
end

local function _sync_forced_move_mode(game, player, current_index)
  local override = _resolve_tile_move_dir(game, current_index)
  if override == false then
    return _set_move_dir(game, player, nil)
  end
  if override then
    return _set_move_dir(game, player, override)
  end
  return _set_move_dir(game, player, _player_move_dir(player))
end

function facing_policy.sync_move_dir_after_position_change(game, player, current_index, mode)
  -- Centralize move_dir updates for teleports/relocations so special handlers
  -- don't each re-encode board-facing rules.
  mode = _validate_sync_args(game, player, current_index, mode)
  if mode == "clear" then
    return _sync_clear_mode(game, player)
  end
  if mode == "preserve" then
    return _set_move_dir(game, player, _player_move_dir(player))
  end
  return _sync_forced_move_mode(game, player, current_index)
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
projectHash=bab23d6ba1b39376
scope.0.id=chunk:src/rules/board/facing_policy.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=115
scope.0.semanticHash=9c13967a1bfa351c
scope.0.lastMutatedAt=2026-06-01T12:30:31Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=10
scope.0.lastMutationKilled=10
scope.1.id=function:_player_move_dir:24
scope.1.kind=function
scope.1.startLine=24
scope.1.endLine=27
scope.1.semanticHash=580a9003aab7f269
scope.1.lastMutatedAt=2026-06-01T12:30:31Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=4
scope.1.lastMutationKilled=4
scope.2.id=function:_set_move_dir:29
scope.2.kind=function
scope.2.startLine=29
scope.2.endLine=36
scope.2.semanticHash=d914b51ffca873e1
scope.2.lastMutatedAt=2026-06-01T12:30:31Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=6
scope.2.lastMutationKilled=6
scope.3.id=function:_validate_sync_args:38
scope.3.kind=function
scope.3.startLine=38
scope.3.endLine=45
scope.3.semanticHash=7298f3b846d7520b
scope.3.lastMutatedAt=2026-06-01T12:30:31Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=6
scope.3.lastMutationKilled=6
scope.4.id=function:_sync_clear_mode:47
scope.4.kind=function
scope.4.startLine=47
scope.4.endLine=50
scope.4.semanticHash=1a325af1539f9f31
scope.4.lastMutatedAt=2026-06-01T12:30:31Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=2
scope.4.lastMutationKilled=2
scope.5.id=function:_resolve_tile_move_dir:52
scope.5.kind=function
scope.5.startLine=52
scope.5.endLine=56
scope.5.semanticHash=d5146e81aecf884e
scope.5.lastMutatedAt=2026-06-01T12:30:31Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=2
scope.5.lastMutationKilled=2
scope.6.id=function:_sync_forced_move_mode:58
scope.6.kind=function
scope.6.startLine=58
scope.6.endLine=67
scope.6.semanticHash=902539a933e655d6
scope.6.lastMutatedAt=2026-06-01T12:30:31Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=6
scope.6.lastMutationKilled=6
scope.7.id=function:facing_policy.sync_move_dir_after_position_change:69
scope.7.kind=function
scope.7.startLine=69
scope.7.endLine=80
scope.7.semanticHash=872db96a26850a97
scope.7.lastMutatedAt=2026-06-01T12:30:31Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=8
scope.7.lastMutationKilled=8
scope.8.id=function:facing_policy.should_skip_inner_entry:82
scope.8.kind=function
scope.8.startLine=82
scope.8.endLine=92
scope.8.semanticHash=ba9f34f1dbc9d196
scope.8.lastMutatedAt=2026-06-01T12:30:31Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=16
scope.8.lastMutationKilled=16
scope.9.id=function:facing_policy.resolve_initial_facing:94
scope.9.kind=function
scope.9.startLine=94
scope.9.endLine=112
scope.9.semanticHash=283b312fe329b9fb
scope.9.lastMutatedAt=2026-06-01T12:30:31Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=9
scope.9.lastMutationKilled=9
]]

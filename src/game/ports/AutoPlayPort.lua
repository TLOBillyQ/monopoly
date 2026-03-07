local auto_play_port = {}

local function _resolve_port(game)
  assert(game ~= nil, "missing game for auto_play_port")
  local port = game.auto_play_port
  assert(type(port) == "table", "missing game.auto_play_port")
  return port
end

local function _resolve_method(game, key)
  local port = _resolve_port(game)
  local fn = port[key]
  assert(type(fn) == "function", "missing auto_play_port." .. tostring(key))
  return fn
end

function auto_play_port.is_auto_player(game, player)
  return _resolve_method(game, "is_auto_player")(game, player) == true
end

function auto_play_port.pick_target_player(game, player, item_id, candidates)
  return _resolve_method(game, "pick_target_player")(game, player, item_id, candidates)
end

function auto_play_port.pick_remote_dice_value(game, player, dice_count)
  return _resolve_method(game, "pick_remote_dice_value")(game, player, dice_count)
end

function auto_play_port.pick_roadblock_target(game, player, candidates)
  return _resolve_method(game, "pick_roadblock_target")(game, player, candidates)
end

return auto_play_port

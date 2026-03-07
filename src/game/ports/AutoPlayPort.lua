local auto_play_port = {}

local function _fallback_port()
  return require("src.game.runtime.AutoPlayPortAdapter").build()
end

local function _resolve_port(game)
  if not game then
    return nil
  end
  local port = game.auto_play_port
  if type(port) == "table" then
    return port
  end
  return _fallback_port()
end

function auto_play_port.is_auto_player(game, player)
  local port = _resolve_port(game)
  if not port or type(port.is_auto_player) ~= "function" then
    return false
  end
  return port.is_auto_player(game, player) == true
end

function auto_play_port.pick_target_player(game, player, item_id, candidates)
  local port = _resolve_port(game)
  if not port or type(port.pick_target_player) ~= "function" then
    return nil
  end
  return port.pick_target_player(game, player, item_id, candidates)
end

function auto_play_port.pick_remote_dice_value(game, player, dice_count)
  local port = _resolve_port(game)
  if not port or type(port.pick_remote_dice_value) ~= "function" then
    return nil, nil
  end
  return port.pick_remote_dice_value(game, player, dice_count)
end

function auto_play_port.pick_roadblock_target(game, player, candidates)
  local port = _resolve_port(game)
  if not port or type(port.pick_roadblock_target) ~= "function" then
    return nil
  end
  return port.pick_roadblock_target(game, player, candidates)
end

return auto_play_port

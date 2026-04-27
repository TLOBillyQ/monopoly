local agent = require("src.computer.core_agent")
local bankruptcy = require("src.rules.endgame.bankruptcy")

local default_ports = {}

local function _build_missing_port(current, builder)
  if type(current) == "table" then
    return current
  end
  return builder()
end

local function _build_auto_play_port()
  return {
    is_auto_player = function(_, player)
      return agent.is_auto_player(player)
    end,
    pick_target_player = function(game, player, item_id, candidates)
      return agent.pick_target_player(game, player, item_id, candidates)
    end,
    pick_remote_dice_value = function(game, player, dice_count)
      return agent.pick_remote_dice_value(game, player, dice_count)
    end,
    pick_roadblock_target = function(game, player, _candidates)
      return agent.pick_roadblock_target(game, player)
    end,
    auto_action_for_choice = function(game, choice)
      return agent.auto_action_for_choice(game, choice)
    end,
  }
end

local function _build_bankruptcy_port()
  return {
    eliminate = function(game, player, opts)
      return bankruptcy.eliminate(game, player, opts)
    end,
  }
end

function default_ports.resolve_game_opts(opts)
  opts = opts or {}
  opts.auto_play_port = _build_missing_port(opts.auto_play_port, _build_auto_play_port)
  opts.bankruptcy_port = _build_missing_port(opts.bankruptcy_port, _build_bankruptcy_port)
  return opts
end

function default_ports.install(game)
  if type(game) ~= "table" then
    return game
  end
  game.auto_play_port = _build_missing_port(game.auto_play_port, _build_auto_play_port)
  game.bankruptcy_port = _build_missing_port(game.bankruptcy_port, _build_bankruptcy_port)
  return game
end

return default_ports

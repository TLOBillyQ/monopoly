local agent = require("src.computer.agent")
local bankruptcy = require("src.rules.endgame")

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

local function _install_defaults(target)
  target.auto_play_port = _build_missing_port(target.auto_play_port, _build_auto_play_port)
  target.bankruptcy_port = _build_missing_port(target.bankruptcy_port, _build_bankruptcy_port)
  return target
end

function default_ports.resolve_game_opts(opts)
  return _install_defaults(opts or {})
end

function default_ports.install(game)
  if type(game) ~= "table" then
    return game
  end
  return _install_defaults(game)
end

return default_ports

--[[ mutate4lua-manifest
version=2
projectHash=8caf031a8d6bc661
scope.0.id=chunk:src/turn/output/default_ports.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=59
scope.0.semanticHash=08da03d918797609
scope.1.id=function:_build_missing_port:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=11
scope.1.semanticHash=b4b6bfff2b680915
scope.2.id=function:anonymous@15:15
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=17
scope.2.semanticHash=4df2a04229373e2a
scope.3.id=function:anonymous@18:18
scope.3.kind=function
scope.3.startLine=18
scope.3.endLine=20
scope.3.semanticHash=faa1dc75e07ba2b4
scope.4.id=function:anonymous@21:21
scope.4.kind=function
scope.4.startLine=21
scope.4.endLine=23
scope.4.semanticHash=7e744a2f2f0b3463
scope.5.id=function:anonymous@24:24
scope.5.kind=function
scope.5.startLine=24
scope.5.endLine=26
scope.5.semanticHash=1ef8218ecf524a81
scope.6.id=function:anonymous@27:27
scope.6.kind=function
scope.6.startLine=27
scope.6.endLine=29
scope.6.semanticHash=d69a279f9f193467
scope.7.id=function:_build_auto_play_port:13
scope.7.kind=function
scope.7.startLine=13
scope.7.endLine=31
scope.7.semanticHash=478131230743037e
scope.8.id=function:anonymous@35:35
scope.8.kind=function
scope.8.startLine=35
scope.8.endLine=37
scope.8.semanticHash=d518cc48d72a2d05
scope.9.id=function:_build_bankruptcy_port:33
scope.9.kind=function
scope.9.startLine=33
scope.9.endLine=39
scope.9.semanticHash=602a1bc9b4135e51
scope.10.id=function:_install_defaults:41
scope.10.kind=function
scope.10.startLine=41
scope.10.endLine=45
scope.10.semanticHash=b6f0d327b35a9a1d
scope.11.id=function:default_ports.resolve_game_opts:47
scope.11.kind=function
scope.11.startLine=47
scope.11.endLine=49
scope.11.semanticHash=0cacf00fabe3256e
scope.12.id=function:default_ports.install:51
scope.12.kind=function
scope.12.startLine=51
scope.12.endLine=56
scope.12.semanticHash=8bd94423f6543b61
]]

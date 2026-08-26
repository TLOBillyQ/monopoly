local agent = require("src.computer.agent")
local control = require("src.player.control")
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
    is_computer_controlled = function(_, player)
      return control.is_computer_controlled(player)
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
version=4
projectHash=5e4df2279db9e119
scope.0.id=chunk:src/turn/output/default_ports.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=60
scope.0.semanticHash=be1e96d1851ccebf
scope.1.id=function:_build_missing_port
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=12
scope.1.semanticHash=213d1a2a21c993f6
scope.2.id=function:_build_auto_play_port
scope.2.kind=function
scope.2.startLine=14
scope.2.endLine=32
scope.2.semanticHash=71347eb13eb95d93
scope.3.id=function:<anonymous>
scope.3.kind=function
scope.3.startLine=16
scope.3.endLine=18
scope.3.semanticHash=67a06b9f43804ce2
scope.4.id=function:<anonymous>#2
scope.4.kind=function
scope.4.startLine=19
scope.4.endLine=21
scope.4.semanticHash=360776c78d632b1f
scope.5.id=function:<anonymous>#3
scope.5.kind=function
scope.5.startLine=22
scope.5.endLine=24
scope.5.semanticHash=d590c542c8c308c5
scope.6.id=function:<anonymous>#4
scope.6.kind=function
scope.6.startLine=25
scope.6.endLine=27
scope.6.semanticHash=3c26bf1ea8e4b724
scope.7.id=function:<anonymous>#5
scope.7.kind=function
scope.7.startLine=28
scope.7.endLine=30
scope.7.semanticHash=aba9250a8c6b104f
scope.8.id=function:_build_bankruptcy_port
scope.8.kind=function
scope.8.startLine=34
scope.8.endLine=40
scope.8.semanticHash=a0e53e763d2cfb89
scope.9.id=function:<anonymous>#6
scope.9.kind=function
scope.9.startLine=36
scope.9.endLine=38
scope.9.semanticHash=d590c542c8c308c5
scope.10.id=function:_install_defaults
scope.10.kind=function
scope.10.startLine=42
scope.10.endLine=46
scope.10.semanticHash=a48c18b51c0f0d3b
scope.11.id=function:default_ports.resolve_game_opts
scope.11.kind=function
scope.11.startLine=48
scope.11.endLine=50
scope.11.semanticHash=ce53a3a81f3c9272
scope.12.id=function:default_ports.install
scope.12.kind=function
scope.12.startLine=52
scope.12.endLine=57
scope.12.semanticHash=957177350aaf8c67
]]

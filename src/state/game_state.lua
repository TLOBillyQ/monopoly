local game_state_players = require("src.state.player_state")
local game_state_tiles = require("src.state.board_state")
local game_state_turn = require("src.state.turn_state")
local Class = require("src.foundation.class")


local game = Class("Game")

local function _install_mixin(target, source, source_name)
  for key, fn in pairs(source) do
    assert(target[key] == nil, "game_state mixin collision: " .. tostring(source_name) .. "." .. tostring(key))
    target[key] = fn
  end
end

_install_mixin(game, game_state_players, "players")
_install_mixin(game, game_state_tiles, "board")
_install_mixin(game, game_state_turn, "turn")

function game:init(opts)
  self.auto_play_port = opts and opts.auto_play_port or self.auto_play_port
  self.bankruptcy_port = opts and opts.bankruptcy_port or self.bankruptcy_port
end

function game:advance_turn()
  if self.finished then
    return
  end
  local runtime = self.turn_runtime
  if runtime and runtime.run_turn then
    runtime:run_turn()
  end
  self:check_victory()
end

function game:dispatch_action(action)
  if self.finished then
    return
  end
  local runtime = self.turn_runtime
  if runtime and runtime.dispatch then
    runtime:dispatch(action)
  end
  self:check_victory()
end

function game:rebuild()
  local length = self.board:length()
  self.occupants = {}
  for i = 1, length do
    self.occupants[i] = {}
  end
  for _, player in ipairs(self.players) do
    if not player.eliminated then
      local idx = player.position
      player.position = idx
      table.insert(self.occupants[idx], player.id)
    end
  end
end

return game

--[[ mutate4lua-manifest
version=4
projectHash=2ef2e1545ec45ced
scope.0.id=chunk:src/state/game_state.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=63
scope.0.semanticHash=b3fd557e9fe5468b
scope.1.id=function:_install_mixin
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=14
scope.1.semanticHash=3994960082292d32
scope.2.id=function:game:init
scope.2.kind=function
scope.2.startLine=20
scope.2.endLine=23
scope.2.semanticHash=ff0b4fe27904f832
scope.3.id=function:game:advance_turn
scope.3.kind=function
scope.3.startLine=25
scope.3.endLine=34
scope.3.semanticHash=570ec966dbf20260
scope.4.id=function:game:dispatch_action
scope.4.kind=function
scope.4.startLine=36
scope.4.endLine=45
scope.4.semanticHash=b95f0196cfa71614
scope.5.id=function:game:rebuild
scope.5.kind=function
scope.5.startLine=47
scope.5.endLine=60
scope.5.semanticHash=f51f90e391482ed8
]]

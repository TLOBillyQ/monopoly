local CompositionRoot = require("src.game.game.CompositionRoot")
local GameState = require("src.game.game.GameState")
local GameVictory = require("src.game.game.GameVictory")
require "vendor.third_party.ClassUtils"


local Game = Class("Game")

for key, fn in pairs(GameState) do
  Game[key] = fn
end

Game.CheckVictory = GameVictory.CheckVictory

function Game:Init(opts)
  if opts and opts.__skip_assemble then
    return
  end
  CompositionRoot.Assemble(opts, self)
end

function Game:AdvanceTurn()
  if self.finished then
    return
  end
  if self.turn_manager then
    self.turn_manager:RunTurn()
  end
  self:CheckVictory()
end

function Game:DispatchAction(action)
  if self.finished then
    return
  end
  if self.turn_manager then
    self.turn_manager:Dispatch(action)
  end
  self:CheckVictory()
end

return Game

local CompositionRoot = require("Manager.GameManager.CompositionRoot")
local GameState = require("Manager.GameManager.GameState")
local GameVictory = require("Manager.GameManager.GameVictory")
require "Library.ClassUtils"


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

function Game:GetService(key, context)
  if context and context.services and context.services[key] then
    return context.services[key]
  end
  return self.services and self.services[key]
end

function Game:GetServices(context)
  if context and context.services then
    return context.services
  end
  return self.services
end

return Game

local CompositionRoot = require("Manager.GameManager.CompositionRoot")
local GameState = require("Manager.GameManager.GameState")
local GameVictory = require("Manager.GameManager.GameVictory")
require "Library.ClassUtils"

---@class Game
---@field board Board
---@field players Player[]
---@field store Store
---@field rng RNG
---@field services table
---@field logger table
---@field ui_port table?
---@field events table?
---@field turn_manager TurnManager?
---@field finished boolean
---@field winner Player?
---@field winner_names string?
---@field last_turn number?
---游戏主协调类，管理所有游戏逻辑、状态、玩家和棋盘
local Game = Class("Game")
Game.__class_new = Game.new

for key, fn in pairs(GameState) do
  Game[key] = fn
end

Game.check_victory = GameVictory.check_victory

function Game.new(opts)
  return CompositionRoot.assemble(opts, Game)
end

function Game:advance_turn()
  if self.finished then
    return
  end
  if self.turn_manager then
    self.turn_manager:run_turn()
  end
  self:check_victory()
end

function Game:dispatch_action(action)
  if self.finished then
    return
  end
  if self.turn_manager then
    self.turn_manager:dispatch(action)
  end
  self:check_victory()
end

function Game:get_service(key, context)
  if context and context.services and context.services[key] then
    return context.services[key]
  end
  return self.services and self.services[key]
end

function Game:get_services(context)
  if context and context.services then
    return context.services
  end
  return self.services
end

return Game

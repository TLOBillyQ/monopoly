local composition_root = require("src.game.core.runtime.CompositionRoot")
local game_state_api = require("src.game.core.runtime.GameStateAPI")
local game_victory = require("src.game.core.runtime.GameVictory")
require "vendor.third_party.ClassUtils"


local game = Class("Game")

for key, fn in pairs(game_state_api) do
  game[key] = fn
end

game.check_victory = game_victory.check_victory

function game:init(opts)
  if opts and opts.__skip_assemble then
    return
  end
  composition_root.assemble(opts, self)
end

function game:advance_turn()
  if self.finished then
    return
  end
  if self.turn_flow then
    self.turn_flow:run_turn()
  end
  self:check_victory()
end

function game:dispatch_action(action)
  if self.finished then
    return
  end
  if self.turn_flow then
    self.turn_flow:dispatch(action)
  end
  self:check_victory()
end

return game

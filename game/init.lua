local bootstrap = require("game.bootstrap")
local state = require("game.state")
local win = require("game.rule.win")
require "lib.third_party.ClassUtils"


local game = Class("Game")

for key, fn in pairs(state) do
  game[key] = fn
end

game.check_victory = win.check_victory

function game:init(opts)
  if opts and opts.__skip_assemble then
    return
  end
  bootstrap.assemble(opts, self)
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

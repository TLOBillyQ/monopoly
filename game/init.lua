local bootstrap = require("game.bootstrap")
local state_turn = require("game.state.turn")
local state_player = require("game.state.player")
local state_tile = require("game.state.tile")
local state_hospital = require("game.state.hospital")
local win = require("game.rule.win")
require "lib.third_party.ClassUtils"


local game = Class("Game")

-- 注入 Turn 状态方法
for key, fn in pairs(state_turn) do
  game[key] = fn
end

-- 注入 Player 状态方法
for key, fn in pairs(state_player) do
  game[key] = fn
end

-- 注入 Tile 状态方法
for key, fn in pairs(state_tile) do
  game[key] = fn
end

-- 注入 Hospital/Mountain 方法
for key, fn in pairs(state_hospital) do
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

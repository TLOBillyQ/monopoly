local composition_root = require("src.game.core.runtime.CompositionRoot")
local game_state_ops = require("src.game.core.runtime.GameStateOps")
local game_victory = require("src.game.core.runtime.GameVictory")
require "vendor.third_party.ClassUtils"


local game = Class("Game")

for key, fn in pairs(game_state_ops) do
  game[key] = fn
end

game.check_victory = game_victory.check_victory

function game:init(opts)
  if opts and opts.__skip_assemble then
    return
  end
  composition_root.assemble(opts, self)
end

local function _resolve_turn_runtime(self)
  return self.turn_engine
end

function game:advance_turn()
  if self.finished then
    return
  end
  local runtime = _resolve_turn_runtime(self)
  if runtime and runtime.run_turn then
    runtime:run_turn()
  end
  self:check_victory()
end

function game:dispatch_action(action)
  if self.finished then
    return
  end
  local runtime = _resolve_turn_runtime(self)
  if runtime and runtime.dispatch then
    runtime:dispatch(action)
  end
  self:check_victory()
end

return game

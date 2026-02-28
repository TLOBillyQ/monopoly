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
  if self.turn_engine and self.turn_engine.get_legacy_flow then
    local legacy_flow = self.turn_engine:get_legacy_flow()
    -- 兼容测试或运行时替换 game.turn_flow 的场景。
    if self.turn_flow and legacy_flow and self.turn_flow ~= legacy_flow then
      return self.turn_flow
    end
    return self.turn_engine
  end
  return self.turn_engine or self.turn_flow
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

-- model_api.build 的 env 缺省路径:未传 env 时按 game 构建 ui env
-- (覆盖 _build_ui_env 的 winner_name 回落与 winner.name 断言路径)。
local lu = require("luaunit")

local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq
local model_api = require("src.ui.view.init")

TestModelApiEnv = {}

function TestModelApiEnv:test_build_without_env_uses_winner_names()
  local game = support.new_game()
  game.winner_names = "玩家甲"
  local model = model_api.build(game, nil)
  lu.assertNotNil(model, "build should produce a model without an explicit env")
  _assert_eq(model.winner_name, "玩家甲",
    "winner_name should fall back to game.winner_names when env is absent")
end

function TestModelApiEnv:test_build_without_env_uses_winner_name_assertion()
  local game = support.new_game()
  game.winner = { name = "玩家乙" }
  local model = model_api.build(game, nil)
  lu.assertNotNil(model, "build should produce a model from winner.name")
  _assert_eq(model.winner_name, "玩家乙",
    "winner_name should come from winner.name when winner_names is absent")
end

return TestModelApiEnv

local lu = require("luaunit")
local market_service = require("src.rules.market")
local market_effects = require("src.rules.market.effects")

-- 原生 LuaUnit 转换(busted → LuaUnit):describe 拍平为文件级 Test 类,
-- 断言词汇切到 lu.assertXxx,用例数与改写前一一对应(5 例)。

local executor = market_effects.executors.market

local function _with_market_stubs(stubs, fn)
  local prev_auto_execute = market_service.auto.execute
  local prev_list_available = market_service.query.list_available
  local prev_choice_build = market_service.choice.build

  market_service.auto.execute = stubs.auto_execute or prev_auto_execute
  market_service.query.list_available = stubs.list_available or prev_list_available
  market_service.choice.build = stubs.choice_build or prev_choice_build

  local ok, err = pcall(fn)

  market_service.auto.execute = prev_auto_execute
  market_service.query.list_available = prev_list_available
  market_service.choice.build = prev_choice_build

  if not ok then
    error(err, 0)
  end
end

local function _ctx(is_auto)
  return {
    tile = { type = "market" },
    player = { id = 1 },
    game = {
      auto_play_port = {
        is_computer_controlled = function()
          return is_auto
        end,
      },
    },
  }
end

TestMarketEffectExecutor = {}

function TestMarketEffectExecutor:test_can_apply_only_on_market_tile()
  lu.assertEvalToTrue(executor.can_apply({ tile = { type = "market" } }) == true, "applies on market tile")
  lu.assertEvalToTrue(executor.can_apply({ tile = { type = "land" } }) == false, "does not apply on other tiles")
end

function TestMarketEffectExecutor:test_auto_player_runs_auto_purchase_and_never_builds_a_choice()
  local auto_calls = 0
  local choice_built = false

  _with_market_stubs({
    auto_execute = function(game, player)
      auto_calls = auto_calls + 1
      lu.assertEvalToTrue(game ~= nil and player ~= nil, "auto execute receives game and player")
    end,
    list_available = function()
      error("auto player must not query buyable items", 0)
    end,
    choice_build = function()
      choice_built = true
      return { kind = "market_buy" }, nil
    end,
  }, function()
    local result = executor.apply(_ctx(true))
    lu.assertEvalToTrue(result == nil, "auto player path yields no pending intent")
  end)

  lu.assertEvalToTrue(auto_calls == 1, "auto purchase ran exactly once")
  lu.assertEvalToTrue(choice_built == false, "auto player path never builds a choice spec")
end

function TestMarketEffectExecutor:test_human_player_with_no_buyable_items_yields_nothing()
  _with_market_stubs({
    auto_execute = function()
      error("human player must not trigger auto purchase", 0)
    end,
    list_available = function()
      return {}
    end,
  }, function()
    lu.assertEvalToTrue(executor.apply(_ctx(false)) == nil, "empty market yields no intent")
  end)
end

function TestMarketEffectExecutor:test_human_player_with_ready_intent_returns_that_intent()
  local intent = { kind = "market_buy_direct" }

  _with_market_stubs({
    auto_execute = function()
      error("human player must not trigger auto purchase", 0)
    end,
    list_available = function()
      return { { id = "item_1" } }
    end,
    choice_build = function()
      return nil, intent
    end,
  }, function()
    local result = executor.apply(_ctx(false))
    lu.assertEvalToTrue(result.intent == intent, "returns the built intent as-is")
    lu.assertEvalToTrue(result.waiting == nil, "a ready intent is not a waiting choice")
  end)
end

function TestMarketEffectExecutor:test_human_player_with_choice_spec_waits_on_market_choice()
  local spec = { kind = "market_buy", owner_role_id = 1 }

  _with_market_stubs({
    auto_execute = function()
      error("human player must not trigger auto purchase", 0)
    end,
    list_available = function()
      return { { id = "item_1" } }
    end,
    choice_build = function()
      return spec, nil
    end,
  }, function()
    local result = executor.apply(_ctx(false))
    lu.assertEvalToTrue(result.waiting == true, "waits for the player to choose")
    lu.assertEvalToTrue(result.reason == "market_choice", "waiting reason is market_choice")
    lu.assertEvalToTrue(result.intent.kind == "need_choice", "intent asks for a choice")
    lu.assertEvalToTrue(result.intent.choice_spec == spec, "carries the built choice spec")
  end)
end



return TestMarketEffectExecutor

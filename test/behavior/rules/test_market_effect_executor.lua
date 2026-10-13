require("test.bootstrap").install_package_paths()
local luassert = require("luassert")
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


describe("TestMarketEffectExecutor", function()
  it("test_can_apply_only_on_market_tile", function()
    luassert.truthy(executor.can_apply({ tile = { type = "market" } }) == true, "applies on market tile")
    luassert.truthy(executor.can_apply({ tile = { type = "land" } }) == false, "does not apply on other tiles")
  end)

  it("test_auto_player_runs_auto_purchase_and_never_builds_a_choice", function()
    local auto_calls = 0
    local choice_built = false

    _with_market_stubs({
      auto_execute = function(game, player)
        auto_calls = auto_calls + 1
        luassert.truthy(game ~= nil and player ~= nil, "auto execute receives game and player")
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
      luassert.truthy(result == nil, "auto player path yields no pending intent")
    end)

    luassert.truthy(auto_calls == 1, "auto purchase ran exactly once")
    luassert.truthy(choice_built == false, "auto player path never builds a choice spec")
  end)

  it("test_human_player_with_no_buyable_items_yields_nothing", function()
    _with_market_stubs({
      auto_execute = function()
        error("human player must not trigger auto purchase", 0)
      end,
      list_available = function()
        return {}
      end,
    }, function()
      luassert.truthy(executor.apply(_ctx(false)) == nil, "empty market yields no intent")
    end)
  end)

  it("test_human_player_with_ready_intent_returns_that_intent", function()
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
      luassert.truthy(result.intent == intent, "returns the built intent as-is")
      luassert.truthy(result.waiting == nil, "a ready intent is not a waiting choice")
    end)
  end)

  it("test_human_player_with_choice_spec_waits_on_market_choice", function()
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
      luassert.truthy(result.waiting == true, "waits for the player to choose")
      luassert.truthy(result.reason == "market_choice", "waiting reason is market_choice")
      luassert.truthy(result.intent.kind == "need_choice", "intent asks for a choice")
      luassert.truthy(result.intent.choice_spec == spec, "carries the built choice spec")
    end)
  end)



end)

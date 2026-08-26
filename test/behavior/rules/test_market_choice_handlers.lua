local lu = require("luaunit")
local market_handlers = require("src.rules.choice_handlers.market")
local market_service = require("src.rules.market")
local purchase_settlement = require("src.rules.market.purchase_settlement")
local market_context = require("src.rules.market.query").context

local function _handlers(finish_choice)
  local registry = {}
  market_handlers.register(registry, {
    finish_choice = finish_choice or function() end,
  })
  return registry
end

-- 按 test_land_choice_handlers.lua 的 _with_resolve_stub 模式,临时替换模块字段后执行并还原。
local function _with_patch(target, key, value, fn)
  local prev = target[key]
  target[key] = value
  local ok, err = pcall(fn)
  target[key] = prev
  if not ok then
    error(err, 0)
  end
end

local function _game()
  return {
    find_player_by_id = function()
      return { id = 1, name = "P" }
    end,
  }
end

local function _choice()
  return { kind = "market_buy", meta = { player_id = 1 } }
end

local function _action()
  return { option_id = "101" }
end

-- 模拟 resolver._finish_choice 的真实契约:stay 决定 status 与 stay 字段。
local function _finish_stub(game, stay)
  return { status = stay and "waiting" or "resolved", stay = stay }
end

TestMarketChoiceHandlers = {}

function TestMarketChoiceHandlers:test_registers_market_buy_handler()
  local registry = _handlers()
  lu.assertNotNil(registry.market_buy, "market_buy registered")
end

function TestMarketChoiceHandlers:test_execute_returns_finish_result_when_verdict_does_not_keep_open()
  local finish_calls = {}
  local registry = _handlers(function(game, stay)
    finish_calls[#finish_calls + 1] = { game = game, stay = stay }
    return _finish_stub(game, stay)
  end)
  local game = _game()

  _with_patch(purchase_settlement, "resolve", function()
    return { keep_open = false }
  end, function()
    _with_patch(market_context, "entry_by_id", function()
      return { kind = "non_item", product_id = 101 }
    end, function()
      _with_patch(market_service.purchase, "execute", function()
        return { ok = true }
      end, function()
        local result = registry.market_buy.execute(game, _choice(), _action())
        lu.assertEvalToTrue(result ~= nil and result.stay == false,
          "non-keep-open verdict must finish the choice with stay=false")
        lu.assertEvalToTrue(#finish_calls == 1, "finish_choice called exactly once")
        lu.assertEvalToTrue(finish_calls[1].stay == false, "finish_choice must receive stay=false")
      end)
    end)
  end)
end

function TestMarketChoiceHandlers:test_execute_stays_open_without_finishing_when_verdict_keeps_open()
  local finish_calls = {}
  local registry = _handlers(function(game, stay)
    finish_calls[#finish_calls + 1] = stay
    return _finish_stub(game, stay)
  end)
  local game = _game()

  _with_patch(purchase_settlement, "resolve", function()
    return { keep_open = true }
  end, function()
    _with_patch(market_context, "entry_by_id", function()
      return { kind = "non_item", product_id = 101 }
    end, function()
      _with_patch(market_service.purchase, "execute", function()
        return { ok = true }
      end, function()
        local result = registry.market_buy.execute(game, _choice(), _action())
        lu.assertEvalToTrue(result ~= nil and result.stay == true,
          "keep-open verdict must stay open")
        lu.assertEvalToTrue(#finish_calls == 0, "finish_choice must not be called when staying open")
      end)
    end)
  end)
end

return TestMarketChoiceHandlers

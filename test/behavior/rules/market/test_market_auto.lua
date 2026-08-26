-- market/auto.lua 直测:AI 跳过/玩家购买的入口分流、黑市排序契约
-- (缺价按 0 且升序)、pending_choice 透传与 skip 事件文案。
local lu = require("luaunit")
local support = require("test.support.shared_support")

local auto = require("src.rules.market.auto")
local auto_play_port = require("src.rules.ports.auto_play")
local eligibility = require("src.rules.market.query").eligibility
local purchase = require("src.rules.market.purchase")
local purchase_settlement = require("src.rules.market.purchase_settlement")
local event_feed = require("src.rules.ports.event_feed")

TestMarketAuto = {}

local function _drive(overrides)
  local captured = {}
  local game = {
    turn = { pending_choice = { id = "pc1" } },
  }
  support.with_patches({
    { target = auto_play_port, key = "is_computer_controlled", value = function()
      return overrides ~= nil and overrides.is_computer_controlled or false
    end },
    { target = eligibility, key = "list_available", value = function()
      return (overrides ~= nil and overrides.list) or {}
    end },
    { target = event_feed, key = "publish", value = function(_, payload)
      captured.feed = payload
    end },
    { target = purchase, key = "execute", value = function(_, _, product_id)
      captured.product_id = product_id
      return { ok = true }
    end },
    { target = purchase_settlement, key = "resolve", value = function(_, choice, _, chosen, result)
      captured.resolve = { choice = choice, chosen = chosen, result = result }
    end },
  }, function()
    auto.execute(game, { id = 1, name = "P1" })
  end)
  return captured
end

-- AI 玩家:只发 skip 事件,不购买;tip=false 与文案契约钉住。
function TestMarketAuto:test_ai_player_publishes_skip_feed_without_purchase()
  local captured = _drive({ is_computer_controlled = true })
  lu.assertEvalToTrue(captured.feed ~= nil, "an AI player must publish a skip feed")
  lu.assertEvalToTrue(captured.feed.kind == "choice_skipped", "the skip kind must be pinned")
  lu.assertEvalToTrue(captured.feed.tip == false, "the skip must not be a tip")
  lu.assertEvalToTrue(captured.feed.text == "P1 (AI) 到达黑市，选择不购买",
    "the skip text must be pinned")
  lu.assertEvalToTrue(captured.product_id == nil and captured.resolve == nil,
    "an AI player must not purchase or settle")
end

-- 玩家:按价格升序购买最低价条目。3 元素列表让「左操作数价格被
-- 恒 0 化」的变异(or→and / entry_price(a)→nil)买到中间价,必须被杀。
function TestMarketAuto:test_player_buys_the_cheapest_entry()
  local captured = _drive({
    list = {
      { price = 300, product_id = "b" },
      { price = 200, product_id = "c" },
      { price = 100, product_id = "a" },
    },
  })
  lu.assertEvalToTrue(captured.product_id == "a", "the cheapest entry must be purchased")
end

-- 缺价条目按 0 计,排到最前(杀缺省 0→1 变异)。
function TestMarketAuto:test_missing_price_entries_sort_to_the_front()
  local captured = _drive({
    list = { { price = 100, product_id = "p" }, { product_id = "m" } },
  })
  lu.assertEvalToTrue(captured.product_id == "m",
    "a missing price must count as zero and sort first")
end

-- pending_choice 原样透传给结算。
function TestMarketAuto:test_pending_choice_flows_into_settlement()
  local captured = _drive({
    list = { { price = 10, product_id = "z" } },
  })
  lu.assertEvalToTrue(captured.resolve ~= nil, "a purchase must settle")
  lu.assertEvalToTrue(captured.resolve.choice ~= nil and captured.resolve.choice.id == "pc1",
    "the pending choice must flow into settlement")
  lu.assertEvalToTrue(captured.resolve.chosen.product_id == "z", "the chosen entry must be passed")
end

-- 空列表静默返回,不发事件不购买。
function TestMarketAuto:test_empty_list_returns_without_side_effects()
  local captured = _drive({})
  lu.assertEvalToTrue(captured.product_id == nil and captured.resolve == nil
    and captured.feed == nil, "an empty list must do nothing")
end

return TestMarketAuto

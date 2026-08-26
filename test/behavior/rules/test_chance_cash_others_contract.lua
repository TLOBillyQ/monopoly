-- luacheck: ignore 211
local lu = require("luaunit")
local support = require("test.support.shared_support")
local default_map = require("src.config.content.default_map")
local chance_handlers = require("src.rules.chance.handlers")
local _config_reset = require("test.support.config_reset")

local function _new_game()
  return support.new_game({ map = default_map })
end

local function _assert_delta(actual, expected, msg)
  assert(actual == expected, (msg or "delta mismatch") .. ": expected " .. tostring(expected) .. " got " .. tostring(actual))
end

TestChanceCashOthersContract = {}

function TestChanceCashOthersContract:setUp()
  _config_reset.reset_all()
end

function TestChanceCashOthersContract:test_case1_pay_others_poor_receiver_gets_6000()
  local g = _new_game()
  local handlers = chance_handlers.build()
  local a = g.players[1]
  local b = g.players[2]
  g:set_player_cash(a, 99999)
  local b_before = g:player_cash(b)
  g:set_player_deity(a, "poor", 3)
  handlers.pay_others(g, a, { effect = "pay_others", amount = 3000, target = "self" })
  local b_after = g:player_cash(b)
  _assert_delta(b_after - b_before, 6000, "case1: receiver should gain 6000 when payer has poor")
end

function TestChanceCashOthersContract:test_case1_event_text_carries_the_paid_amount()
  -- #293:支付事件的文案用 abs_value(delta)(→ nil 变异)拼金币数,文案未测。
  local g = _new_game()
  local handlers = chance_handlers.build()
  local a = g.players[1]
  g:set_player_cash(a, 99999)
  g:set_player_deity(a, "poor", 3)
  local texts = {}
  local saved_publish = g.event_feed_port
  g.event_feed_port = {
    publish = function(_, _, event)
      if event and event.text then texts[#texts + 1] = event.text end
    end,
  }
  handlers.pay_others(g, a, { effect = "pay_others", amount = 3000, target = "self" })
  g.event_feed_port = saved_publish
  local joined = table.concat(texts, "\n")
  lu.assertEvalToTrue(joined:find("3000", 1, true) ~= nil,
    "payment event text should carry the paid amount; got " .. joined)
end

function TestChanceCashOthersContract:test_case2_pay_others_no_poor_receiver_gets_3000()
  local g = _new_game()
  local handlers = chance_handlers.build()
  local a = g.players[1]
  local b = g.players[2]
  g:set_player_cash(a, 99999)
  local b_before = g:player_cash(b)
  handlers.pay_others(g, a, { effect = "pay_others", amount = 3000, target = "self" })
  local b_after = g:player_cash(b)
  _assert_delta(b_after - b_before, 3000, "case2: receiver should gain 3000 when payer has no poor")
end

function TestChanceCashOthersContract:test_case3_collect_from_others_rich_each_other_pays_6000()
  local g = _new_game()
  local handlers = chance_handlers.build()
  local a = g.players[1]
  local b = g.players[2]
  g:set_player_cash(b, 99999)
  g:set_player_deity(a, "rich", 3)
  handlers.collect_from_others(g, a, { effect = "collect_from_others", amount = 3000, target = "self" })
  local b_after = g:player_cash(b)
  _assert_delta(99999 - b_after, 6000, "case3: each other should pay 6000 when collector has rich")
end

function TestChanceCashOthersContract:test_case4_collect_from_others_no_rich_each_other_pays_3000()
  local g = _new_game()
  local handlers = chance_handlers.build()
  local a = g.players[1]
  local b = g.players[2]
  g:set_player_cash(b, 99999)
  handlers.collect_from_others(g, a, { effect = "collect_from_others", amount = 3000, target = "self" })
  local b_after = g:player_cash(b)
  _assert_delta(99999 - b_after, 3000, "case4: each other should pay 3000 when collector has no rich")
end

function TestChanceCashOthersContract:test_case5_collect_from_others_poor_not_rich_no_doubling()
  local g = _new_game()
  local handlers = chance_handlers.build()
  local a = g.players[1]
  local b = g.players[2]
  g:set_player_cash(b, 99999)
  g:set_player_deity(a, "poor", 3)
  handlers.collect_from_others(g, a, { effect = "collect_from_others", amount = 3000, target = "self" })
  local b_after = g:player_cash(b)
  _assert_delta(99999 - b_after, 3000, "case5: poor deity on collector must not double the fee")
end

function TestChanceCashOthersContract:test_case6_pay_others_rich_not_poor_no_doubling()
  local g = _new_game()
  local handlers = chance_handlers.build()
  local a = g.players[1]
  local b = g.players[2]
  g:set_player_cash(a, 99999)
  local b_before = g:player_cash(b)
  g:set_player_deity(a, "rich", 3)
  handlers.pay_others(g, a, { effect = "pay_others", amount = 3000, target = "self" })
  local b_after = g:player_cash(b)
  _assert_delta(b_after - b_before, 3000, "case6: rich deity on payer must not double the fee")
end


return TestChanceCashOthersContract

-- luacheck: ignore 211
local support = require("spec.support.shared_support")
local default_map = require("src.config.content.default_map")
local chance_handlers = require("src.rules.chance.handlers")

local function _new_game()
  return support.new_game({ map = default_map })
end

local function _assert_delta(actual, expected, msg)
  assert(actual == expected, (msg or "delta mismatch") .. ": expected " .. tostring(expected) .. " got " .. tostring(actual))
end

describe("contract: pay_others / collect_from_others receiver behavior", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("case1_pay_others_poor_receiver_gets_6000", function()
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
  end)

  it("case2_pay_others_no_poor_receiver_gets_3000", function()
    local g = _new_game()
    local handlers = chance_handlers.build()
    local a = g.players[1]
    local b = g.players[2]
    g:set_player_cash(a, 99999)
    local b_before = g:player_cash(b)
    handlers.pay_others(g, a, { effect = "pay_others", amount = 3000, target = "self" })
    local b_after = g:player_cash(b)
    _assert_delta(b_after - b_before, 3000, "case2: receiver should gain 3000 when payer has no poor")
  end)

  it("case3_collect_from_others_rich_each_other_pays_6000", function()
    local g = _new_game()
    local handlers = chance_handlers.build()
    local a = g.players[1]
    local b = g.players[2]
    g:set_player_cash(b, 99999)
    g:set_player_deity(a, "rich", 3)
    handlers.collect_from_others(g, a, { effect = "collect_from_others", amount = 3000, target = "self" })
    local b_after = g:player_cash(b)
    _assert_delta(99999 - b_after, 6000, "case3: each other should pay 6000 when collector has rich")
  end)

  it("case4_collect_from_others_no_rich_each_other_pays_3000", function()
    local g = _new_game()
    local handlers = chance_handlers.build()
    local a = g.players[1]
    local b = g.players[2]
    g:set_player_cash(b, 99999)
    handlers.collect_from_others(g, a, { effect = "collect_from_others", amount = 3000, target = "self" })
    local b_after = g:player_cash(b)
    _assert_delta(99999 - b_after, 3000, "case4: each other should pay 3000 when collector has no rich")
  end)

  it("case5_collect_from_others_poor_not_rich_no_doubling", function()
    local g = _new_game()
    local handlers = chance_handlers.build()
    local a = g.players[1]
    local b = g.players[2]
    g:set_player_cash(b, 99999)
    g:set_player_deity(a, "poor", 3)
    handlers.collect_from_others(g, a, { effect = "collect_from_others", amount = 3000, target = "self" })
    local b_after = g:player_cash(b)
    _assert_delta(99999 - b_after, 3000, "case5: poor deity on collector must not double the fee")
  end)

  it("case6_pay_others_rich_not_poor_no_doubling", function()
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
  end)
end)

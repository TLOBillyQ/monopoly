-- Mutation-pinning specs for src/player/actions/balance.lua (角色属性金币深模块).
--
-- #259 之前,这里的 clamp/partial/恒等 coercion 位点以「整数域等价变异体」
-- 申报并存(等价理由见 git 历史)。#259 按三分类协议把等价位点全部化简掉:
-- math.max/math.min 吸收边界、恒等 coercion 改双运算形态、is_numeric 提前
-- 拦截删除,曾经的「等价申报」全部转为可杀位点;本文件现钉的是真实边界
-- 语义(钳零、partial 截顶、inf 拒绝、anim delta、写入失败前缀、溢出回绕)。

local lu = require("luaunit")
local balance = require("src.player.actions.balance")

local function _player(initial)
  return { _coin_role = balance.new_memory_coin_role(initial) }
end

local function _game()
  return { dirty = {} }
end

local function _read(player)
  return balance.player_cash(nil, player)
end

local NO_ANIM = { suppress_cash_receive_anim = true }

local function _player_with_hostile_setter(balance_amount)
  return {
    _coin_role = {
      get_attr_raw_fixed = function() return balance_amount end,
      set_attr_raw_fixed = function() error("host-write-down") end,
    },
  }
end

TestBalanceMutation = {}

function TestBalanceMutation:test_clamps_a_would_be_negative_balance_to_exactly_0()
  local game, player = _game(), _player(5)
  local updated = balance.add_player_cash(game, player, -10, NO_ANIM)
  -- next_cash = 5 + (-10) = -5 -> clamp to 0.
  lu.assertEvalToTrue(updated == 0, "under-run must clamp to 0; got " .. tostring(updated))
  lu.assertEvalToTrue(_read(player) == 0, "stored balance must be 0 after clamp")
end

function TestBalanceMutation:test_leaves_an_exactly_zero_result_at_zero()
  local game, player = _game(), _player(10)
  local updated = balance.add_player_cash(game, player, -10, NO_ANIM)
  -- next_cash = 0: `< 0` false (original) and `<= 0` true (mutant) both yield 0.
  lu.assertEvalToTrue(updated == 0, "exact-zero result must stay 0; got " .. tostring(updated))
end

function TestBalanceMutation:test_does_not_clamp_a_positive_result()
  local game, player = _game(), _player(10)
  local updated = balance.add_player_cash(game, player, 5, NO_ANIM)
  lu.assertEvalToTrue(updated == 15, "positive result must pass through unclamped; got " .. tostring(updated))
end

function TestBalanceMutation:test_caps_the_transferred_amount_at_the_payers_balance_when_partial_is_allowed()
  local game = _game()
  local payer, receiver = _player(30), _player(0)
  local payer_after, receiver_after, actual =
    balance.transfer_player_cash(game, payer, receiver, 100,
      { allow_partial = true, suppress_cash_receive_anim = true })
  -- payer_before (30) < requested (100) -> actual capped to 30.
  lu.assertEvalToTrue(actual == 30, "partial transfer must cap at payer balance; got " .. tostring(actual))
  lu.assertEvalToTrue(payer_after == 0, "payer must end at 0; got " .. tostring(payer_after))
  lu.assertEvalToTrue(receiver_after == 30, "receiver must receive the capped amount; got " .. tostring(receiver_after))
end

function TestBalanceMutation:test_transfers_the_full_amount_when_balance_equals_request()
  local game = _game()
  local payer, receiver = _player(100), _player(0)
  local payer_after, receiver_after, actual =
    balance.transfer_player_cash(game, payer, receiver, 100,
      { allow_partial = true, suppress_cash_receive_anim = true })
  -- payer_before == requested == 100: `<` (full) and `<=` (partial) both give 100.
  lu.assertEvalToTrue(actual == 100, "equal-balance transfer must move the full amount; got " .. tostring(actual))
  lu.assertEvalToTrue(payer_after == 0 and receiver_after == 100,
    "balances must settle to 0/100; got " .. tostring(payer_after) .. "/" .. tostring(receiver_after))
end

function TestBalanceMutation:test_rejects_math_huge_as_a_delta()
  -- kills _is_finite_numeric's `ok and diff == 0` `and` -> `or`: inf-inf is
  -- NaN, so the original rejects; the `or` mutant accepts inf and writes it.
  local player = _player(10)
  local ok, err = pcall(function()
    balance.add_player_cash(nil, player, math.huge)
  end)
  lu.assertEvalToTrue(ok == false, "math.huge must be rejected as a delta")
  lu.assertEvalToTrue(tostring(err):find("必须是有限整数", 1, true) ~= nil,
    "the rejection names the finite-integer rule, got: " .. tostring(err))
end

function TestBalanceMutation:test_queues_the_cash_anim_with_the_actual_delta_not_the_sum()
  -- kills _apply_coin_delta's `updated_cash - current_cash` `-` -> `+`.
  local action_anim_port = require("src.foundation.ports.action_anim")
  local game, player = _game(), _player(10)
  local captured = {}
  local support = require("test.support.shared_support")
  support.with_patches({
    { target = action_anim_port, key = "queue", value = function(_, opts)
      captured.amount = opts.amount
      return true
    end },
  }, function()
    balance.add_player_cash(game, player, 5)
  end)
  lu.assertEvalToTrue(captured.amount == 5, "the anim delta must be the applied delta; got " .. tostring(captured.amount))
end

function TestBalanceMutation:test_transfer_surfaces_a_payer_write_failure_with_the_failure_prefix()
  -- kills transfer_player_cash's "写入失败: " -> nil and tostring(payer_err) -> nil.
  local payer = _player_with_hostile_setter(100)
  local receiver = _player(0)
  local ok, err = pcall(function()
    balance.transfer_player_cash(_game(), payer, receiver, 50, NO_ANIM)
  end)
  lu.assertEvalToTrue(ok == false, "a failing payer write must abort the transfer")
  local text = tostring(err)
  lu.assertEvalToTrue(text:find("写入失败: ", 1, true) ~= nil, "the failure keeps its prefix, got: " .. text)
  lu.assertEvalToTrue(text:find("host-write-down", 1, true) ~= nil, "the failure carries the writer error, got: " .. text)
end

function TestBalanceMutation:test_transfer_rejects_a_receiver_balance_overflow_as_an_invalid_write_value()
  -- kills the transfer receiver check's "写入值" label -> nil: receiver_after
  -- wraps negative past math.maxinteger and must be rejected by name.
  local payer = _player(10)
  local receiver = _player(math.maxinteger)
  local ok, err = pcall(function()
    balance.transfer_player_cash(_game(), payer, receiver, 1, NO_ANIM)
  end)
  lu.assertEvalToTrue(ok == false, "an overflowing receiver balance must be rejected")
  local text = tostring(err)
  lu.assertEvalToTrue(text:find("写入值", 1, true) ~= nil, "the rejection keeps the 写入值 label, got: " .. text)
  lu.assertEvalToTrue(text:find("不能为负数", 1, true) ~= nil, "the rejection names the negative rule, got: " .. text)
end


return TestBalanceMutation

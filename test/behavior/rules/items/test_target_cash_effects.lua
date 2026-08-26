-- target_cash_effects.share_wealth 直测:均富结算的三种现金形态
-- (transfer / add / set 兜底)、emit 抑制模式、成就正差额判定与天使免疫。
local lu = require("luaunit")
local support = require("test.support.shared_support")

local target_cash_effects = require("src.rules.items.target_cash_effects")
local achievement_progress = require("src.rules.ports.achievement_progress")
local event_feed = require("src.rules.ports.event_feed")
local angel_feedback = require("src.rules.items.angel_feedback")

TestTargetCashEffects = {}

local _USER, _TARGET = { id = 1, name = "U1" }, { id = 2, name = "T2" }

local function _game(captured, overrides)
  local g = {
    angel_immune_to_item = function()
      return false
    end,
    player_cash = function(_, p)
      return p.id == 1 and 400 or 200
    end,
    transfer_player_cash = function(_, from, to, amount)
      captured.transfer = { from = from.id, to = to.id, amount = amount }
    end,
    add_player_cash = function(_, p, amount)
      captured.add = captured.add or {}
      captured.add[#captured.add + 1] = { player = p.id, amount = amount }
    end,
    set_player_cash = function(_, p, value)
      captured.set = captured.set or {}
      captured.set[#captured.set + 1] = { player = p.id, value = value }
    end,
  }
  for k, v in pairs(overrides or {}) do
    if v == false then
      g[k] = nil
    else
      g[k] = v
    end
  end
  return g
end

local function _drive(overrides, context)
  local captured = {}
  support.with_patches({
    { target = achievement_progress, key = "cash_received", value = function(_, p, amount)
      captured.achievement = captured.achievement or {}
      captured.achievement[#captured.achievement + 1] = { player = p.id, amount = amount }
    end },
    { target = event_feed, key = "publish", value = function() end },
    { target = angel_feedback, key = "publish", value = function()
      captured.angel_feedback = true
    end },
  }, function()
    captured.result = target_cash_effects.share_wealth.apply(
      _game(captured, overrides), _USER, _TARGET, context)
  end)
  return captured
end

-- 400+200=600 → 各 300,user 减 100(负差额)→ transfer user→target 100。
function TestTargetCashEffects:test_negative_user_delta_uses_transfer()
  local captured = _drive()
  lu.assertEvalToTrue(captured.transfer ~= nil, "a negative user delta must transfer")
  lu.assertEvalToTrue(captured.transfer.from == 1 and captured.transfer.to == 2,
    "the payer must be the user")
  lu.assertEvalToTrue(captured.transfer.amount == 100, "the transfer amount must be the delta")
  lu.assertEvalToTrue(captured.add == nil and captured.set == nil,
    "only one cash form may run")
end

-- 无 transfer 时回落 add_player_cash 形态。
function TestTargetCashEffects:test_falls_back_to_add_when_transfer_is_unavailable()
  local captured = _drive({
    transfer_player_cash = false,
  })
  lu.assertEvalToTrue(captured.add ~= nil, "add form must run without transfer")
  lu.assertEvalToTrue(#captured.add == 2, "both players must be credited")
  lu.assertEvalToTrue(captured.set == nil, "set form must not run when add is available")
end

-- 双形态都缺时 set 兜底。
function TestTargetCashEffects:test_falls_back_to_set_when_both_ports_are_unavailable()
  local captured = _drive({
    transfer_player_cash = false,
    add_player_cash = false,
  })
  lu.assertEvalToTrue(captured.set ~= nil, "set form must run as the fallback")
  lu.assertEvalToTrue(#captured.set == 2, "both players must be set")
  lu.assertEvalToTrue(captured.set[1].value == 300, "the user half must be pinned")
end

-- suppress 模式:不 emit,仍走 set 兜底。
function TestTargetCashEffects:test_suppress_mode_skips_emit_but_still_settles()
  local captured = _drive({}, { suppress_cash_receive_anim = true })
  lu.assertEvalToTrue(captured.set ~= nil, "settlement must still run in suppress mode")
end

-- item_target_player_only 模式:同样不 emit。
function TestTargetCashEffects:test_item_target_player_only_mode_skips_emit()
  local captured = _drive({}, { share_wealth_cash_receive_mode = "item_target_player_only" })
  lu.assertEvalToTrue(captured.set ~= nil, "settlement must still run in item_target_player_only mode")
end

-- 均等现金:差额为 0,任何结算形态都不得触发,成就也不记。
function TestTargetCashEffects:test_equal_cash_runs_no_settlement()
  local captured = _drive({
    player_cash = function()
      return 300
    end,
  })
  lu.assertEvalToTrue(captured.transfer == nil and captured.add == nil and captured.set == nil,
    "zero deltas must not trigger any cash form")
  lu.assertEvalToTrue(captured.achievement == nil, "zero deltas must not record achievements")
end

-- user 侧差额恰为 1 也要记(杀 user 分支 > 0 的 0→1 变异)。
function TestTargetCashEffects:test_achievement_records_a_unit_delta_on_the_user_side()
  local captured = _drive({
    player_cash = function(_, p)
      return p.id == 1 and 299 or 301
    end,
  })
  lu.assertEvalToTrue(captured.achievement ~= nil, "a unit user delta must still record")
  lu.assertEvalToTrue(captured.achievement[1].player == 1, "the receiving player must be the user")
end

-- 差额恰为 1 也要记成就(杀 > 0 的 0→1 变异)。
function TestTargetCashEffects:test_achievement_records_a_unit_delta()
  local captured = _drive({
    player_cash = function(_, p)
      return p.id == 1 and 301 or 299
    end,
  })
  lu.assertEvalToTrue(captured.achievement ~= nil, "a unit delta must still record an achievement")
  lu.assertEvalToTrue(captured.achievement[1].amount == 1, "the recorded amount must be the unit delta")
end

-- 成就只在正差额时记(user 负差额不记 user,记 target 正差额)。
function TestTargetCashEffects:test_achievement_records_only_positive_deltas()
  local captured = _drive()
  lu.assertEvalToTrue(captured.achievement ~= nil, "a positive delta must record an achievement")
  lu.assertEvalToTrue(#captured.achievement == 1, "only the target delta is positive")
  lu.assertEvalToTrue(captured.achievement[1].player == 2, "the receiving player must be the target")
end

-- 天使免疫:发布反馈并短路,不结算。
function TestTargetCashEffects:test_angel_immune_short_circuits_with_feedback()
  local captured = _drive({
    angel_immune_to_item = function()
      return true
    end,
  })
  lu.assertEvalToTrue(captured.angel_feedback == true, "angel feedback must be published")
  lu.assertEvalToTrue(captured.result == true, "an immune share_wealth is consumed")
  lu.assertEvalToTrue(captured.transfer == nil and captured.set == nil,
    "no settlement may run for an immune target")
end

return TestTargetCashEffects

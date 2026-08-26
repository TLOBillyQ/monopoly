-- session phase 观察接缝（#513/#166）：on_phase 注册、mark_phase 按序通知、
-- 返回的 unsubscribe 闭包解除注册。验收车道 turn_driver 依赖该接缝观察真实
-- 回合相位序列，此处直接钉住行为（含 #520 披露的 unsubscribe 零覆盖）。
local lu = require("luaunit")
local support = require("test.support.shared_support")
local session_mod = require("src.turn.scheduler.session")

local _assert_eq = support.assert_eq

local function _make_session()
  return session_mod.new({
    game = { turn = {} },
  })
end

TestSessionObserver = {}

function TestSessionObserver:test_mark_phase_notifies_observers_in_registration_order()
  local s = _make_session()
  local fired = {}
  s:on_phase(function(phase)
    fired[#fired + 1] = "first:" .. phase
  end)
  s:on_phase(function(phase)
    fired[#fired + 1] = "second:" .. phase
  end)

  s:mark_phase("roll")

  lu.assertEquals(fired, { "first:roll", "second:roll" })
  _assert_eq(s.game.turn.phase, "roll", "mark_phase keeps production phase marking")
end

function TestSessionObserver:test_unsubscribe_removes_only_its_own_observer()
  -- kills unsubscribe 的 table.remove 下标偏移与 break 删除：解绑中间观察者后，
  -- 其余观察者仍须按序触发。
  local s = _make_session()
  local fired = {}
  s:on_phase(function(phase)
    fired[#fired + 1] = "keep_a:" .. phase
  end)
  local unsubscribe = s:on_phase(function(phase)
    fired[#fired + 1] = "drop:" .. phase
  end)
  s:on_phase(function(phase)
    fired[#fired + 1] = "keep_b:" .. phase
  end)

  unsubscribe()
  s:mark_phase("move")

  _assert_eq(#fired, 2, "unsubscribed observer must not fire again")
  lu.assertEquals(fired, { "keep_a:move", "keep_b:move" })
end

function TestSessionObserver:test_unsubscribe_of_unknown_observer_keeps_list_intact()
  -- kills unsubscribe 内循环换恒真/恒假：未注册（或已解绑）的闭包不得误删他人。
  local s = _make_session()
  local fired = {}
  s:on_phase(function(phase)
    fired[#fired + 1] = phase
  end)

  local stray = s:on_phase(function() end)
  stray()
  stray() -- 二次解绑不再命中任何观察者

  s:mark_phase("landing")
  lu.assertEquals(fired, { "landing" })
end

-- mutate 车道契约：内建 runner 只跑 spec return 的表，单类文件直接 return。
return TestSessionObserver

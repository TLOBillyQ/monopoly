-- #293 批3:src/turn/waits/ui_gate.lua 幸存者直测——fallback gate 默认值
-- (L7/8/9/10)与 resolve_modal_timeout_seconds 的边界(L42 and→or / >→>=)
-- 此前只被下游间接使用,本 spec 直测模块面。

local tick_ui_gate = require("src.turn.waits.ui_gate")
local timing = require("src.config.gameplay.timing")
local _config_reset = require("test.support.config_reset")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

TestTickUiGate = {}

function TestTickUiGate:setUp()
  _config_reset.reset_all()
end

function TestTickUiGate:test_resolve_ui_gate_returns_inert_fallback_when_no_resolver()
  -- #293: L7/8/9/10 _fallback_gate 默认值翻 true 变异——无 resolver 时必须
  -- 返回全部关断的惰性 gate。
  local gate = tick_ui_gate.resolve_ui_gate(nil, nil)
  _assert_eq(gate.input_blocked, false, "fallback input_blocked must be false")
  _assert_eq(gate.choice_active, false, "fallback choice_active must be false")
  _assert_eq(gate.market_active, false, "fallback market_active must be false")
  _assert_eq(gate.popup_active, false, "fallback popup_active must be false")
end

function TestTickUiGate:test_resolve_modal_timeout_seconds_falls_back_on_non_numeric_auto_close()
  -- #293: L42 and→or 变异让非数值 auto_close 也被采纳——非数值必须回退配置默认。
  local gate = { popup_auto_close_seconds = "abc" }
  local result = tick_ui_gate.resolve_modal_timeout_seconds(nil, { resolve_ui_gate = function() return gate end })
  _assert_eq(result, timing.popup_auto_close_seconds, "non-numeric auto_close must fall back to the configured default")
end

function TestTickUiGate:test_resolve_modal_timeout_seconds_falls_back_on_zero_auto_close()
  -- #293: L42 >→>= 变异让 0 也被采纳——0 秒自动关闭无意义,必须回退配置默认。
  local gate = { popup_auto_close_seconds = 0 }
  local result = tick_ui_gate.resolve_modal_timeout_seconds(nil, { resolve_ui_gate = function() return gate end })
  _assert_eq(result, timing.popup_auto_close_seconds, "zero auto_close must fall back to the configured default")
end

return TestTickUiGate

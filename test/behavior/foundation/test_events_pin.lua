-- monopoly_events 常量完整性 pin:#293 复核——6 个事件常量被 nil 替换存活,
-- 根因是测试从不迭代整张配置表。结构断言(每个事件名都是非空字符串)
-- 一次性击杀全部位点。
local lu = require("luaunit")

local monopoly_events = require("src.foundation.events")

local function _assert_eq(actual, expected)
  lu.assertEvalToTrue(actual == expected,
    "event name should keep its canonical value; expected " .. tostring(expected)
      .. " got " .. tostring(actual))
end

TestEventsPin = {}

function TestEventsPin:test_every_event_name_is_a_non_empty_string()
  local function walk(group, prefix)
    for name, value in pairs(group) do
      local key = prefix .. "." .. name
      -- emit / emit_intent 等 API 函数不是事件名常量,与字符串常量分开处理。
      if type(value) ~= "function" then
        if type(value) == "table" then
          walk(value, key)
        else
          lu.assertEvalToTrue(type(value) == "string" and value ~= "",
            key .. " should map to a non-empty string, got " .. tostring(value))
        end
      end
    end
  end
  walk(monopoly_events, "events")
end

function TestEventsPin:test_known_event_names_keep_their_canonical_values()
  _assert_eq(monopoly_events.movement.moved, "mv.moved")
  _assert_eq(monopoly_events.movement.passed_start, "mv.passed_start")
  _assert_eq(monopoly_events.movement.market_interrupt, "mv.market_interrupt")
  _assert_eq(monopoly_events.market.auto_skip, "mk.auto_skip")
  _assert_eq(monopoly_events.intent.need_choice, "it.need_choice")
end

function TestEventsPin:test_emit_intent_asserts_missing_kind_and_event()
  -- #293:emit_intent 的两处断言消息未测,消息→nil 变异存活。
  local ok_kind, err_kind = pcall(monopoly_events.emit_intent, nil, {})
  lu.assertEvalToTrue(ok_kind == false, "emit_intent without kind should assert")
  lu.assertEvalToTrue(tostring(err_kind):find("missing intent kind", 1, true) ~= nil,
    "kind assert should carry its message: " .. tostring(err_kind))

  local ok_event, err_event = pcall(monopoly_events.emit_intent, "no_such_kind", {})
  lu.assertEvalToTrue(ok_event == false, "emit_intent with unknown kind should assert")
  lu.assertEvalToTrue(tostring(err_event):find("missing intent event", 1, true) ~= nil,
    "event assert should carry its message: " .. tostring(err_event))
end

return TestEventsPin

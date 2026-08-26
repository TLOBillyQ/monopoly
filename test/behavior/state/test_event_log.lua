-- #293 批3 pin:src/state/event_log.lua 无既有直测文件,13 个幸存者集中在
-- 时钟回退链(_wall_now_hms/_os_date_hms/_now_hms)与 get_entries 起点钳制。
-- 策略:桩 runtime_ports.wall_now_hms 与 _G.os 分别驱动三条时钟路径,
-- 断言 time_text 的最终取值;桩函数与源码同表对象,桩值即契约值。

local lu = require("luaunit")
local event_log = require("src.state.event_log")
local runtime_ports = require("src.foundation.ports.runtime_ports")

local original_wall_now_hms = runtime_ports.wall_now_hms
local original_os = _G.os
local original_os_date = original_os and original_os.date or nil

local function _assert_eq(a, b, msg)
  lu.assertEvalToTrue(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _stub_wall(value)
  runtime_ports.wall_now_hms = function()
    return value
  end
end

TestEventLog = {}

function TestEventLog:tearDown()
  runtime_ports.wall_now_hms = original_wall_now_hms
  if original_os then
    original_os.date = original_os_date
  end
  _G.os = original_os
end

function TestEventLog:test_append_uses_wall_clock_hms_when_valid()
  -- L16 `runtime_ports.wall_now_hms()` 换 nil 与 L17 `type(hms) == "string" and
  -- hms ~= ""` 的 type/==/string/~= 四连变异:合法时钟串必须原样进入 time_text。
  _stub_wall("23:59:59")
  local log = event_log.new()
  local item = event_log.append(log, { kind = "test", text = "hello" })
  _assert_eq(item.time_text, "23:59:59", "valid wall clock hms must be used verbatim")
end

function TestEventLog:test_append_rejects_empty_wall_clock_string()
  -- L17 `hms ~= ""` 的 and->or 与 `~= ""` -> `~= nil`:空串必须被拒,
  -- 回退到系统时钟,不能原样进 time_text。
  _stub_wall("")
  local log = event_log.new()
  local item = event_log.append(log, { kind = "test", text = "hello" })
  lu.assertEvalToTrue(item.time_text ~= nil and item.time_text ~= "",
    "empty wall clock hms must fall back to a real clock; got " .. tostring(item.time_text))
end

function TestEventLog:test_append_falls_back_to_empty_when_no_clock_available()
  -- L43 `_now_hms()` 尾部的 `or ""` 换 nil:双时钟全缺时 time_text 必须空串;
  -- L33 `os_lib and type(os_lib.date) == "function"` 的 and->or 在 os 为 nil 时
  -- 撞 nil 索引报错(Eggy 沙箱 os 可缺,守卫是真实契约),基线走空回退。
  -- 注:_G.os 置 nil 会连 luaunit 自身一起带崩,故断言后立即还原。
  _stub_wall(nil)
  local saved_os = _G.os
  _G.os = nil
  local log = event_log.new()
  local item = event_log.append(log, { kind = "test", text = "hello" })
  _G.os = saved_os
  _assert_eq(item.time_text, "", "no clocks available must yield an empty time text")
end

function TestEventLog:test_append_ignores_a_failed_os_date_call()
  -- L28 `ok == true and type(text) == "string"` 的 and->or:os.date 报错时
  -- 返回文本(errmsg)必须被拒,不能进 time_text。
  _stub_wall(nil)
  _G.os.date = function()
    error("clock boom")
  end
  local log = event_log.new()
  local item = event_log.append(log, { kind = "test", text = "hello" })
  _assert_eq(item.time_text, "", "failed os.date must yield an empty time text")
end

function TestEventLog:test_get_entries_with_large_limit_starts_at_the_first_entry()
  -- L110 `math.max(1, n - read_limit + 1)` 的 1->0:limit 超过条目数时起点
  -- 必须钳在 1,变异体从 0 开始把 nil 塞进结果头。
  local log = event_log.new()
  event_log.append(log, { kind = "a", text = "one" })
  event_log.append(log, { kind = "b", text = "two" })
  local out = event_log.get_entries(log, 10)
  _assert_eq(#out, 2, "large limit must return all entries")
  lu.assertEvalToTrue(out[1] == log.entries[1], "first returned entry must be the first log entry")
end

function TestEventLog:test_pop_buffer_removes_only_the_matching_buffer()
  -- pop_buffer 契约直测:只摘除匹配的 hold,其余缓冲保留。
  local log = event_log.new()
  local hold_a = {}
  local hold_b = {}
  event_log.push_buffer(log, hold_a)
  event_log.push_buffer(log, hold_b)
  event_log.pop_buffer(hold_a)
  lu.assertEvalToTrue(#log.active_buffers == 1, "one buffer must remain after pop")
  lu.assertEvalToTrue(log.active_buffers[1] == hold_b, "the other buffer must stay")
end

return TestEventLog

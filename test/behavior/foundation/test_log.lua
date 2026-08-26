local lu = require("luaunit")
local logger = require("src.foundation.log")

-- warn 级合成文案统一带 spec_synthetic 前缀：logger 会经 print 落到
-- warn 采集器，保留前缀由 test/support/behavior_warns_data.lua 白名单豁免。
--
-- map #73 收缩后 logger 无环形缓冲：唯一出口是 print（→ 宿主 log.txt）
-- 与 ui_sink。spec 一律用 print 捕获断言。

local function _capture_print(fn)
  local captured = {}
  local original_print = _G.print
  rawset(_G, "print", function(...)
    local parts = {}
    for i = 1, select("#", ...) do
      parts[#parts + 1] = tostring(select(i, ...))
    end
    captured[#captured + 1] = table.concat(parts, " ")
  end)
  local ok, err = pcall(fn)
  rawset(_G, "print", original_print)
  if not ok then
    error(err)
  end
  return captured
end

local function _joined(lines)
  return table.concat(lines, "\n")
end

-- 回到 logger 的出厂配置。清空每回合限流的计数是 setter 的职责（重设配置即
-- 丢弃旧账本），spec 不碰 logger 内部字段。
local function _reset_logger()
  logger.set_info_per_turn_limit(nil)
  logger.set_info_turn_provider(nil)
  logger.reset_time_runtime()
  logger.set_ui_sink(nil)
end

-- 原生 LuaUnit 迁移:六个平级 describe 各带 before_each/after_each,按钩子边界
-- 拆成六个 Test* 类(before_each → setUp、after_each → tearDown),「logger module
-- defaults」的 describe 级 local saved_pkg 迁为 self.saved_pkg(与试点文件同款);
-- 裸 assert 语句按语义等价切到 lu.assertXxx,用例数与改写前一一对应
-- (9 + 10 + 5 + 4 + 1 + 1 = 30 例)。
TestLoggerOutput = {}

function TestLoggerOutput:setUp()
  _reset_logger()
end

function TestLoggerOutput:tearDown()
  _reset_logger()
end

function TestLoggerOutput:test_info_prints_a_formatted_info_line()
  local lines = _capture_print(function()
    logger.info("test message")
  end)
  local text = _joined(lines)
  lu.assertEvalToTrue(text:find("%[info%]"), "expected [info] level label")
  lu.assertEvalToTrue(text:find("test message"), "expected 'test message' in output")
end

function TestLoggerOutput:test_renders_the_time_prefix_the_formatter_yields()
  logger.set_time_formatter(function()
    return "12:34:56"
  end)
  local text = _joined(_capture_print(function()
    logger.info("timed")
  end))
  lu.assertEvalToTrue(text:find("^12:34:56 %[info%] timed"), "time prefix precedes level and text: " .. text)
end

function TestLoggerOutput:test_omits_the_time_prefix_when_the_formatter_yields_an_empty_string()
  -- 宿主可换 formatter(logger.set_time_formatter);空串即不带时间前缀,且不留
  -- 前导空格。契约同款,behavior 侧保留一份以覆盖 _format_entry 的空串分支。
  logger.set_time_formatter(function()
    return ""
  end)
  local text = _joined(_capture_print(function()
    logger.info("bare")
  end))
  lu.assertEvalToTrue(text:find("^%[info%] bare"), "no time prefix and no leading space: " .. text)
end

function TestLoggerOutput:test_omits_the_time_prefix_when_the_formatter_yields_nil()
  -- 宿主 formatter 返回 nil 不得打崩日志:与空串同样按「无时间前缀」渲染。
  logger.set_time_formatter(function()
    return nil
  end)
  local text = _joined(_capture_print(function()
    logger.info("nil_time")
  end))
  lu.assertEvalToTrue(text:find("^%[info%] nil_time"), "nil time prefix renders like an empty one: " .. text)
end

function TestLoggerOutput:test_warn_prints_a_formatted_warn_line()
  local lines = _capture_print(function()
    logger.warn("spec_synthetic something wrong")
  end)
  local text = _joined(lines)
  lu.assertEvalToTrue(text:find("%[warn%]"), "expected [warn] level label")
  lu.assertEvalToTrue(text:find("something wrong"), "expected warn text in output")
end

function TestLoggerOutput:test_stringifies_multiple_args_space_joined()
  local lines = _capture_print(function()
    logger.info("a", 1, true, nil)
  end)
  lu.assertEvalToTrue(_joined(lines):find("a 1 true nil", 1, true), "expected space-joined stringified args")
end

function TestLoggerOutput:test_ui_sink_receives_the_entry_alongside_print()
  local seen = nil
  logger.set_ui_sink(function(entry)
    seen = entry
  end)
  local lines = _capture_print(function()
    logger.warn("spec_synthetic sink probe")
  end)
  lu.assertNotNil(seen, "ui_sink should receive the entry")
  lu.assertIs(seen.level, "warn", "entry should carry level")
  lu.assertEvalToTrue(seen.text:find("sink probe"), "entry should carry text")
  lu.assertEvalToTrue(#lines >= 1, "print output should still happen with ui_sink set")
end

function TestLoggerOutput:test_log_once_logs_first_call_and_skips_duplicate_key()
  local sink = {}
  local first, second
  local lines = _capture_print(function()
    first = logger.log_once(sink, "info", "my_key", "first_message")
    second = logger.log_once(sink, "info", "my_key", "second_message")
  end)
  lu.assertIs(first, true, "expected first call to return true")
  lu.assertFalse(second, "expected second call to return false")
  local text = _joined(lines)
  lu.assertEvalToTrue(text:find("first_message"), "expected first message logged")
  lu.assertEvalToFalse(text:find("second_message"), "expected second message skipped")
end

function TestLoggerOutput:test_log_once_with_warn_level_routes_through_logger_warn()
  local sink = {}
  local lines = _capture_print(function()
    logger.log_once(sink, "warn", "warn_key", "spec_synthetic once warn")
  end)
  lu.assertEvalToTrue(_joined(lines):find("%[warn%]"), "warn level must route through logger.warn")
end

-- #522:warn 默认只进 log.txt(print),ui_sink 不再无条件上屏;确需玩家可见的
-- 规则提示用 logger.warn_ui 显式声明(产出 entry.ui == true),上屏白名单 =
-- 全部 warn_ui 调用点(grep 可得,2026-08-20 盘点时为空)。
TestLoggerUiChannel = {}

function TestLoggerUiChannel:setUp()
  _reset_logger()
end

function TestLoggerUiChannel:tearDown()
  _reset_logger()
end

function TestLoggerUiChannel:test_warn_entry_carries_no_ui_flag_by_default()
  local seen = nil
  logger.set_ui_sink(function(entry)
    seen = entry
  end)
  _capture_print(function()
    logger.warn("spec_synthetic plain warn")
  end)
  lu.assertNotNil(seen, "ui_sink still observes every warn entry")
  lu.assertIs(seen.ui, nil, "plain logger.warn must not flag the entry for ui")
end

function TestLoggerUiChannel:test_warn_ui_marks_entry_for_the_ui_sink_and_still_prints()
  local seen = nil
  logger.set_ui_sink(function(entry)
    seen = entry
  end)
  local lines = _capture_print(function()
    logger.warn_ui("spec_synthetic ui warn")
  end)
  lu.assertNotNil(seen, "ui_sink should receive warn_ui entries")
  lu.assertIs(seen.ui, true, "warn_ui must flag the entry for ui routing")
  lu.assertIs(seen.level, "warn", "warn_ui stays a warn-level entry")
  lu.assertEvalToTrue(_joined(lines):find("%[warn%]"), "warn_ui still prints a [warn] line to log.txt")
end

TestLoggerInfoPerTurnRateLimit = {}

function TestLoggerInfoPerTurnRateLimit:setUp()
  _reset_logger()
end

function TestLoggerInfoPerTurnRateLimit:tearDown()
  _reset_logger()
end

function TestLoggerInfoPerTurnRateLimit:test_limit_and_provider_suppress_info_beyond_limit_within_a_turn()
  logger.set_info_per_turn_limit(2)
  logger.set_info_turn_provider(function() return 1 end)
  local text = _joined(_capture_print(function()
    logger.info("msg1")
    logger.info("msg2")
    logger.info("msg3_suppressed")
  end))
  lu.assertEvalToTrue(text:find("msg1"), "expected msg1")
  lu.assertEvalToTrue(text:find("msg2"), "expected msg2")
  lu.assertEvalToFalse(text:find("msg3_suppressed"), "expected msg3 suppressed by rate limit")
end

function TestLoggerInfoPerTurnRateLimit:test_rebinding_the_turn_provider_drops_the_previous_configuration_s_count()
  -- 开新局会重新绑定 provider（src/turn/loop/init.lua）。上一局在回合 1 用尽的
  -- 配额不得抑制新一局回合 1 的首批 info。
  logger.set_info_per_turn_limit(1)
  logger.set_info_turn_provider(function() return 1 end)
  _capture_print(function()
    logger.info("previous_game_used_the_quota")
  end)

  logger.set_info_turn_provider(function() return 1 end)
  local text = _joined(_capture_print(function()
    logger.info("new_game_first_info")
  end))
  lu.assertEvalToTrue(text:find("new_game_first_info"), "a rebound provider starts a fresh per-turn count")
end

function TestLoggerInfoPerTurnRateLimit:test_rebinding_the_limit_drops_the_previous_configuration_s_count()
  logger.set_info_per_turn_limit(1)
  logger.set_info_turn_provider(function() return 1 end)
  _capture_print(function()
    logger.info("quota_used")
  end)

  logger.set_info_per_turn_limit(1)
  local text = _joined(_capture_print(function()
    logger.info("after_limit_reconfigured")
  end))
  lu.assertEvalToTrue(text:find("after_limit_reconfigured"), "a rebound limit starts a fresh per-turn count")
end

TestLoggerInfoPerTurnRateLimit["test_limit=1 suppresses the second info (boundary: >0 not >1)"] = function(self)
  logger.set_info_per_turn_limit(1)
  logger.set_info_turn_provider(function() return 1 end)
  local text = _joined(_capture_print(function()
    logger.info("first_ok")
    logger.info("second_should_be_suppressed_xyz")
  end))
  lu.assertEvalToTrue(text:find("first_ok"), "first must pass through")
  lu.assertEvalToFalse(text:find("second_should_be_suppressed_xyz"),
    "limit=1 with provider must suppress second info")
end

function TestLoggerInfoPerTurnRateLimit:test_limit_0_disables_rate_limiting()
  logger.set_info_per_turn_limit(0)
  logger.set_info_turn_provider(function() return 1 end)
  local text = _joined(_capture_print(function()
    for i = 1, 5 do logger.info("msg" .. i) end
  end))
  for i = 1, 5 do
    lu.assertEvalToTrue(text:find("msg" .. i), "limit=0 must not gate any messages; missing msg" .. i)
  end
end

function TestLoggerInfoPerTurnRateLimit:test_nil_provider_disables_rate_limiting()
  logger.set_info_per_turn_limit(2)
  logger.set_info_turn_provider(nil)
  local text = _joined(_capture_print(function()
    for i = 1, 5 do logger.info("msg" .. i) end
  end))
  for i = 1, 5 do
    lu.assertEvalToTrue(text:find("msg" .. i), "nil provider must let all through; missing msg" .. i)
  end
end

function TestLoggerInfoPerTurnRateLimit:test_provider_returning_nil_short_circuits_the_rate_limit_check()
  logger.set_info_per_turn_limit(1)
  logger.set_info_turn_provider(function() return nil end)
  local text = _joined(_capture_print(function()
    logger.info("a")
    logger.info("b")
  end))
  lu.assertEvalToTrue(text:find("a") and text:find("b"),
    "provider returning nil must skip rate limit (both logged)")
end

function TestLoggerInfoPerTurnRateLimit:test_new_turn_resets_the_counter()
  logger.set_info_per_turn_limit(2)
  local turn = 1
  logger.set_info_turn_provider(function() return turn end)
  local text = _joined(_capture_print(function()
    logger.info("t1a"); logger.info("t1b"); logger.info("t1_suppressed")
    turn = 2
    logger.info("t2a"); logger.info("t2b"); logger.info("t2_suppressed")
  end))
  lu.assertEvalToTrue(text:find("t1a") and text:find("t1b"), "expected first turn's two messages")
  lu.assertEvalToTrue(text:find("t2a") and text:find("t2b"), "turn change must reset counter")
  lu.assertEvalToFalse(text:find("t1_suppressed"), "expected t1 third suppressed")
  lu.assertEvalToFalse(text:find("t2_suppressed"), "expected t2 third suppressed")
end

function TestLoggerInfoPerTurnRateLimit:test_info_unlimited_bypasses_the_rate_limit()
  logger.set_info_per_turn_limit(1)
  logger.set_info_turn_provider(function() return 1 end)
  local text = _joined(_capture_print(function()
    logger.info_unlimited("u1")
    logger.info_unlimited("u2")
    logger.info_unlimited("u3")
  end))
  for i = 1, 3 do
    lu.assertEvalToTrue(text:find("u" .. i), "unlimited variant must bypass limit; missing u" .. i)
  end
end

function TestLoggerInfoPerTurnRateLimit:test_warn_is_never_rate_limited()
  logger.set_info_per_turn_limit(1)
  logger.set_info_turn_provider(function() return 1 end)
  local text = _joined(_capture_print(function()
    logger.warn("spec_synthetic w1")
    logger.warn("spec_synthetic w2")
  end))
  lu.assertEvalToTrue(text:find("w1") and text:find("w2"), "warn must bypass the info rate limit")
end

TestLoggerTimeRuntime = {}

function TestLoggerTimeRuntime:tearDown()
  logger.reset_time_runtime()
end

function TestLoggerTimeRuntime:test_timestamp_provider_is_called_per_entry_and_formatter_output_lands_in_the_line()
  local calls = 0
  logger.timestamp_provider = function() calls = calls + 1; return 7 end
  logger.time_formatter = function(ts) return "T" .. tostring(ts) end
  local text = _joined(_capture_print(function()
    logger.info("x")
    logger.info("y")
    logger.info("z")
  end))
  lu.assertEvalToTrue(calls >= 3, "timestamp_provider must be called per entry; got " .. calls)
  lu.assertEvalToTrue(text:find("T7"), "expected time_formatter output T7 in formatted line")
end

function TestLoggerTimeRuntime:test_time_formatter_receives_the_timestamp()
  local seen = {}
  logger.timestamp_provider = function() return 42 end
  logger.time_formatter = function(ts) seen[#seen + 1] = ts; return "" end
  _capture_print(function()
    logger.info("a")
  end)
  lu.assertIs(seen[1], 42, "time_formatter must receive timestamp_provider result")
end

TestLoggerTimeRuntime["test_configure_game_time zero-pads values < 10 and leaves >= 10 alone"] = function(self)
  logger.configure_game_time({
    get_timestamp = function() return 0 end,
    get_hour = function() return 9 end,
    get_minute = function() return 12 end,
    get_second = function() return 5 end,
  })
  lu.assertIs(logger.time_formatter(0), "09:12:05",
    "_pad2 must zero-pad < 10 and leave >= 10 untouched")
end

TestLoggerTimeRuntime["test_configure_game_time value=10 is not padded ('<' not '<=')"] = function(self)
  logger.configure_game_time({
    get_timestamp = function() return 0 end,
    get_hour = function() return 10 end,
    get_minute = function() return 10 end,
    get_second = function() return 10 end,
  })
  lu.assertIs(logger.time_formatter(0), "10:10:10", "value=10 must NOT pad")
end

function TestLoggerTimeRuntime:test_reset_time_runtime_restores_tostring_formatting()
  logger.configure_game_time({
    get_timestamp = function() return 0 end,
    get_hour = function() return 1 end,
    get_minute = function() return 2 end,
    get_second = function() return 3 end,
  })
  logger.reset_time_runtime()
  lu.assertIs(logger.timestamp_provider(), 0, "reset must restore zero timestamp provider")
  lu.assertIs(logger.time_formatter(7), "7", "reset must restore tostring formatter")
end

TestLoggerAnimDebugProvider = {}

function TestLoggerAnimDebugProvider:tearDown()
  logger.set_anim_debug_enabled_provider(nil)
end

function TestLoggerAnimDebugProvider:test_is_anim_debug_enabled_returns_false_without_provider()
  logger.set_anim_debug_enabled_provider(nil)
  lu.assertFalse(logger.is_anim_debug_enabled(), "expected false without provider")
end

function TestLoggerAnimDebugProvider:test_is_anim_debug_enabled_calls_provider()
  logger.set_anim_debug_enabled_provider(function() return true end)
  lu.assertTrue(logger.is_anim_debug_enabled(), "expected true from provider")
end

function TestLoggerAnimDebugProvider:test_is_anim_debug_enabled_returns_false_when_provider_errors()
  logger.set_anim_debug_enabled_provider(function() error("boom") end)
  lu.assertFalse(logger.is_anim_debug_enabled(), "expected false on provider error")
end

function TestLoggerAnimDebugProvider:test_is_anim_debug_enabled_requires_exact_true_from_provider()
  logger.set_anim_debug_enabled_provider(function() return "yes" end)
  lu.assertFalse(logger.is_anim_debug_enabled(), "truthy non-bool must not enable")
end

TestLoggerTestMode = {}

function TestLoggerTestMode:tearDown()
  logger.set_test_mode(false)
end

function TestLoggerTestMode:test_is_test_mode_returns_true_only_for_explicit_true()
  logger.test_mode = "yes"
  lu.assertFalse(logger.is_test_mode(), "is_test_mode must use == true equality")
  logger.test_mode = 1
  lu.assertFalse(logger.is_test_mode(), "is_test_mode must reject numeric truthy")
  logger.test_mode = true
  lu.assertTrue(logger.is_test_mode())
end

TestLoggerModuleDefaults = {}

function TestLoggerModuleDefaults:setUp()
  self.saved_pkg = package.loaded["src.foundation.log"]
  package.loaded["src.foundation.log"] = nil
end

function TestLoggerModuleDefaults:tearDown()
  package.loaded["src.foundation.log"] = self.saved_pkg
end

function TestLoggerModuleDefaults:test_fresh_module_defaults_counters_providers_test_mode()
  local m = require("src.foundation.log")
  lu.assertIs(m.info_turn_count, 0, "expected default info_turn_count=0")
  lu.assertIs(m.timestamp_provider(), 0, "default timestamp_provider must return 0")
  lu.assertIs(m.time_formatter(7), "7", "default time_formatter(7) must be '7'")
  lu.assertFalse(m.test_mode, "expected default test_mode=false")
  lu.assertFalse(m.is_test_mode())
end


-- mutate 车道统一返回全部类（#283 多类文件 return 首类假幸存方向）：
-- 正常车道扫 _G 收全部 Test* 类，但 mutate 内建 runner 只跑 return 的表，
-- 只 return 首个类会让其余类的用例在变异车道完全不执行。合并全部类，
-- 每个 test* 方法跑所属类 setUp/tearDown（见 multi_class_return）。
-- #293 复核:set_time_formatter / set_anim_debug_enabled_provider /
-- configure_game_time / log_once 的守卫断言消息未测,消息→nil 变异存活。
TestLoggerGuardMessages = {}

function TestLoggerGuardMessages:test_set_time_formatter_asserts_non_function()
  local ok, err = pcall(logger.set_time_formatter, 42)
  lu.assertEvalToTrue(ok == false, "non-function formatter should assert")
  lu.assertEvalToTrue(tostring(err):find("time formatter must be function", 1, true) ~= nil,
    "assert should carry its message: " .. tostring(err))
end

function TestLoggerGuardMessages:test_set_anim_debug_provider_asserts_bad_type()
  local ok, err = pcall(logger.set_anim_debug_enabled_provider, "not_a_function")
  lu.assertEvalToTrue(ok == false, "bad provider type should assert")
  lu.assertEvalToTrue(tostring(err):find("anim debug provider must be function or nil", 1, true) ~= nil,
    "assert should carry its message: " .. tostring(err))
end

function TestLoggerGuardMessages:test_configure_game_time_asserts_missing_api()
  local ok_api, err_api = pcall(logger.configure_game_time, nil)
  lu.assertEvalToTrue(ok_api == false, "configure_game_time without api should assert")
  lu.assertEvalToTrue(tostring(err_api):find("missing game api", 1, true) ~= nil,
    "assert should carry its message: " .. tostring(err_api))

  logger.configure_game_time({
    get_timestamp = function() return nil end,
    get_hour = function() return 0 end,
    get_minute = function() return 0 end,
    get_second = function() return 0 end,
  })
  local ok_stamp, err_stamp = pcall(function()
    logger.info("timestamp_assert_probe")
  end)
  lu.assertEvalToTrue(ok_stamp == false,
    "logging with a nil timestamp should hit the formatter assert")
  lu.assertEvalToTrue(tostring(err_stamp):find("missing timestamp", 1, true) ~= nil,
    "timestamp assert should carry its message: " .. tostring(err_stamp))
  logger.reset_time_runtime()

  -- L143 `game_api.get_timestamp()`→nil 变异:api 返回非 nil 时才可分。
  logger.configure_game_time({
    get_timestamp = function() return 12345 end,
    get_hour = function() return 7 end,
    get_minute = function() return 8 end,
    get_second = function() return 9 end,
  })
  local ok_live, err_live = pcall(function()
    logger.info("timestamp_live_probe")
  end)
  lu.assertEvalToTrue(ok_live == true,
    "a live timestamp should format without error: " .. tostring(err_live))
  local live_text = _joined(_capture_print(function()
    logger.info("timestamp_live_probe")
  end))
  lu.assertEvalToTrue(live_text:find("07:08:09", 1, true) ~= nil,
    "formatted time should reflect the game api components; got " .. live_text)
  logger.reset_time_runtime()
end

function TestLoggerGuardMessages:test_log_once_asserts_missing_sink()
  local ok, err = pcall(logger.log_once, nil, "info", "key", "msg")
  lu.assertEvalToTrue(ok == false, "log_once without sink should assert")
  lu.assertEvalToTrue(tostring(err):find("missing dedupe sink", 1, true) ~= nil,
    "assert should carry its message: " .. tostring(err))
end

return require("test.support.multi_class_return").merge(
  TestLoggerOutput,
  TestLoggerUiChannel,
  TestLoggerInfoPerTurnRateLimit,
  TestLoggerTimeRuntime,
  TestLoggerAnimDebugProvider,
  TestLoggerTestMode,
  TestLoggerModuleDefaults,
  TestLoggerGuardMessages
)

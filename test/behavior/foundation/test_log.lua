require("test.bootstrap").install_package_paths()
-- busted injects the extensible assertion object into each file environment.
-- luacheck: ignore 143
local luassert = assert
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

describe("TestLoggerOutput", function()

  before_each(function()
    _reset_logger()
  end)

  after_each(function()
    _reset_logger()
  end)

  it("test_info_prints_a_formatted_info_line", function()
    local lines = _capture_print(function()
      logger.info("test message")
    end)
    local text = _joined(lines)
    luassert.truthy(text:find("%[info%]"), "expected [info] level label")
    luassert.truthy(text:find("test message"), "expected 'test message' in output")
  end)

  it("test_renders_the_time_prefix_the_formatter_yields", function()
    logger.set_time_formatter(function()
      return "12:34:56"
    end)
    local text = _joined(_capture_print(function()
      logger.info("timed")
    end))
    luassert.truthy(text:find("^12:34:56 %[info%] timed"), "time prefix precedes level and text: " .. text)
  end)

  it("test_omits_the_time_prefix_when_the_formatter_yields_an_empty_string", function()
    -- 宿主可换 formatter(logger.set_time_formatter);空串即不带时间前缀,且不留
    -- 前导空格。契约同款,behavior 侧保留一份以覆盖 _format_entry 的空串分支。
    logger.set_time_formatter(function()
      return ""
    end)
    local text = _joined(_capture_print(function()
      logger.info("bare")
    end))
    luassert.truthy(text:find("^%[info%] bare"), "no time prefix and no leading space: " .. text)
  end)

  it("test_omits_the_time_prefix_when_the_formatter_yields_nil", function()
    -- 宿主 formatter 返回 nil 不得打崩日志:与空串同样按「无时间前缀」渲染。
    logger.set_time_formatter(function()
      return nil
    end)
    local text = _joined(_capture_print(function()
      logger.info("nil_time")
    end))
    luassert.truthy(text:find("^%[info%] nil_time"), "nil time prefix renders like an empty one: " .. text)
  end)

  it("test_warn_prints_a_formatted_warn_line", function()
    local lines = _capture_print(function()
      logger.warn("spec_synthetic something wrong")
    end)
    local text = _joined(lines)
    luassert.truthy(text:find("%[warn%]"), "expected [warn] level label")
    luassert.truthy(text:find("something wrong"), "expected warn text in output")
  end)

  it("test_stringifies_multiple_args_space_joined", function()
    local lines = _capture_print(function()
      logger.info("a", 1, true, nil)
    end)
    luassert.truthy(_joined(lines):find("a 1 true nil", 1, true), "expected space-joined stringified args")
  end)

  it("test_ui_sink_receives_the_entry_alongside_print", function()
    local seen = nil
    logger.set_ui_sink(function(entry)
      seen = entry
    end)
    local lines = _capture_print(function()
      logger.warn("spec_synthetic sink probe")
    end)
    luassert.is_not_nil(seen, "ui_sink should receive the entry")
    luassert.is.equal("warn", seen.level, "entry should carry level")
    luassert.truthy(seen.text:find("sink probe"), "entry should carry text")
    luassert.truthy(#lines >= 1, "print output should still happen with ui_sink set")
  end)

  it("test_log_once_logs_first_call_and_skips_duplicate_key", function()
    local sink = {}
    local first, second
    local lines = _capture_print(function()
      first = logger.log_once(sink, "info", "my_key", "first_message")
      second = logger.log_once(sink, "info", "my_key", "second_message")
    end)
    luassert.is.equal(true, first, "expected first call to return true")
    luassert.is_false(second, "expected second call to return false")
    local text = _joined(lines)
    luassert.truthy(text:find("first_message"), "expected first message logged")
    luassert.falsy(text:find("second_message"), "expected second message skipped")
  end)

  it("test_log_once_with_warn_level_routes_through_logger_warn", function()
    local sink = {}
    local lines = _capture_print(function()
      logger.log_once(sink, "warn", "warn_key", "spec_synthetic once warn")
    end)
    luassert.truthy(_joined(lines):find("%[warn%]"), "warn level must route through logger.warn")
  end)

  -- #522:warn 默认只进 log.txt(print),ui_sink 不再无条件上屏;确需玩家可见的
  -- 规则提示用 logger.warn_ui 显式声明(产出 entry.ui == true),上屏白名单 =
  -- 全部 warn_ui 调用点(grep 可得,2026-08-20 盘点时为空)。
end)
describe("TestLoggerUiChannel", function()

  before_each(function()
    _reset_logger()
  end)

  after_each(function()
    _reset_logger()
  end)

  it("test_warn_entry_carries_no_ui_flag_by_default", function()
    local seen = nil
    logger.set_ui_sink(function(entry)
      seen = entry
    end)
    _capture_print(function()
      logger.warn("spec_synthetic plain warn")
    end)
    luassert.is_not_nil(seen, "ui_sink still observes every warn entry")
    luassert.is.equal(nil, seen.ui, "plain logger.warn must not flag the entry for ui")
  end)

  it("test_warn_ui_marks_entry_for_the_ui_sink_and_still_prints", function()
    local seen = nil
    logger.set_ui_sink(function(entry)
      seen = entry
    end)
    local lines = _capture_print(function()
      logger.warn_ui("spec_synthetic ui warn")
    end)
    luassert.is_not_nil(seen, "ui_sink should receive warn_ui entries")
    luassert.is.equal(true, seen.ui, "warn_ui must flag the entry for ui routing")
    luassert.is.equal("warn", seen.level, "warn_ui stays a warn-level entry")
    luassert.truthy(_joined(lines):find("%[warn%]"), "warn_ui still prints a [warn] line to log.txt")
  end)

end)
describe("TestLoggerInfoPerTurnRateLimit", function()

  before_each(function()
    _reset_logger()
  end)

  after_each(function()
    _reset_logger()
  end)

  it("test_limit_and_provider_suppress_info_beyond_limit_within_a_turn", function()
    logger.set_info_per_turn_limit(2)
    logger.set_info_turn_provider(function() return 1 end)
    local text = _joined(_capture_print(function()
      logger.info("msg1")
      logger.info("msg2")
      logger.info("msg3_suppressed")
    end))
    luassert.truthy(text:find("msg1"), "expected msg1")
    luassert.truthy(text:find("msg2"), "expected msg2")
    luassert.falsy(text:find("msg3_suppressed"), "expected msg3 suppressed by rate limit")
  end)

  it("test_rebinding_the_turn_provider_drops_the_previous_configuration_s_count", function()
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
    luassert.truthy(text:find("new_game_first_info"), "a rebound provider starts a fresh per-turn count")
  end)

  it("test_rebinding_the_limit_drops_the_previous_configuration_s_count", function()
    logger.set_info_per_turn_limit(1)
    logger.set_info_turn_provider(function() return 1 end)
    _capture_print(function()
      logger.info("quota_used")
    end)

    logger.set_info_per_turn_limit(1)
    local text = _joined(_capture_print(function()
      logger.info("after_limit_reconfigured")
    end))
    luassert.truthy(text:find("after_limit_reconfigured"), "a rebound limit starts a fresh per-turn count")
  end)

  it("test_limit=1 suppresses the second info (boundary: >0 not >1)", function()
    logger.set_info_per_turn_limit(1)
    logger.set_info_turn_provider(function() return 1 end)
    local text = _joined(_capture_print(function()
      logger.info("first_ok")
      logger.info("second_should_be_suppressed_xyz")
    end))
    luassert.truthy(text:find("first_ok"), "first must pass through")
    luassert.falsy(text:find("second_should_be_suppressed_xyz"), "limit=1 with provider must suppress second info")
  end)

  it("test_limit_0_disables_rate_limiting", function()
    logger.set_info_per_turn_limit(0)
    logger.set_info_turn_provider(function() return 1 end)
    local text = _joined(_capture_print(function()
      for i = 1, 5 do logger.info("msg" .. i) end
    end))
    for i = 1, 5 do
      luassert.truthy(text:find("msg" .. i), "limit=0 must not gate any messages; missing msg" .. i)
    end
  end)

  it("test_nil_provider_disables_rate_limiting", function()
    logger.set_info_per_turn_limit(2)
    logger.set_info_turn_provider(nil)
    local text = _joined(_capture_print(function()
      for i = 1, 5 do logger.info("msg" .. i) end
    end))
    for i = 1, 5 do
      luassert.truthy(text:find("msg" .. i), "nil provider must let all through; missing msg" .. i)
    end
  end)

  it("test_provider_returning_nil_short_circuits_the_rate_limit_check", function()
    logger.set_info_per_turn_limit(1)
    logger.set_info_turn_provider(function() return nil end)
    local text = _joined(_capture_print(function()
      logger.info("a")
      logger.info("b")
    end))
    luassert.truthy(text:find("a") and text:find("b"), "provider returning nil must skip rate limit (both logged)")
  end)

  it("test_new_turn_resets_the_counter", function()
    logger.set_info_per_turn_limit(2)
    local turn = 1
    logger.set_info_turn_provider(function() return turn end)
    local text = _joined(_capture_print(function()
      logger.info("t1a"); logger.info("t1b"); logger.info("t1_suppressed")
      turn = 2
      logger.info("t2a"); logger.info("t2b"); logger.info("t2_suppressed")
    end))
    luassert.truthy(text:find("t1a") and text:find("t1b"), "expected first turn's two messages")
    luassert.truthy(text:find("t2a") and text:find("t2b"), "turn change must reset counter")
    luassert.falsy(text:find("t1_suppressed"), "expected t1 third suppressed")
    luassert.falsy(text:find("t2_suppressed"), "expected t2 third suppressed")
  end)

  it("test_info_unlimited_bypasses_the_rate_limit", function()
    logger.set_info_per_turn_limit(1)
    logger.set_info_turn_provider(function() return 1 end)
    local text = _joined(_capture_print(function()
      logger.info_unlimited("u1")
      logger.info_unlimited("u2")
      logger.info_unlimited("u3")
    end))
    for i = 1, 3 do
      luassert.truthy(text:find("u" .. i), "unlimited variant must bypass limit; missing u" .. i)
    end
  end)

  it("test_warn_is_never_rate_limited", function()
    logger.set_info_per_turn_limit(1)
    logger.set_info_turn_provider(function() return 1 end)
    local text = _joined(_capture_print(function()
      logger.warn("spec_synthetic w1")
      logger.warn("spec_synthetic w2")
    end))
    luassert.truthy(text:find("w1") and text:find("w2"), "warn must bypass the info rate limit")
  end)

end)
describe("TestLoggerTimeRuntime", function()

  after_each(function()
    logger.reset_time_runtime()
  end)

  it("test_timestamp_provider_is_called_per_entry_and_formatter_output_lands_in_the_line", function()
    local calls = 0
    logger.timestamp_provider = function() calls = calls + 1; return 7 end
    logger.time_formatter = function(ts) return "T" .. tostring(ts) end
    local text = _joined(_capture_print(function()
      logger.info("x")
      logger.info("y")
      logger.info("z")
    end))
    -- lint-allow: call-count timestamp_provider 是公共配置钩子,每条日志调用一次即其契约
    luassert.truthy(calls >= 3, "timestamp_provider must be called per entry; got " .. calls)
    luassert.truthy(text:find("T7"), "expected time_formatter output T7 in formatted line")
  end)

  it("test_time_formatter_receives_the_timestamp", function()
    local seen = {}
    logger.timestamp_provider = function() return 42 end
    logger.time_formatter = function(ts) seen[#seen + 1] = ts; return "" end
    _capture_print(function()
      logger.info("a")
    end)
    luassert.is.equal(42, seen[1], "time_formatter must receive timestamp_provider result")
  end)

  it("test_configure_game_time zero-pads values < 10 and leaves >= 10 alone", function()
    logger.configure_game_time({
      get_timestamp = function() return 0 end,
      get_hour = function() return 9 end,
      get_minute = function() return 12 end,
      get_second = function() return 5 end,
    })
    luassert.is.equal("09:12:05", logger.time_formatter(0), "_pad2 must zero-pad < 10 and leave >= 10 untouched")
  end)

  it("test_configure_game_time value=10 is not padded ('<' not '<=')", function()
    logger.configure_game_time({
      get_timestamp = function() return 0 end,
      get_hour = function() return 10 end,
      get_minute = function() return 10 end,
      get_second = function() return 10 end,
    })
    luassert.is.equal("10:10:10", logger.time_formatter(0), "value=10 must NOT pad")
  end)

  it("test_reset_time_runtime_restores_tostring_formatting", function()
    logger.configure_game_time({
      get_timestamp = function() return 0 end,
      get_hour = function() return 1 end,
      get_minute = function() return 2 end,
      get_second = function() return 3 end,
    })
    logger.reset_time_runtime()
    luassert.is.equal(0, logger.timestamp_provider(), "reset must restore zero timestamp provider")
    luassert.is.equal("7", logger.time_formatter(7), "reset must restore tostring formatter")
  end)

end)
describe("TestLoggerAnimDebugProvider", function()

  after_each(function()
    logger.set_anim_debug_enabled_provider(nil)
  end)

  it("test_is_anim_debug_enabled_returns_false_without_provider", function()
    logger.set_anim_debug_enabled_provider(nil)
    luassert.is_false(logger.is_anim_debug_enabled(), "expected false without provider")
  end)

  it("test_is_anim_debug_enabled_calls_provider", function()
    logger.set_anim_debug_enabled_provider(function() return true end)
    luassert.is_true(logger.is_anim_debug_enabled(), "expected true from provider")
  end)

  it("test_is_anim_debug_enabled_returns_false_when_provider_errors", function()
    logger.set_anim_debug_enabled_provider(function() error("boom") end)
    luassert.is_false(logger.is_anim_debug_enabled(), "expected false on provider error")
  end)

  it("test_is_anim_debug_enabled_requires_exact_true_from_provider", function()
    logger.set_anim_debug_enabled_provider(function() return "yes" end)
    luassert.is_false(logger.is_anim_debug_enabled(), "truthy non-bool must not enable")
  end)

end)
describe("TestLoggerTestMode", function()

  after_each(function()
    logger.set_test_mode(false)
  end)

  it("test_is_test_mode_returns_true_only_for_explicit_true", function()
    logger.test_mode = "yes"
    luassert.is_false(logger.is_test_mode(), "is_test_mode must use == true equality")
    logger.test_mode = 1
    luassert.is_false(logger.is_test_mode(), "is_test_mode must reject numeric truthy")
    logger.test_mode = true
    luassert.is_true(logger.is_test_mode())
  end)

end)
describe("TestLoggerModuleDefaults", function()
  local saved_pkg

  before_each(function()
    saved_pkg = package.loaded["src.foundation.log"]
    package.loaded["src.foundation.log"] = nil
  end)

  after_each(function()
    package.loaded["src.foundation.log"] = saved_pkg
  end)

  it("test_fresh_module_defaults_counters_providers_test_mode", function()
    local m = require("src.foundation.log")
    luassert.is.equal(0, m.info_turn_count, "expected default info_turn_count=0")
    luassert.is.equal(0, m.timestamp_provider(), "default timestamp_provider must return 0")
    luassert.is.equal("7", m.time_formatter(7), "default time_formatter(7) must be '7'")
    luassert.is_false(m.test_mode, "expected default test_mode=false")
    luassert.is_false(m.is_test_mode())
  end)


end)
describe("TestLoggerGuardMessages", function()

  it("test_set_time_formatter_asserts_non_function", function()
    local ok, err = pcall(logger.set_time_formatter, 42)
    luassert.truthy(ok == false, "non-function formatter should assert")
    luassert.truthy(tostring(err):find("time formatter must be function", 1, true) ~= nil, "assert should carry its message: " .. tostring(err))
  end)

  it("test_set_anim_debug_provider_asserts_bad_type", function()
    local ok, err = pcall(logger.set_anim_debug_enabled_provider, "not_a_function")
    luassert.truthy(ok == false, "bad provider type should assert")
    luassert.truthy(tostring(err):find("anim debug provider must be function or nil", 1, true) ~= nil, "assert should carry its message: " .. tostring(err))
  end)

  it("test_configure_game_time_asserts_missing_api", function()
    local ok_api, err_api = pcall(logger.configure_game_time, nil)
    luassert.truthy(ok_api == false, "configure_game_time without api should assert")
    luassert.truthy(tostring(err_api):find("missing game api", 1, true) ~= nil, "assert should carry its message: " .. tostring(err_api))

    logger.configure_game_time({
      get_timestamp = function() return nil end,
      get_hour = function() return 0 end,
      get_minute = function() return 0 end,
      get_second = function() return 0 end,
    })
    local ok_stamp, err_stamp = pcall(function()
      logger.info("timestamp_assert_probe")
    end)
    luassert.truthy(ok_stamp == false, "logging with a nil timestamp should hit the formatter assert")
    luassert.truthy(tostring(err_stamp):find("missing timestamp", 1, true) ~= nil, "timestamp assert should carry its message: " .. tostring(err_stamp))
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
    luassert.truthy(ok_live == true, "a live timestamp should format without error: " .. tostring(err_live))
    local live_text = _joined(_capture_print(function()
      logger.info("timestamp_live_probe")
    end))
    luassert.truthy(live_text:find("07:08:09", 1, true) ~= nil, "formatted time should reflect the game api components; got " .. live_text)
    logger.reset_time_runtime()
  end)

  it("test_log_once_asserts_missing_sink", function()
    local ok, err = pcall(logger.log_once, nil, "info", "key", "msg")
    luassert.truthy(ok == false, "log_once without sink should assert")
    luassert.truthy(tostring(err):find("missing dedupe sink", 1, true) ~= nil, "assert should carry its message: " .. tostring(err))
  end)

end)

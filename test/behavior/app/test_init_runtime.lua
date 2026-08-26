-- init_runtime 直测:has_game_time_api 守卫、build_ui_warn_sink 路径、
-- try_show_tip_to_role 的 pcall 故障臂。
local lu = require("luaunit")

local init_runtime = require("src.app.init_runtime")
local runtime_ports = require("src.foundation.ports.runtime_ports")

TestInitRuntime = {}

-- ---- has_game_time_api ----

function TestInitRuntime:test_has_game_time_api_nil_returns_false()
  lu.assertEvalToTrue(init_runtime.has_game_time_api(nil) == false,
    "nil game_api must return false")
end

function TestInitRuntime:test_has_game_time_api_missing_get_second_returns_false()
  -- 缺 get_second 也应返回 false，闭合 _GAME_TIME_METHODS 表的所有条目循环分支。
  local api = {
    get_timestamp = function() return 0 end,
    get_hour = function() return 0 end,
    get_minute = function() return 0 end,
  }
  lu.assertEvalToTrue(init_runtime.has_game_time_api(api) == false,
    "game_api missing get_second must return false")
end

-- ---- build_ui_warn_sink (走 _show_warn_in_ui 的 marquee/tips 臂) ----
-- #522:上屏是显式 opt-in——只有 entry.ui == true(logger.warn_ui 产出)的 warn
-- 才路由到宿主;默认 logger.warn 的开发者留痕只进 log.txt。

function TestInitRuntime:test_build_ui_warn_sink_skips_non_warn()
  local saved = _G.GlobalAPI
  _G.GlobalAPI = { show_tips = function(_, _) end }
  local sink = init_runtime.build_ui_warn_sink()
  -- info 级别应该跳过
  lu.assertEvalToTrue(sink({ level = "info", text = "nope" }) == nil,
    "non-warn level must be a no-op")
  _G.GlobalAPI = saved
end

function TestInitRuntime:test_build_ui_warn_sink_nil_entry_skips()
  local saved = _G.GlobalAPI
  _G.GlobalAPI = { show_tips = function(_, _) end }
  local sink = init_runtime.build_ui_warn_sink()
  lu.assertEvalToTrue(sink(nil) == nil, "nil entry must be a no-op")
  _G.GlobalAPI = saved
end

function TestInitRuntime:test_build_ui_warn_sink_routes_through_marquee()
  local saved = _G.GlobalAPI
  local called_text = nil
  _G.GlobalAPI = { show_message_marquee = function(text)
    called_text = text
  end }
  local sink = init_runtime.build_ui_warn_sink()
  sink({ level = "warn", ui = true, text = "test warn" })
  lu.assertEvalToTrue(called_text ~= nil, "marquee must be called for ui-opted warn entries when available")
  lu.assertEvalToTrue(string.find(called_text, "%[warn%]") ~= nil,
    "marquee text must contain [warn] prefix")
  _G.GlobalAPI = saved
end

function TestInitRuntime:test_build_ui_warn_sink_nil_text_defaults_to_empty()
  -- entry.text 为 nil 时 or "" 补空串;变异 ""→nil 会产出 nil .. 字符串。
  local saved = _G.GlobalAPI
  local called_text = nil
  _G.GlobalAPI = { show_message_marquee = function(text)
    called_text = text
  end }
  local sink = init_runtime.build_ui_warn_sink()
  sink({ level = "warn", ui = true })
  lu.assertEvalToTrue(called_text ~= nil, "marquee must be called even when text is nil")
  lu.assertEvalToTrue(string.find(called_text, "nil$") == nil,
    "trailing text must not contain literal nil when text is absent")
  _G.GlobalAPI = saved
end

function TestInitRuntime:test_build_ui_warn_sink_falls_back_to_show_tips()
  local saved = _G.GlobalAPI
  local called_text = nil
  _G.GlobalAPI = { show_tips = function(text, duration)
    called_text = text
    lu.assertEvalToTrue(duration == 3.0, "tips duration must be 3.0")
  end }
  local sink = init_runtime.build_ui_warn_sink()
  sink({ level = "warn", ui = true, text = "test warn" })
  lu.assertEvalToTrue(called_text ~= nil, "show_tips must be called as fallback when marquee is missing")
  _G.GlobalAPI = saved
end

function TestInitRuntime:test_build_ui_warn_sink_skips_warn_without_ui_opt_in()
  -- #522:开发者留痕(默认 logger.warn,entry.ui 为 nil)只进 log.txt,不上屏;
  -- 真机事故原型即终局 AI 面板跳过留痕经 sink 广播成 toast。
  local saved = _G.GlobalAPI
  local called = false
  _G.GlobalAPI = {
    show_message_marquee = function(_) called = true end,
    show_tips = function(_, _) called = true end,
  }
  local sink = init_runtime.build_ui_warn_sink()
  sink({ level = "warn", text = "dev trace" })
  lu.assertEvalToTrue(called == false, "warn entries without ui=true must not reach the host")
  _G.GlobalAPI = saved
end

-- ---- try_show_tip_to_role: pcall 故障臂 ----

function TestInitRuntime:test_try_show_tip_to_role_without_role_id_returns_false()
  local result = init_runtime.try_show_tip_to_role({ text = "x" }, "text", 1.0)
  lu.assertEvalToTrue(result == false, "tip without role_id must return false")
end

function TestInitRuntime:test_show_tips_pcall_error_returns_nil()
  -- 当 role.show_tips 索引抛错时，_show_tips_of 的 or 变 and 也应返回 nil。
  -- 用 runtime_ports.resolve_role 返回的对象带有会抛错的 __index 元表。
  local saved_resolve = runtime_ports.resolve_role
  local boom_role = setmetatable({}, {
    __index = function(_, _)
      error("role access boom")
    end
  })
  runtime_ports.resolve_role = function(_)
    return boom_role
  end
  local result = init_runtime.try_show_tip_to_role({ role_id = 1 }, "text", 1.0)
  lu.assertEvalToTrue(result == false, "pcall failure in _show_tips_of must return false from try_show_tip_to_role")
  runtime_ports.resolve_role = saved_resolve
end

function TestInitRuntime:test_call_show_tips_error_returns_false()
  -- _call_show_tips 的 pcall 失败时，and 变 or 返回不同值。
  local saved_resolve = runtime_ports.resolve_role
  local role = { show_tips = function(_, _)
    error("show_tips boom")
  end }
  runtime_ports.resolve_role = function(_)
    return role
  end
  local result = init_runtime.try_show_tip_to_role({ role_id = 1 }, "text", 1.0)
  lu.assertEvalToTrue(result == false,
    "pcall failure in _call_show_tips must return false from try_show_tip_to_role")
  runtime_ports.resolve_role = saved_resolve
end

function TestInitRuntime:test_show_tips_not_a_function_returns_false()
  -- role.show_tips 存在但不是函数时，_show_tips_of 的 or→and 变异等价因为
  -- 两种情况都触发 pcall 成功+show_tips 为非函数的路径。
  local saved_resolve = runtime_ports.resolve_role
  local role = { show_tips = "not_a_function" }
  runtime_ports.resolve_role = function(_)
    return role
  end
  local result = init_runtime.try_show_tip_to_role({ role_id = 1 }, "text", 1.0)
  lu.assertEvalToTrue(result == false,
    "non-function show_tips must return false from try_show_tip_to_role")
  runtime_ports.resolve_role = saved_resolve
end

return TestInitRuntime

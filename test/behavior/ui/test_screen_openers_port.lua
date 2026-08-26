local lu = require("luaunit")
local support = require("test.support.shared_support")
local screen_openers = require("src.ui.seams.screen_openers")

local _assert_eq = support.assert_eq

-- screen_openers 是纯契约 port(#332 拆 coord↔screens):coord 开屏动作经此接缝,
-- 实现由装配侧 configure 注入(host_install / 测试基线 / acceptance 绑定),本文件
-- 不反向依赖 screens。测试用假实现钉转发契约——参数/返回值原样穿透;未注入实现
-- 时调用必须当场报错,装配遗漏即刻暴露。

local function _fake_impl(seen)
  return {
    open_secondary_confirm = function(state, choice, choice_id)
      seen.open_secondary_confirm = { state = state, choice = choice, choice_id = choice_id }
      return "open_secondary_confirm_ret"
    end,
    open_pre_confirm = function(state, choice, option_id, title, body)
      seen.open_pre_confirm = { state = state, choice = choice, option_id = option_id, title = title, body = body }
      return "open_pre_confirm_ret"
    end,
    open_item_phase_pre_confirm = function(state, choice)
      seen.open_item_phase_pre_confirm = { state = state, choice = choice }
      return "open_item_phase_pre_confirm_ret"
    end,
    refresh_secondary_confirm_copy = function(state, option_id)
      seen.refresh_secondary_confirm_copy = { state = state, option_id = option_id }
      return "refresh_secondary_confirm_copy_ret"
    end,
    open_market = function(state, choice, choice_id, market)
      seen.open_market = { state = state, choice = choice, choice_id = choice_id, market = market }
      return "open_market_ret"
    end,
    close_market = function(state)
      seen.close_market = { state = state }
      return "close_market_ret"
    end,
  }
end

local _METHODS = {
  { "open_secondary_confirm", { { s = 1 }, { c = 1 }, 7 } },
  { "open_pre_confirm", { { s = 2 }, { c = 2 }, 8, "标题", "正文" } },
  { "open_item_phase_pre_confirm", { { s = 3 }, { c = 3 } } },
  { "refresh_secondary_confirm_copy", { { s = 4 }, 9 } },
  { "open_market", { { s = 5 }, { c = 5 }, 10, { m = 1 } } },
  { "close_market", { { s = 6 } } },
}

TestScreenOpenersPort = {}

function TestScreenOpenersPort:setUp()
  screen_openers.reset_for_tests()
end

for _, method in ipairs(_METHODS) do
  local name, args = method[1], method[2]
  TestScreenOpenersPort["test_" .. name .. "_forwards_to_the_configured_impl"] = function(self)
    local seen = {}
    screen_openers.configure(_fake_impl(seen))
    local ret = screen_openers[name](table.unpack(args))
    _assert_eq(seen[name].state, args[1], name .. " state must pass through")
    _assert_eq(ret, name .. "_ret", name .. " must return the impl's value")
  end
end

local function _expect_error(fragment, fn)
  local ok, err = pcall(fn)
  lu.assertEvalToTrue(ok == false, "call should raise")
  lu.assertEvalToTrue(
    tostring(err):find(fragment, 1, true) ~= nil,
    "error should mention: " .. tostring(fragment) .. ", got: " .. tostring(err)
  )
end

function TestScreenOpenersPort:test_calls_without_a_configured_impl_error_loudly()
  _expect_error("missing screen_openers implementation", function()
    screen_openers.open_secondary_confirm({}, {}, 1)
  end)
  _expect_error("missing screen_openers implementation", function()
    screen_openers.close_market({})
  end)
end

function TestScreenOpenersPort:test_reset_for_tests_clears_the_configured_impl()
  screen_openers.configure(_fake_impl({}))
  screen_openers.reset_for_tests()
  _expect_error("missing screen_openers implementation", function()
    screen_openers.open_market({}, {}, 1, {})
  end)
end

function TestScreenOpenersPort:test_configure_rejects_an_impl_missing_methods()
  _expect_error("missing open_secondary_confirm", function()
    screen_openers.configure({ close_market = function() end })
  end)
  _expect_error("missing open_pre_confirm", function()
    screen_openers.configure({ open_secondary_confirm = function() end })
  end)
  _expect_error("missing close_market", function()
    screen_openers.configure({
      open_secondary_confirm = function() end,
      open_pre_confirm = function() end,
      open_item_phase_pre_confirm = function() end,
      refresh_secondary_confirm_copy = function() end,
      open_market = function() end,
    })
  end)
end

function TestScreenOpenersPort:test_configure_rejects_a_non_table_impl()
  _expect_error("invalid screen_openers implementation", function()
    screen_openers.configure(nil)
  end)
end

function TestScreenOpenersPort:test_missing_impl_errors_name_each_unconfigured_verb()
  _expect_error("missing screen_openers implementation", function()
    screen_openers.open_pre_confirm({}, {}, 1, "标题", "正文")
  end)
  _expect_error("missing screen_openers implementation", function()
    screen_openers.open_item_phase_pre_confirm({}, {})
  end)
  _expect_error("missing screen_openers implementation", function()
    screen_openers.refresh_secondary_confirm_copy({}, 1)
  end)
end

function TestScreenOpenersPort:test_is_configured_reflects_the_configuration_state()
  lu.assertEvalToTrue(screen_openers.is_configured() == false, "a fresh port starts unconfigured")
  screen_openers.configure(_fake_impl({}))
  lu.assertEvalToTrue(screen_openers.is_configured() == true, "a configured port reports configured")
  screen_openers.reset_for_tests()
  lu.assertEvalToTrue(screen_openers.is_configured() == false, "reset returns to unconfigured")
end

function TestScreenOpenersPort:test_forwarding_proxies_are_stable_across_reconfiguration()
  -- 旧实现调用时读字段,替换实现后旧句柄仍走新实现(与 host_slot 转发同语义)。
  local first_seen, second_seen = {}, {}
  screen_openers.configure(_fake_impl(first_seen))
  screen_openers.open_market({ a = 1 }, { c = 1 }, 1, {})
  screen_openers.configure(_fake_impl(second_seen))
  screen_openers.open_market({ a = 2 }, { c = 2 }, 2, {})
  _assert_eq(first_seen.open_market.state.a, 1, "first impl saw the first call")
  _assert_eq(second_seen.open_market.state.a, 2, "second impl saw the second call")
end


return TestScreenOpenersPort

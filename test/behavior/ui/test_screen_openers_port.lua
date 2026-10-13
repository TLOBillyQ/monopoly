require("test.bootstrap").install_package_paths()
local luassert = assert
local support = require("test.support.shared_support")
local screen_openers = require("src.ui.seams.screen_openers")

local function _assert_eq(a, b, msg) luassert.is.equal(b, a, msg) end

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
describe("TestScreenOpenersPort", function()
before_each(function()
  screen_openers.reset_for_tests()
end)

for _, method in ipairs(_METHODS) do
  local name, args = method[1], method[2]
  it("test_" .. name .. "_forwards_to_the_configured_impl", function()
    local seen = {}
    screen_openers.configure(_fake_impl(seen))
    local ret = screen_openers[name](table.unpack(args))
    _assert_eq(seen[name].state, args[1], name .. " state must pass through")
    _assert_eq(ret, name .. "_ret", name .. " must return the impl's value")
  end)
end

local function _expect_error(fragment, fn)
  local ok, err = pcall(fn)
  luassert.truthy(ok == false, "call should raise")
  luassert.truthy(
    tostring(err):find(fragment, 1, true) ~= nil,
    "error should mention: " .. tostring(fragment) .. ", got: " .. tostring(err)
  )
end

it("test_calls_without_a_configured_impl_error_loudly", function()
  _expect_error("missing screen_openers implementation", function()
    screen_openers.open_secondary_confirm({}, {}, 1)
  end)
  _expect_error("missing screen_openers implementation", function()
    screen_openers.close_market({})
  end)
end)

it("test_reset_for_tests_clears_the_configured_impl", function()
  screen_openers.configure(_fake_impl({}))
  screen_openers.reset_for_tests()
  _expect_error("missing screen_openers implementation", function()
    screen_openers.open_market({}, {}, 1, {})
  end)
end)

it("test_configure_rejects_an_impl_missing_methods", function()
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
end)

it("test_configure_rejects_a_non_table_impl", function()
  _expect_error("invalid screen_openers implementation", function()
    screen_openers.configure(nil)
  end)
end)

it("test_missing_impl_errors_name_each_unconfigured_verb", function()
  _expect_error("missing screen_openers implementation", function()
    screen_openers.open_pre_confirm({}, {}, 1, "标题", "正文")
  end)
  _expect_error("missing screen_openers implementation", function()
    screen_openers.open_item_phase_pre_confirm({}, {})
  end)
  _expect_error("missing screen_openers implementation", function()
    screen_openers.refresh_secondary_confirm_copy({}, 1)
  end)
end)

it("test_is_configured_reflects_the_configuration_state", function()
  luassert.truthy(screen_openers.is_configured() == false, "a fresh port starts unconfigured")
  screen_openers.configure(_fake_impl({}))
  luassert.truthy(screen_openers.is_configured() == true, "a configured port reports configured")
  screen_openers.reset_for_tests()
  luassert.truthy(screen_openers.is_configured() == false, "reset returns to unconfigured")
end)

it("test_forwarding_proxies_are_stable_across_reconfiguration", function()
  -- 旧实现调用时读字段,替换实现后旧句柄仍走新实现(与 host_slot 转发同语义)。
  local first_seen, second_seen = {}, {}
  screen_openers.configure(_fake_impl(first_seen))
  screen_openers.open_market({ a = 1 }, { c = 1 }, 1, {})
  screen_openers.configure(_fake_impl(second_seen))
  screen_openers.open_market({ a = 2 }, { c = 2 }, 2, {})
  _assert_eq(first_seen.open_market.state.a, 1, "first impl saw the first call")
  _assert_eq(second_seen.open_market.state.a, 2, "second impl saw the second call")
end)


end)

local lu = require("luaunit")
local support = require("test.support.shared_support")
local share_panel = require("src.foundation.ports.share_panel")

local _assert_eq = support.assert_eq

-- share_panel 是纯契约 port(#463,与 card_reveal #329 同构):宿主调用实现下沉
-- src/host/share_panel,由装配侧 configure 注入(host_install / 测试基线 /
-- acceptance 绑定三处同款),本文件不反向依赖实现。测试用假实现钉转发契约——
-- actor_role_id/tag 参数与返回值原样穿透;与 card_reveal 不同,未配置时
-- try_show 安全降级返回 false 而非报错(分享面板是锦上添花能力,装配遗漏
-- 不该砸断调用方)。

TestSharePanelPort = {}

function TestSharePanelPort:setUp()
  share_panel.reset_for_tests()
end

function TestSharePanelPort:tearDown()
  support.restore_runtime_services()
end

local function _fake_impl(seen)
  return {
    try_show = function(actor_role_id, tag)
      seen.actor_role_id = actor_role_id
      seen.tag = tag
      return "impl_ret"
    end,
  }
end

local function _expect_error(fragment, fn)
  local ok, err = pcall(fn)
  lu.assertEvalToTrue(ok == false, "call should raise")
  lu.assertEvalToTrue(
    tostring(err):find(fragment, 1, true) ~= nil,
    "error should mention: " .. tostring(fragment) .. ", got: " .. tostring(err)
  )
end

function TestSharePanelPort:test_try_show_forwards_to_the_configured_impl()
  local seen = {}
  share_panel.configure(_fake_impl(seen))
  local ret = share_panel.try_show(7, "share button")
  _assert_eq(ret, "impl_ret", "return value must pass through")
  _assert_eq(seen.actor_role_id, 7, "actor_role_id must pass through")
  _assert_eq(seen.tag, "share button", "tag must pass through")
end

function TestSharePanelPort:test_try_show_without_a_configured_impl_degrades_to_false()
  _assert_eq(share_panel.try_show(1), false, "unconfigured port must degrade to false, not raise")
  _assert_eq(share_panel.try_show(nil, "auto share panel"), false,
    "unconfigured port must degrade to false for any arguments")
end

function TestSharePanelPort:test_reset_for_tests_clears_the_configured_impl()
  share_panel.configure(_fake_impl({}))
  share_panel.reset_for_tests()
  _assert_eq(share_panel.try_show(1), false, "reset must return the port to the unconfigured fallback")
end

function TestSharePanelPort:test_configure_rejects_an_impl_missing_try_show()
  _expect_error("missing try_show", function()
    share_panel.configure({})
  end)
end

function TestSharePanelPort:test_configure_rejects_a_non_table_impl()
  _expect_error("invalid share_panel implementation", function()
    share_panel.configure(nil)
  end)
end

function TestSharePanelPort:test_is_configured_reflects_the_configuration_state()
  lu.assertEvalToTrue(share_panel.is_configured() == false, "a fresh port starts unconfigured")
  share_panel.configure(_fake_impl({}))
  lu.assertEvalToTrue(share_panel.is_configured() == true, "a configured port reports configured")
  share_panel.reset_for_tests()
  lu.assertEvalToTrue(share_panel.is_configured() == false, "reset returns to unconfigured")
end

return TestSharePanelPort

local lu = require("luaunit")
local support = require("test.support.shared_support")
local resolver_seam = require("src.ui.seams.local_actor_resolver")

local _assert_eq = support.assert_eq

-- local_actor_resolver 接缝是纯契约 port(#332 拆 ui.input ↔ ui.coord 投影环):
-- input 层经它解析点击者身份,不反向 require coord/render 实现;实现由装配侧
-- configure 注入(host_install / 测试基线 / acceptance 绑定),未注入时调用
-- 当场报错。两个动词(from_event/turn_bound)原样转发,别名语义与实现模块
-- 一致;#446 收掉无生产消费者的 resolve_local。

local function _fake_impl(seen)
  return {
    resolve_from_event = function(state, data)
      seen.resolve_from_event = { state = state, data = data }
      return "resolve_from_event_ret"
    end,
    resolve_turn_bound = function(state, data)
      seen.resolve_turn_bound = { state = state, data = data }
      return "resolve_turn_bound_ret"
    end,
  }
end

TestLocalActorResolverSeam = {}

function TestLocalActorResolverSeam:setUp()
  resolver_seam.reset_for_tests()
end

for _, method in ipairs({ "resolve_from_event", "resolve_turn_bound" }) do
  TestLocalActorResolverSeam["test_" .. method .. "_forwards_to_the_configured_impl"] = function()
    local seen = {}
    resolver_seam.configure(_fake_impl(seen))
    local state, data = { s = 1 }, { d = 1 }
    local ret = resolver_seam[method](state, data)
    _assert_eq(seen[method].state, state, method .. " state must pass through")
    _assert_eq(seen[method].data, data, method .. " data must pass through")
    _assert_eq(ret, method .. "_ret", method .. " must return the impl's value")
  end
end

function TestLocalActorResolverSeam:test_calls_without_a_configured_impl_error_loudly()
  local ok, err = pcall(function()
    resolver_seam.resolve_from_event({}, {})
  end)
  lu.assertEvalToTrue(ok == false, "call should raise")
  lu.assertEvalToTrue(
    tostring(err):find("missing local_actor_resolver implementation", 1, true) ~= nil,
    "error should mention the missing implementation, got: " .. tostring(err)
  )
end

function TestLocalActorResolverSeam:test_reset_for_tests_clears_the_configured_impl()
  resolver_seam.configure(_fake_impl({}))
  resolver_seam.reset_for_tests()
  local ok, err = pcall(function()
    resolver_seam.resolve_turn_bound({}, {})
  end)
  lu.assertEvalToTrue(ok == false, "call after reset should raise")
  lu.assertEvalToTrue(
    tostring(err):find("missing local_actor_resolver implementation", 1, true) ~= nil,
    "error should mention the missing implementation, got: " .. tostring(err)
  )
end

function TestLocalActorResolverSeam:test_configure_rejects_an_impl_missing_methods()
  local ok, err = pcall(function()
    resolver_seam.configure({ resolve_from_event = function() end })
  end)
  lu.assertEvalToTrue(ok == false, "configure should raise for a partial impl")
  lu.assertEvalToTrue(
    tostring(err):find("missing resolve_turn_bound", 1, true) ~= nil,
    "error should name the missing method, got: " .. tostring(err)
  )

  ok, err = pcall(function()
    resolver_seam.configure({
      resolve_turn_bound = function() end,
    })
  end)
  lu.assertEvalToTrue(ok == false, "configure should raise for a partial impl")
  lu.assertEvalToTrue(
    tostring(err):find("missing resolve_from_event", 1, true) ~= nil,
    "error should name the missing method, got: " .. tostring(err)
  )
end

function TestLocalActorResolverSeam:test_configure_rejects_a_non_table_impl()
  local ok, err = pcall(function()
    resolver_seam.configure(nil)
  end)
  lu.assertEvalToTrue(ok == false, "configure should raise for a non-table impl")
  lu.assertEvalToTrue(
    tostring(err):find("invalid local_actor_resolver implementation", 1, true) ~= nil,
    "configure should name the invalid impl, got: " .. tostring(err)
  )
end

function TestLocalActorResolverSeam:test_resolve_turn_bound_without_impl_errors_loudly()
  local ok, err = pcall(function()
    resolver_seam.resolve_turn_bound({}, {})
  end)
  lu.assertEvalToTrue(ok == false, "resolve_turn_bound without a configured impl should raise")
  lu.assertEvalToTrue(
    tostring(err):find("missing local_actor_resolver implementation", 1, true) ~= nil,
    "error should mention the missing implementation, got: " .. tostring(err)
  )
end

function TestLocalActorResolverSeam:test_is_configured_reflects_the_configuration_state()
  lu.assertEvalToTrue(resolver_seam.is_configured() == false, "a fresh seam starts unconfigured")
  resolver_seam.configure(_fake_impl({}))
  lu.assertEvalToTrue(resolver_seam.is_configured() == true, "a configured seam reports configured")
  resolver_seam.reset_for_tests()
  lu.assertEvalToTrue(resolver_seam.is_configured() == false, "reset returns to unconfigured")
end


return TestLocalActorResolverSeam

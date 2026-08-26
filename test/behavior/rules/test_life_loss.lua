-- life_loss(ADR 0046):规则层经 runtime_ports.call_role_die 触达宿主
-- role.die,不再直接摸宿主对象与组件系统;成功判据 = 端口返回 true。
local lu = require("luaunit")
local support = require("test.support.shared_support")
local life_loss = require("src.rules.endgame.life_loss")
local runtime_ports = require("src.foundation.ports.runtime_ports")

TestLifeLoss = {}

function TestLifeLoss:test_try_call_life_die_returns_false_for_nil_role()
  local called = false
  support.with_patches({
    {
      target = runtime_ports,
      key = "call_role_die",
      value = function()
        called = true
        return true
      end,
    },
  }, function()
    lu.assertEvalToTrue(life_loss.try_call_life_die(nil) == false,
      "nil role yields false without touching the port")
  end)
  lu.assertEvalToTrue(called == false, "nil role must not reach the host port")
end

function TestLifeLoss:test_try_call_life_die_delegates_to_the_runtime_port()
  local seen = nil
  local result = nil
  support.with_patches({
    {
      target = runtime_ports,
      key = "call_role_die",
      value = function(role)
        seen = role
        return true
      end,
    },
  }, function()
    result = life_loss.try_call_life_die({ id = 1 })
  end)
  lu.assertEvalToTrue(result == true, "a truthy port result yields true")
  lu.assertEvalToTrue(seen ~= nil and seen.id == 1, "the port must receive the role")
end

function TestLifeLoss:test_try_call_life_die_returns_false_when_port_returns_false()
  local result = nil
  support.with_patches({
    {
      target = runtime_ports,
      key = "call_role_die",
      value = function()
        return false
      end,
    },
  }, function()
    result = life_loss.try_call_life_die({ id = 2 })
  end)
  lu.assertEvalToTrue(result == false, "a falsy port result yields false")
end

-- 以下三条走共享基线的真实默认端口(role_die 宿主适配),钉宿主直调语义。
function TestLifeLoss:test_try_call_life_die_returns_false_when_role_die_throws()
  local role = {
    die = function()
      error("host die failed")
    end,
  }
  lu.assertEvalToTrue(life_loss.try_call_life_die(role) == false,
    "a throwing role.die must yield false")
end

function TestLifeLoss:test_try_call_life_die_returns_false_when_role_has_no_die_method()
  lu.assertEvalToTrue(life_loss.try_call_life_die({}) == false,
    "a role without die yields false")
end

function TestLifeLoss:test_try_call_life_die_returns_true_when_role_die_succeeds()
  local role = {
    die = function()
      return true
    end,
  }
  lu.assertEvalToTrue(life_loss.try_call_life_die(role) == true,
    "a succeeding role.die yields true")
end

return TestLifeLoss

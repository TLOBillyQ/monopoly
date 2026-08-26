-- role_die 宿主适配 spec(ADR 0046):单次直调 role.die(role, nil),
-- 成功判据 = 返回值 truthy;pcall 只防宿主异常炸穿规则层;失败必留痕,禁止静默。
local lu = require("luaunit")
local support = require("test.support.shared_support")
local role_die = require("src.host.role_die")
local logger = require("src.foundation.log")

-- 在 with_patches 窗口内执行调用并捕获全部 warn 日志。
local function _call(role)
  local warns = {}
  local result
  support.with_patches({
    {
      target = logger,
      key = "warn",
      value = function(...)
        warns[#warns + 1] = table.concat({ ... }, " ")
      end,
    },
  }, function()
    result = role_die.call_role_die(role)
  end)
  return result, warns
end

TestRoleDie = {}

function TestRoleDie:test_call_role_die_calls_die_with_role_and_nil()
  local received_first, received_second
  local role = {
    die = function(first, second)
      received_first = first
      received_second = second
      return true
    end,
  }
  local result = role_die.call_role_die(role)
  lu.assertEvalToTrue(result == true, "a succeeding role.die yields true")
  lu.assertEvalToTrue(received_first == role, "die must receive the role as self")
  lu.assertEvalToTrue(received_second == nil, "die must receive nil as the second argument")
end

function TestRoleDie:test_call_role_die_accepts_any_truthy_return()
  local role = {
    die = function()
      return 1
    end,
  }
  lu.assertEvalToTrue(role_die.call_role_die(role) == true,
    "a truthy non-boolean return still counts as success")
end

function TestRoleDie:test_call_role_die_returns_false_and_warns_when_die_raises()
  local role = {
    die = function()
      error("host die failed")
    end,
  }
  local result, warns = _call(role)
  lu.assertEvalToTrue(result == false, "a throwing role.die must yield false")
  lu.assertEvalToTrue(#warns == 1, "a throwing role.die must leave exactly one warn")
  lu.assertEvalToTrue(warns[1]:find("raised", 1, true) ~= nil,
    "warn should mention the raise; got " .. tostring(warns[1]))
  lu.assertEvalToTrue(warns[1]:find("host die failed", 1, true) ~= nil,
    "warn should carry the raised error detail; got " .. tostring(warns[1]))
end

function TestRoleDie:test_call_role_die_returns_false_and_warns_when_die_returns_falsy()
  local role_nil = { die = function() return nil end }
  local result_nil, warns_nil = _call(role_nil)
  lu.assertEvalToTrue(result_nil == false, "nil return must yield false")
  lu.assertEvalToTrue(#warns_nil == 1, "nil return must leave exactly one warn")

  local role_false = { die = function() return false end }
  local result_false, warns_false = _call(role_false)
  lu.assertEvalToTrue(result_false == false, "false return must yield false")
  lu.assertEvalToTrue(#warns_false == 1, "false return must leave exactly one warn")
  lu.assertEvalToTrue(warns_false[1]:find("falsy", 1, true) ~= nil,
    "warn should mention the falsy return; got " .. tostring(warns_false[1]))
  lu.assertEvalToTrue(warns_false[1]:find("falsy: false", 1, true) ~= nil,
    "warn should carry the falsy value detail; got " .. tostring(warns_false[1]))
  lu.assertEvalToTrue(warns_nil[1]:find("falsy: nil", 1, true) ~= nil,
    "warn should carry the nil return detail; got " .. tostring(warns_nil[1]))
end

function TestRoleDie:test_call_role_die_returns_false_and_warns_for_nil_role()
  local result, warns = _call(nil)
  lu.assertEvalToTrue(result == false, "nil role must yield false")
  lu.assertEvalToTrue(#warns == 1, "nil role must leave exactly one warn")
  lu.assertEvalToTrue(warns[1]:find("role is nil", 1, true) ~= nil,
    "nil role warn should carry the skip reason; got " .. tostring(warns[1]))
end

function TestRoleDie:test_call_role_die_returns_false_and_warns_when_role_lacks_die()
  local result, warns = _call({})
  lu.assertEvalToTrue(result == false, "a role without die must yield false")
  lu.assertEvalToTrue(#warns == 1, "missing die must leave exactly one warn")
  lu.assertEvalToTrue(warns[1]:find("die", 1, true) ~= nil,
    "warn should name the missing method; got " .. tostring(warns[1]))
end

return TestRoleDie

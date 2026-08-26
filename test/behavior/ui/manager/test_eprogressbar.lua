-- eprogressbar.lua branch-dense coverage: value/max/min 的 client_role 定向分支与全角色广播分支。
local lu = require("luaunit")
local context = require("src.ui.manager.context")
local EProgressbar = require("src.ui.manager.eprogressbar")
local support = require("test.support.ui_manager_nodes_support")

-- 原生 LuaUnit 迁移:describe 拍平为文件级 Test* 类,before_each/after_each 收成
-- setUp/tearDown,共享 local role_a/role_b 收成 self 字段,用例数与改写前一致(7 例)。

TestEProgressbar = {}

function TestEProgressbar:setUp()
  support.clear_context()
  self.role_a = support.make_role(1)
  self.role_b = support.make_role(2)
end

function TestEProgressbar:tearDown()
  support.clear_context()
end

function TestEProgressbar:test_init_defaults_transition_time_to_zero()
  local bar = EProgressbar:new(401, "bar")

  lu.assertEvalToTrue(bar.transition_time == 0.0, "new progressbar transition_time should default to 0.0")
end

function TestEProgressbar:test_value_targets_only_the_client_role_and_carries_transition_time()
  context.client_role = self.role_a
  support.install_roles({ self.role_a, self.role_b })
  local bar = EProgressbar:new(402, "bar")
  bar.transition_time = 0.5

  bar.value = 42

  local calls = support.calls_of(self.role_a, "set_progressbar_transition")
  lu.assertEvalToTrue(#calls == 1, "client role should receive set_progressbar_transition once")
  lu.assertEvalToTrue(calls[1].args[1] == 402, "host call should carry the eui node id")
  lu.assertEvalToTrue(calls[1].args[2] == 42, "host call should carry the new value")
  lu.assertEvalToTrue(calls[1].args[3] == 0.5, "host call should carry the transition time")
  lu.assertEvalToTrue(#self.role_b.calls == 0, "other roles should not receive the value update")
  lu.assertEvalToTrue(bar.value == 42, "value getter should report the stored value")
end

function TestEProgressbar:test_value_broadcasts_to_all_roles_when_no_client_role()
  support.install_roles({ self.role_a, self.role_b })
  local bar = EProgressbar:new(403, "bar")

  bar.value = 7

  for _, role in ipairs({ self.role_a, self.role_b }) do
    local calls = support.calls_of(role, "set_progressbar_transition")
    lu.assertEvalToTrue(#calls == 1 and calls[1].args[2] == 7, "every role should receive the value update")
    lu.assertEvalToTrue(calls[1].args[3] == 0.0, "every role should receive the default transition time")
  end
end

function TestEProgressbar:test_max_value_targets_only_the_client_role()
  context.client_role = self.role_a
  support.install_roles({ self.role_a, self.role_b })
  local bar = EProgressbar:new(404, "bar")

  bar.max_value = 100

  local calls = support.calls_of(self.role_a, "set_progressbar_max")
  lu.assertEvalToTrue(#calls == 1, "client role should receive set_progressbar_max once")
  lu.assertEvalToTrue(calls[1].args[1] == 404, "host call should carry the eui node id")
  lu.assertEvalToTrue(calls[1].args[2] == 100, "host call should carry the new max value")
  lu.assertEvalToTrue(#self.role_b.calls == 0, "other roles should not receive the max update")
  lu.assertEvalToTrue(bar.max_value == 100, "max_value getter should report the stored value")
end

function TestEProgressbar:test_max_value_broadcasts_to_all_roles_when_no_client_role()
  support.install_roles({ self.role_a, self.role_b })
  local bar = EProgressbar:new(405, "bar")

  bar.max_value = 60

  for _, role in ipairs({ self.role_a, self.role_b }) do
    local calls = support.calls_of(role, "set_progressbar_max")
    lu.assertEvalToTrue(#calls == 1 and calls[1].args[2] == 60, "every role should receive the max update")
  end
end

function TestEProgressbar:test_min_value_targets_only_the_client_role()
  context.client_role = self.role_a
  support.install_roles({ self.role_a, self.role_b })
  local bar = EProgressbar:new(406, "bar")

  bar.min_value = 5

  local calls = support.calls_of(self.role_a, "set_progressbar_min")
  lu.assertEvalToTrue(#calls == 1, "client role should receive set_progressbar_min once")
  lu.assertEvalToTrue(calls[1].args[1] == 406, "host call should carry the eui node id")
  lu.assertEvalToTrue(calls[1].args[2] == 5, "host call should carry the new min value")
  lu.assertEvalToTrue(#self.role_b.calls == 0, "other roles should not receive the min update")
  lu.assertEvalToTrue(bar.min_value == 5, "min_value getter should report the stored value")
end

function TestEProgressbar:test_min_value_broadcasts_to_all_roles_when_no_client_role()
  support.install_roles({ self.role_a, self.role_b })
  local bar = EProgressbar:new(407, "bar")

  bar.min_value = 1

  for _, role in ipairs({ self.role_a, self.role_b }) do
    local calls = support.calls_of(role, "set_progressbar_min")
    lu.assertEvalToTrue(#calls == 1 and calls[1].args[2] == 1, "every role should receive the min update")
  end
end


return TestEProgressbar

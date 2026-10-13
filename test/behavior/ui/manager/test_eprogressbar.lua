local luassert = assert
local context = require("src.ui.manager.context")
local EProgressbar = require("src.ui.manager.eprogressbar")
local support = require("test.support.ui_manager_nodes_support")

describe("TestEProgressbar", function()
  local role_a, role_b
  before_each(function()
    support.clear_context()
    role_a = support.make_role(1)
    role_b = support.make_role(2)
  end)
  after_each(function() support.clear_context() end)
  it("test_init_defaults_transition_time_to_zero", function()
    local bar = EProgressbar:new(401, "bar")
    luassert.truthy(bar.transition_time == 0.0, "new progressbar transition_time should default to 0.0")
  end)
  it("test_value_targets_only_the_client_role_and_carries_transition_time", function()
    context.client_role = role_a
    support.install_roles({ role_a, role_b })
    local bar = EProgressbar:new(402, "bar")
    bar.transition_time = 0.5
    bar.value = 42
    local calls = support.calls_of(role_a, "set_progressbar_transition")
    luassert.truthy(#calls == 1, "client role should receive set_progressbar_transition once")
    luassert.truthy(calls[1].args[1] == 402, "host call should carry the eui node id")
    luassert.truthy(calls[1].args[2] == 42, "host call should carry the new value")
    luassert.truthy(calls[1].args[3] == 0.5, "host call should carry the transition time")
    luassert.truthy(#role_b.calls == 0, "other roles should not receive the value update")
    luassert.truthy(bar.value == 42, "value getter should report the stored value")
  end)
  it("test_value_broadcasts_to_all_roles_when_no_client_role", function()
    support.install_roles({ role_a, role_b })
    local bar = EProgressbar:new(403, "bar")
    bar.value = 7
    for _, role in ipairs({ role_a, role_b }) do
      local calls = support.calls_of(role, "set_progressbar_transition")
      luassert.truthy(#calls == 1 and calls[1].args[2] == 7, "every role should receive the value update")
      luassert.truthy(calls[1].args[3] == 0.0, "every role should receive the default transition time")
    end
  end)
  it("test_max_value_targets_only_the_client_role", function()
    context.client_role = role_a
    support.install_roles({ role_a, role_b })
    local bar = EProgressbar:new(404, "bar")
    bar.max_value = 100
    local calls = support.calls_of(role_a, "set_progressbar_max")
    luassert.truthy(#calls == 1, "client role should receive set_progressbar_max once")
    luassert.truthy(calls[1].args[1] == 404, "host call should carry the eui node id")
    luassert.truthy(calls[1].args[2] == 100, "host call should carry the new max value")
    luassert.truthy(#role_b.calls == 0, "other roles should not receive the max update")
    luassert.truthy(bar.max_value == 100, "max_value getter should report the stored value")
  end)
  it("test_max_value_broadcasts_to_all_roles_when_no_client_role", function()
    support.install_roles({ role_a, role_b })
    local bar = EProgressbar:new(405, "bar")
    bar.max_value = 60
    for _, role in ipairs({ role_a, role_b }) do
      local calls = support.calls_of(role, "set_progressbar_max")
      luassert.truthy(#calls == 1 and calls[1].args[2] == 60, "every role should receive the max update")
    end
  end)
  it("test_min_value_targets_only_the_client_role", function()
    context.client_role = role_a
    support.install_roles({ role_a, role_b })
    local bar = EProgressbar:new(406, "bar")
    bar.min_value = 5
    local calls = support.calls_of(role_a, "set_progressbar_min")
    luassert.truthy(#calls == 1, "client role should receive set_progressbar_min once")
    luassert.truthy(calls[1].args[1] == 406, "host call should carry the eui node id")
    luassert.truthy(calls[1].args[2] == 5, "host call should carry the new min value")
    luassert.truthy(#role_b.calls == 0, "other roles should not receive the min update")
    luassert.truthy(bar.min_value == 5, "min_value getter should report the stored value")
  end)
  it("test_min_value_broadcasts_to_all_roles_when_no_client_role", function()
    support.install_roles({ role_a, role_b })
    local bar = EProgressbar:new(407, "bar")
    bar.min_value = 1
    for _, role in ipairs({ role_a, role_b }) do
      local calls = support.calls_of(role, "set_progressbar_min")
      luassert.truthy(#calls == 1 and calls[1].args[2] == 1, "every role should receive the min update")
    end
  end)
end)

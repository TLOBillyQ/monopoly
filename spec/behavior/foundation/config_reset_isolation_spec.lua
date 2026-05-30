local constants = require("src.config.content.constants")

describe("runtime.config_reset_isolation", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("mutation_case_changes_timeout", function()
    constants.action_timeout_seconds = 1
    assert(constants.action_timeout_seconds == 1,
      "mutation case should be able to override timeout")
  end)

  it("next_case_sees_default_timeout", function()
    assert(constants.action_timeout_seconds == 15,
      "reset hook should restore config defaults before the next case")
  end)
end)

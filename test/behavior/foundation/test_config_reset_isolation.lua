require("test.bootstrap").install_package_paths()
-- busted injects the extensible assertion object into each file environment.
-- luacheck: ignore 143
local luassert = assert
local constants = require("src.config.content.constants")

local _config_reset = require("test.support.config_reset")

describe("TestConfigResetIsolation", function()

  before_each(function()
    _config_reset.reset_all()
  end)

  it("test_mutation_case_changes_timeout", function()
    constants.action_timeout_seconds = 1
    luassert.is.equal(1, constants.action_timeout_seconds, "mutation case should be able to override timeout")
  end)

  it("test_next_case_sees_default_timeout", function()
    luassert.is.equal(15, constants.action_timeout_seconds, "reset hook should restore config defaults before the next case")
  end)


end)

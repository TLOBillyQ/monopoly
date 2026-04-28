local constants = require("src.config.content.constants")

local suite = {
  name = "runtime.config_reset_isolation",
  tests = {
    {
      name = "mutation_case_changes_timeout",
      run = function()
        constants.action_timeout_seconds = 1
        assert(constants.action_timeout_seconds == 1,
          "mutation case should be able to override timeout")
      end,
    },
    {
      name = "next_case_sees_default_timeout",
      run = function()
        assert(constants.action_timeout_seconds == 15,
          "reset hook should restore config defaults before the next case")
      end,
    },
  },
}

return suite

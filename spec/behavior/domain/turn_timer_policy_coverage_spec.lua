local logger = require("src.core.utils.logger")
local suite = require("suites.domain.turn_timer_policy_coverage")
local cases = suite.tests or suite
local label = suite.name or "domain.turn_timer_policy_coverage"

describe(label, function()
  for _, case in ipairs(cases) do
    it(case.name, function()
      logger.set_test_mode(false)
      case.run()
    end)
  end
end)

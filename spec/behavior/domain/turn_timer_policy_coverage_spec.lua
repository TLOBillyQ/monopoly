local logger = require("src.foundation.log.logger")
require("spec.behavior._shim").bind(_ENV, "suites.domain.turn_timer_policy_coverage", {
  wrap = function(run) return function() logger.set_test_mode(false); run() end end,
})

--- Old backend outputter; event TAP formatting is shared with genuine busted.
local M = require("packages.luaunit_runner.legacy_outputter")
M.tap_handler_factory = require("packages.test_runner.tap_handler").tap_handler_factory
return M

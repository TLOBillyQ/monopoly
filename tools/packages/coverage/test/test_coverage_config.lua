---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/packages/coverage/test/test_coverage_config.lua") end
require("test.bootstrap").install_package_paths()

local lu = require("luaunit")
local config = require("packages.coverage.coverage_config")

-- coverage_config 是 luacov 配置的唯一真源（收集侧
-- luaunit_runner `-c`、报告侧 coverage.lua、crap4lua luacov adapter 同读本表)。
-- 在此直接钉住口径值,防止误改。

TestCoverageConfig = {}

function TestCoverageConfig:test_returns_the_luacov_config_fields()
  lu.assertIsTable(config.include)
  lu.assertIsTable(config.exclude)
  lu.assertIsTable(config.includeuntestedfiles)
  lu.assertIs(config.statsfile, "build/luacov.stats.out")
  lu.assertIs(config.reportfile, "build/luacov.report.out")
  lu.assertFalse(config.deletestats)
  lu.assertFalse(config.runreport)
  lu.assertFalse(config.codefromstrings)
end

function TestCoverageConfig:test_keeps_the_six_tier_include_prefixes_unanchored()
  lu.assertEquals(config.include, {
    "src/foundation/", "src/rules/", "src/turn/",
    "src/state/", "src/player/", "src/computer/",
  })
end

TestCoverageConfig["test_pins_exclude_and_includeuntestedfiles口径"] = function(self)
  lu.assertEquals(config.exclude, {
    "src/app/", "src/host/", "src/ui/", "src/config/",
    "tests/", "test/", "tools/", "vendor/",
    "/usr/", "/%.luarocks/",
  })
  lu.assertEquals(config.includeuntestedfiles, {
    "src/foundation", "src/rules", "src/turn",
    "src/state", "src/player", "src/computer",
  })
end


return TestCoverageConfig

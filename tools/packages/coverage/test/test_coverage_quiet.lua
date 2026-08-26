---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/packages/coverage/test/test_coverage_quiet.lua") end
require("test.bootstrap").install_package_paths()

local lu = require("luaunit")
local coverage = require("packages.coverage.coverage")

-- 原生 LuaUnit 形态(旧 DSL 迁移时重构):两个 describe 拆成两个 Test* 类,
-- 原 _trace 组的 before_each/after_each 对应 setUp/tearDown(6 例,一一对应)。

TestCoverageQuietParseArgs = {}

function TestCoverageQuietParseArgs:test_recognizes_quiet_flag()
  local opts = coverage.parse_args({ "--quiet" })
  lu.assertTrue(opts.quiet)
end

function TestCoverageQuietParseArgs:test_defaults_quiet_to_false()
  local opts = coverage.parse_args({})
  lu.assertFalse(opts.quiet)
end

function TestCoverageQuietParseArgs:test_preserves_other_options_when_quiet_is_set()
  local opts = coverage.parse_args({
    "--quiet",
    "--out=tmp/cov.md",
    "--threshold=85",
    "--profiles=behavior,contract",
  })
  lu.assertTrue(opts.quiet)
  lu.assertIs(opts.out, "tmp/cov.md")
  lu.assertIs(opts.threshold, 85)
  lu.assertEquals(opts.profiles, { "behavior", "contract" })
end

TestCoverageQuietTrace = {}

function TestCoverageQuietTrace:setUp()
  self.captured = {}
  coverage._set_trace_sink_for_tests(function(msg)
    self.captured[#self.captured + 1] = tostring(msg)
  end)
end

function TestCoverageQuietTrace:tearDown()
  coverage._set_trace_sink_for_tests(nil)
end

function TestCoverageQuietTrace:test_emits_when_quiet_is_false()
  coverage._trace(false, "Running: luacov")
  lu.assertIs(#self.captured, 1)
  lu.assertIs(self.captured[1], "Running: luacov")
end

function TestCoverageQuietTrace:test_suppresses_when_quiet_is_true()
  coverage._trace(true, "Running: luacov")
  lu.assertIs(#self.captured, 0)
end

function TestCoverageQuietTrace:test_treats_nil_quiet_as_not_quiet_back_compat()
  coverage._trace(nil, "Running: luacov")
  lu.assertIs(#self.captured, 1)
end


return TestCoverageQuietParseArgs

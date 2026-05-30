---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/quality/coverage/spec/coverage_quiet_spec.lua") end
require("spec.bootstrap").install_package_paths()

local coverage = require("quality.coverage")

describe("coverage.parse_args", function()
  it("recognizes --quiet flag", function()
    local opts = coverage.parse_args({ "--quiet" })
    assert.is_true(opts.quiet)
  end)

  it("defaults quiet to false", function()
    local opts = coverage.parse_args({})
    assert.is_false(opts.quiet)
  end)

  it("preserves other options when --quiet is set", function()
    local opts = coverage.parse_args({
      "--quiet",
      "--out=tmp/cov.md",
      "--threshold=85",
      "--profiles=behavior,contract",
    })
    assert.is_true(opts.quiet)
    assert.are.equal("tmp/cov.md", opts.out)
    assert.are.equal(85, opts.threshold)
    assert.are.same({ "behavior", "contract" }, opts.profiles)
  end)
end)

describe("coverage._trace (happy-path stdout budget)", function()
  local captured

  before_each(function()
    captured = {}
    coverage._set_trace_sink_for_tests(function(msg)
      captured[#captured + 1] = tostring(msg)
    end)
  end)

  after_each(function()
    coverage._set_trace_sink_for_tests(nil)
  end)

  it("emits when quiet is false (default)", function()
    coverage._trace(false, "Running: luacov")
    assert.are.equal(1, #captured)
    assert.are.equal("Running: luacov", captured[1])
  end)

  it("suppresses when quiet is true", function()
    coverage._trace(true, "Running: luacov")
    assert.are.equal(0, #captured)
  end)

  it("treats nil quiet as not quiet (back-compat)", function()
    coverage._trace(nil, "Running: luacov")
    assert.are.equal(1, #captured)
  end)
end)

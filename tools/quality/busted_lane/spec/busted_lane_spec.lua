---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/quality/busted_lane/spec/busted_lane_spec.lua") end
require("spec.bootstrap").install_package_paths()

local busted_lane = require("quality.busted_lane")

local function _all_pass_tap()
  return table.concat({
    "ok 1 - first thing works",
    "ok 2 - second thing works",
    "ok 3 - third thing works",
    "1..3",
  }, "\n") .. "\n"
end

local function _one_fail_tap()
  return table.concat({
    "ok 1 - first thing works",
    "not ok 2 - busted thing fails",
    "# Failure message: boom: expected 3 got 2",
    "ok 3 - third thing works",
    "1..3",
  }, "\n") .. "\n"
end

describe("busted_lane.parse_args", function()
  it("requires --profile", function()
    local opts, err = busted_lane.parse_args({})
    assert.is_nil(opts)
    assert.is_truthy(tostring(err):find("missing --profile", 1, true))
  end)

  it("parses --profile", function()
    local opts = busted_lane.parse_args({ "--profile", "contract" })
    assert.are.equal("contract", opts.profile)
    assert.is_false(opts.verbose)
  end)

  it("parses --verbose alongside --profile", function()
    local opts = busted_lane.parse_args({ "--profile", "guards", "--verbose" })
    assert.are.equal("guards", opts.profile)
    assert.is_true(opts.verbose)
  end)

  it("parses --busted-bin", function()
    local opts = busted_lane.parse_args({ "--profile", "contract", "--busted-bin", "custom-busted" })
    assert.are.equal("contract", opts.profile)
    assert.are.equal("custom-busted", opts.busted_bin)
  end)
end)

describe("busted_lane.compress_tap", function()
  it("collapses all-pass TAP to a single 'N passed' line", function()
    local out, passed, failed = busted_lane.compress_tap(_all_pass_tap())
    assert.are.equal("3 passed\n", out)
    assert.are.equal(3, passed)
    assert.are.equal(0, failed)
  end)

  it("keeps not-ok lines and trailing diagnostics on failure", function()
    local out, passed, failed = busted_lane.compress_tap(_one_fail_tap())
    assert.are.equal(2, passed)
    assert.are.equal(1, failed)
    assert.is_truthy(out:find("not ok 2 %- busted thing fails"),
      "failing line must be preserved: " .. out)
    assert.is_truthy(out:find("Failure message: boom: expected 3 got 2", 1, true),
      "diagnostic envelope must be preserved: " .. out)
    assert.is_truthy(out:find("2 passed, 1 failed", 1, true),
      "summary line must be present: " .. out)
  end)

  it("drops the TAP plan line (1..N) on both success and failure", function()
    local pass_out = busted_lane.compress_tap(_all_pass_tap())
    local fail_out = busted_lane.compress_tap(_one_fail_tap())
    assert.is_nil(pass_out:find("1..3", 1, true))
    assert.is_nil(fail_out:find("1..3", 1, true))
  end)

  it("happy-path output is at most one line", function()
    local out = busted_lane.compress_tap(_all_pass_tap())
    local newline_count = 0
    for _ in out:gmatch("\n") do newline_count = newline_count + 1 end
    assert.are.equal(1, newline_count, "happy path should be exactly one terminated line: " .. out)
  end)

  it("treats nil / empty input as zero passes", function()
    local out, passed, failed = busted_lane.compress_tap(nil)
    assert.are.equal("0 passed\n", out)
    assert.are.equal(0, passed)
    assert.are.equal(0, failed)
  end)
end)

describe("busted_lane.run", function()
  it("starts busted through argv with --busted-bin taking priority", function()
    local captured
    local result = busted_lane.run({
      profile = "contract",
      busted_bin = "custom-busted",
      run_command = function(command)
        captured = command
        return { ok = true, code = 0, output = _all_pass_tap() }
      end,
    })

    assert.are.same({
      "custom-busted",
      "--output=TAP",
      "--run",
      "contract",
    }, captured)
    assert.are.equal(0, result.code)
    assert.are.equal("3 passed\n", result.stdout)
  end)
end)

---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/quality/verify_full/spec/verify_full_spec.lua") end
require("spec.bootstrap").install_package_paths()

local verify_full = require("quality.verify_full")

local function _count_lines(text)
  local count = 0
  for _ in (tostring(text or "") .. "\n"):gmatch("[^\n]*\n") do
    count = count + 1
  end
  return count - 1
end

local function _all_pass_results()
  return {
    results = {
      { label = "contract", ok = true, elapsed = 5, output = "ok 1\nok 2\n1..2\n" },
      { label = "guards", ok = true, elapsed = 3, output = "ok 1\n1..1\n" },
      { label = "arch", ok = true, elapsed = 1, output = "arch ok\n" },
    },
    skipped = {},
    total_elapsed = 10,
  }
end

local function _one_fail_results()
  return {
    results = {
      { label = "contract", ok = true, elapsed = 5, output = "ok 1\n1..1\n" },
      {
        label = "guards",
        ok = false,
        elapsed = 4,
        output = "ok 1\nnot ok 2 - busted: guard check\n# Failure message: boom\n1..2\n",
      },
    },
    skipped = {},
    total_elapsed = 9,
  }
end

describe("verify_full.build_output (compressed by default)", function()
  it("happy path emits at most 3 lines", function()
    local input = _all_pass_results()
    local out = verify_full.build_output(input)
    local lines = _count_lines(out.stdout)
    assert.is_true(lines <= 3, "expected <= 3 lines on happy path, got " .. lines .. ":\n" .. out.stdout)
    assert.are.equal(0, out.exit_code)
  end)

  it("happy path includes aggregate summary with passed/failed/skipped counts", function()
    local input = _all_pass_results()
    local out = verify_full.build_output(input)
    assert.is_truthy(out.stdout:find("passed=3", 1, true), "summary should report passed=3: " .. out.stdout)
    assert.is_truthy(out.stdout:find("failed=0", 1, true))
    assert.is_truthy(out.stdout:find("skipped=0", 1, true))
    assert.is_truthy(out.stdout:find("PASS", 1, true))
  end)

  it("happy path suppresses per-lane stdout", function()
    local input = _all_pass_results()
    local out = verify_full.build_output(input)
    assert.is_nil(out.stdout:find("ok 1", 1, true), "lane stdout should be suppressed on success")
    assert.is_nil(out.stdout:find("arch ok", 1, true), "lane stdout should be suppressed on success")
  end)

  it("failure path emits failing lane stdout verbatim", function()
    local input = _one_fail_results()
    local out = verify_full.build_output(input)
    assert.are.equal(1, out.exit_code)
    assert.is_truthy(out.stdout:find("not ok 2 %- busted: guard check"),
      "failing lane stdout must be preserved: " .. out.stdout)
    assert.is_truthy(out.stdout:find("Failure message: boom", 1, true),
      "failing diagnostic must be preserved")
  end)

  it("failure path does not include passing lane stdout", function()
    local input = _one_fail_results()
    local out = verify_full.build_output(input)
    assert.is_nil(out.stdout:find("ok 1\n1..1", 1, true),
      "passing lane stdout should still be suppressed on failure")
  end)

  it("skipped lanes appear in summary", function()
    local input = _all_pass_results()
    input.skipped = { "lint", "coverage" }
    local out = verify_full.build_output(input)
    assert.is_truthy(out.stdout:find("skipped=2", 1, true))
    assert.is_truthy(out.stdout:find("skipped: lint, coverage", 1, true))
  end)
end)

describe("verify_full.build_output (--verbose)", function()
  it("verbose preserves all lane stdout on success", function()
    local input = _all_pass_results()
    input.verbose = true
    local out = verify_full.build_output(input)
    assert.is_truthy(out.stdout:find("arch ok", 1, true), "verbose must include lane stdout")
    assert.is_truthy(out.stdout:find("ok 1", 1, true), "verbose must include lane stdout")
  end)

  it("verbose preserves all lane stdout on failure", function()
    local input = _one_fail_results()
    input.verbose = true
    local out = verify_full.build_output(input)
    assert.is_truthy(out.stdout:find("not ok 2", 1, true))
    assert.is_truthy(out.stdout:find("ok 1\n1..1", 1, true),
      "verbose must include passing lane stdout too: " .. out.stdout)
  end)

  it("verbose includes per-step PASS/FAIL trace lines", function()
    local input = _all_pass_results()
    input.verbose = true
    local out = verify_full.build_output(input)
    assert.is_truthy(out.stdout:find("PASS contract", 1, true),
      "verbose must include per-step trace: " .. out.stdout)
  end)
end)

---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/packages/spec_lane/test/test_spec_evidence.lua") end
require("test.bootstrap").install_package_paths()

local check = require("luassert")
local evidence = require("packages.spec_lane.spec_evidence")
local env_lib = require("foundation.env")
local fs_lib = require("foundation.fs")

local COUNTS_A = "# COUNTS: files=2 cases=3 passed=3 failed=0 errors=0\n"
local COUNTS_B = "# COUNTS: files=1 cases=2 passed=1 failed=1 errors=0\n"

describe("spec lane evidence", function()

it("parses the runner counts line even when output glued to its prefix", function()
  local counts = evidence.parse_counts("ok 1 - a\npartial-without-newline" .. COUNTS_A)
  check.equal(2, counts.files)
  check.equal(3, counts.cases)
  check.equal(3, counts.passed)
  check.equal(0, counts.failed)
  check.equal(0, counts.errors)
end)

it("returns nil when the raw output carries no counts line", function()
  check.is_nil(evidence.parse_counts("ok 1 - a\n1..1\n"))
end)

it("formats counts back into the runner line", function()
  check.equal("# COUNTS: files=2 cases=3 passed=3 failed=0 errors=0",
    evidence.format_counts({ files = 2, cases = 3, passed = 3, failed = 0, errors = 0 }))
end)

it("tallies numbered ok and unnumbered not ok tap lines", function()
  local tally = evidence.tally_tap("ok 1 - a\nnot ok 2 - b\nnot ok - failed to load x\n1..2\n")
  check.equal(1, tally.passed)
  check.equal(2, tally.failed)
end)

it("aggregates per lane counts instead of relying on tap lines", function()
  local aggregated = evidence.aggregate({
    { label = "tooling_w1", raw = "ok 1 - a\nok 2 - b\nok 3 - c\n" .. COUNTS_A },
    -- 第二条 lane 的 ok 行被 stdout/stderr 合流串流吃掉一条(#130),COUNTS 仍在。
    { label = "tooling_w2", raw = "k 1 - a\nnot ok 2 - b\n" .. COUNTS_B },
  })
  check.equal(3, aggregated.counts.files)
  check.equal(5, aggregated.counts.cases)
  check.equal(4, aggregated.counts.passed)
  check.equal(1, aggregated.counts.failed)
  check.equal(0, aggregated.counts.errors)
  check.equal(3, aggregated.tally.passed)
  check.equal(1, aggregated.tally.failed)
  check.same({}, aggregated.missing)
end)

it("reports which lanes lack counts instead of inventing a total", function()
  local aggregated = evidence.aggregate({
    { label = "tooling_w1", raw = "ok 1 - a\n" .. COUNTS_A },
    { label = "tooling_w2", raw = "runner crashed\n" },
  })
  check.is_nil(aggregated.counts)
  check.same({ "tooling_w2" }, aggregated.missing)
end)

it("explains a tap versus counts mismatch", function()
  local line = evidence.mismatch_line(
    { files = 1, cases = 2, passed = 2, failed = 0, errors = 0 }, { passed = 1, failed = 0 })
  check.matches("COUNT MISMATCH", line, 1, true)
  check.matches("tap passed=1 failed=0", line, 1, true)
  check.matches("counts passed=2 failed=0 errors=0", line, 1, true)
end)

it("has no mismatch when both sides agree", function()
  check.is_nil(evidence.mismatch_line(
    { files = 1, cases = 2, passed = 2, failed = 0, errors = 0 }, { passed = 2, failed = 0 }))
end)

local function _with_dir(fn)
  local dir = env_lib.make_temp_path("spec_evidence_spec", "")
  fs_lib.remove_path(dir)
  local ok, err = xpcall(function() fn(dir) end, debug.traceback)
  fs_lib.remove_path(dir)
  if not ok then error(err) end
end

it("writes raw lane output and recomputes the summary from it", function()
  _with_dir(function(dir)
    check.is_true(evidence.write(dir, {
      profile = "tooling",
      mode = "sharded",
      exit_code = 0,
      lanes = {
        { label = "tooling_w1", raw = "ok 1 - a\nok 2 - b\nok 3 - c\n" .. COUNTS_A, files = { "a.lua", "b.lua" } },
        { label = "tooling_w2", raw = "ok 1 - d\n" .. COUNTS_B:gsub("passed=1 failed=1", "passed=2 failed=0") },
      },
    }))
    check.is_true(fs_lib.path_exists(dir .. "/tooling_w1.tap"))
    check.is_true(fs_lib.path_exists(dir .. "/tooling_w2.tap"))
    check.matches("a.lua", fs_lib.read_raw(dir .. "/tooling_w1.files"), 1, true)

    local result = evidence.recount(dir)
    check.is_table(result)
    check.is_true(result.match, result.detail)
    check.equal(5, result.counts.cases)
    check.equal(5, result.counts.passed)
    check.equal(4, result.tally.passed)
  end)
end)

it("recount flags evidence that no longer matches its summary", function()
  _with_dir(function(dir)
    check.is_true(evidence.write(dir, {
      profile = "tooling", mode = "serial", exit_code = 0,
      lanes = { { label = "tooling", raw = "ok 1 - a\nok 2 - b\nok 3 - c\n" .. COUNTS_A } },
    }))
    local handle = assert(io.open(dir .. "/tooling.tap", "ab"))
    handle:write("ok 4 - injected later\n")
    handle:close()
    local result = evidence.recount(dir)
    check.is_false(result.match)
    check.matches("tap", result.detail, 1, true)
  end)
end)

it("recount rejects evidence whose raw output has no counts", function()
  _with_dir(function(dir)
    check.is_true(evidence.write(dir, {
      profile = "tooling", mode = "serial", exit_code = 0,
      lanes = { { label = "tooling", raw = "ok 1 - a\n1..1\n" } },
    }))
    local result = evidence.recount(dir)
    check.is_false(result.match)
    check.matches("missing COUNTS", result.detail, 1, true)
  end)
end)

it("recount rejects a directory without evidence", function()
  _with_dir(function(dir)
    local result, err = evidence.recount(dir)
    check.is_nil(result)
    check.matches("summary", tostring(err), 1, true)
  end)
end)

end)

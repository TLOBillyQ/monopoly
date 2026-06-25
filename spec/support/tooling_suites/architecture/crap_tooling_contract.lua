local bootstrap = require("spec.bootstrap")
local common = require("shared.lib.common")
local crap = require("quality.crap")
local adapter = require("quality.crap.adapter")
local gate = require("quality.crap.gate")
local package_path_helper = require("shared.package_path_helper")

bootstrap.install_package_paths()

local function _assert_eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. "\nexpected: " .. tostring(expected) .. "\nactual: " .. tostring(actual))
  end
end

local function _assert_contains(text, expected, message)
  if tostring(text or ""):find(expected, 1, true) == nil then
    error((message or "missing expected text") .. "\nexpected: " .. tostring(expected) .. "\nactual: " .. tostring(text))
  end
end

local function _assert_not_contains(text, unexpected, message)
  if tostring(text or ""):find(unexpected, 1, true) ~= nil then
    error((message or "unexpected text found") .. "\nunexpected: " .. tostring(unexpected) .. "\nactual: " .. tostring(text))
  end
end

local function _buffer()
  local parts = {}
  return {
    write = function(_, ...)
      local count = select("#", ...)
      for index = 1, count do
        parts[#parts + 1] = tostring(select(index, ...))
      end
    end,
    text = function()
      return table.concat(parts)
    end,
  }
end

local function _test_env_preserves_monopoly_path_convention()
  local env = crap.env
  assert(env.tmp_root:find("monopoly_crap", 1, true) ~= nil,
    "default tmp root should preserve monopoly-specific directory name")
  assert(env.default_config:find("tools/quality/crap/config.lua", 1, true) ~= nil,
    "default config should point at monopoly wrapper config")
end

local function _test_install_monopoly_package_paths_only_installs_canonical_repo_patterns()
  local original_package_path = package.path
  package.path = "/tmp/monopoly_package_path_sentinel.lua"

  local ok, err = pcall(function()
    package_path_helper.install_monopoly_package_paths({
      repo_root = "/repo",
      arch_view_root = "/repo/.swarmforge/tools/arch_view@abc",
    })
    _assert_contains(package.path, "/repo/tools/?.lua", "helper should keep canonical repo tool paths")
    _assert_contains(package.path, "/repo/spec/?.lua", "helper should keep canonical spec paths")
    _assert_not_contains(package.path, "/repo/.swarmforge/tools/arch_view@abc",
      "package helper should not install tool cache paths")
  end)

  package.path = original_package_path
  if not ok then
    error(err)
  end
end

local function _test_adapter_resolves_behavior_and_contract_lanes()
  local behavior_suites = adapter.resolve_suites("behavior")
  assert(#behavior_suites > 0, "behavior lane should expose behavior suites")

  local contract_suites = adapter.resolve_suites("contract")
  assert(#contract_suites > 0, "contract lane should expose contract suites")
  assert(type(adapter.run) == "function", "adapter should expose the standalone run contract")
  _assert_eq(adapter.debug_api, debug, "adapter should expose debug api for coverage hooks")
end

local function _test_cli_report_generates_report_json()
  local out = _buffer()
  local err = _buffer()
  local tmp_out = common.make_temp_path("crap_contract_report", ".json")
  local ok = crap.run({
    "report",
    "--out", tmp_out,
    "--lane", "behavior",
    "--top", "3",
  }, {
    stdout = out,
    stderr = err,
  })

  assert(ok == true, "cli report should return true: " .. err:text())
  _assert_contains(out:text(), "crap report json:", "report stdout should print report path")
  assert(common.path_exists(tmp_out), "report json should exist at output path")
  local content = common.read_file(tmp_out)
  _assert_contains(content, '"functions"', "report json should contain functions array")
  _assert_contains(content, '"crap_score"', "report json should contain crap_score field")
  _assert_contains(content, '"complexity"', "report json should contain complexity field")
  _assert_contains(content, '"hit_line_count"', "report json should contain hit_line_count")
  _assert_contains(content, '"executable_line_count"', "report json should contain executable_line_count")
  common.remove_path(tmp_out)
end

local function _test_cli_collect_writes_coverage_json()
  local out = _buffer()
  local err = _buffer()
  local tmp_out = common.make_temp_path("crap_contract_collect", ".json")
  local ok = crap.run({
    "collect",
    "--out", tmp_out,
    "--lane", "behavior",
  }, {
    stdout = out,
    stderr = err,
  })

  assert(ok == true, "collect should return true: " .. err:text())
  _assert_contains(out:text(), "crap collect json:", "collect stdout should print collect path")
  assert(common.path_exists(tmp_out), "collect json should exist at output path")
  local content = common.read_file(tmp_out)
  _assert_contains(content, '"coverage_result"', "collect json should contain coverage_result")
  common.remove_path(tmp_out)
end

local function _test_cli_summary_out_prints_resolved_json_path()
  local in_json = common.make_temp_path("crap_summary_input", ".json")
  local ok_write, write_err = common.write_file(in_json, '{"functions":[]}')
  if not ok_write then
    error(write_err)
  end

  local out = _buffer()
  local summary_out = common.make_temp_path("crap_summary_output", ".json")
  local ok = crap.run({
    "summary",
    "--in-json", in_json,
    "--out", summary_out,
  }, {
    stdout = out,
    stderr = _buffer(),
  })
  common.remove_path(in_json)

  assert(ok == true, "summary should return true")
  _assert_contains(out:text(), "crap summary json:",
    "summary stdout should print resolved summary json path")
  common.remove_path(summary_out)
end

local function _test_no_go_binary_references_in_reference_cli()
  local cli_path = common.join_path(crap.env.tool_root, "lib/crap4lua/cli.lua")
  local content = common.read_file(cli_path)
  _assert_not_contains(content, "ensure_" .. "binary", "reference cli should not reference removed binary resolver")
  _assert_not_contains(content, "_launcher_" .. "source", "reference cli should not reference removed launcher")
  _assert_not_contains(content, "go " .. "build", "reference cli should not reference removed build command")
end

local function _test_gate_ceiling_is_complexity_aware()
  -- cx below base keeps the flat base bar.
  _assert_eq(gate.ceiling(3, 7), 7, "cx=3 should keep base ceiling 7")
  _assert_eq(gate.ceiling(6, 7), 7, "cx=6 should keep base ceiling 7")
  -- cx at/above base accepts the irreducible floor (cx) plus one.
  _assert_eq(gate.ceiling(7, 7), 8, "cx=7 ceiling should be cx+1=8")
  _assert_eq(gate.ceiling(8, 7), 9, "cx=8 ceiling should be cx+1=9")
end

local function _test_gate_is_violation_accepts_high_complexity_floor()
  -- cx=8 at its 100% floor (crap=8.0) passes; a coverage gap to 9.0 fails.
  assert(gate.is_violation({ complexity = 8, crap = 8.0 }, 7) == false,
    "cx=8 at floor 8.0 should not violate")
  assert(gate.is_violation({ complexity = 8, crap = 9.0 }, 7) == true,
    "cx=8 at 9.0 should violate (coverage gap above floor)")
  -- cx<=6 keeps the legacy <7 bar.
  assert(gate.is_violation({ complexity = 6, crap = 6.5 }, 7) == false,
    "cx=6 at 6.5 should not violate (below 7)")
  assert(gate.is_violation({ complexity = 6, crap = 7.0 }, 7) == true,
    "cx=6 at 7.0 should violate (legacy bar)")
end

local function _test_gate_violations_group_by_file()
  local by_file = gate.violations_by_file({
    { source_path = "src/a.lua", name = "f1", complexity = 8, crap = 9.0 },
    { source_path = "src/a.lua", name = "f2", complexity = 5, crap = 10.0 },
    { source_path = "src/a.lua", name = "ok", complexity = 8, crap = 8.0 }, -- floor, not a violation
    { source_path = "src/b.lua", name = "f3", complexity = 3, crap = 7.2 },
  }, 7)
  _assert_eq(by_file["src/a.lua"].count, 2, "src/a.lua should have 2 violations")
  _assert_eq(by_file["src/b.lua"].count, 1, "src/b.lua should have 1 violation")
  _assert_eq(gate.total_violations(by_file), 3, "total violations should be 3")
end

local function _test_gate_evaluate_ratchets_against_baseline()
  local by_file = {
    ["src/a.lua"] = { count = 2, functions = { { name = "f", crap = 9.0, complexity = 8 } } },
    ["src/b.lua"] = { count = 1, functions = { { name = "g", crap = 7.2, complexity = 3 } } },
  }
  -- Within baseline: no regressions.
  local none = gate.evaluate(by_file, { files = { ["src/a.lua"] = 2, ["src/b.lua"] = 1 } })
  _assert_eq(#none, 0, "counts within baseline should yield no regressions")
  -- Exceeds baseline on one file: a single regression reported.
  local some = gate.evaluate(by_file, { files = { ["src/a.lua"] = 1, ["src/b.lua"] = 1 } })
  _assert_eq(#some, 1, "exceeding baseline should yield one regression")
  _assert_eq(some[1].source_path, "src/a.lua", "regression should name the exceeding file")
  _assert_eq(some[1].allowed, 1, "regression should report the baseline budget")
  -- Unlisted file with violations is treated as budget 0.
  local fresh = gate.evaluate(by_file, { files = {} })
  _assert_eq(#fresh, 2, "files absent from baseline default to budget 0")
end

local function _test_gate_render_baseline_round_trips()
  local source = gate.render_baseline(7, {
    ["src/b.lua"] = { count = 1 },
    ["src/a.lua"] = { count = 2 },
  })
  _assert_contains(source, "base_threshold = 7", "baseline should record the base threshold")
  _assert_contains(source, '["src/a.lua"] = 2', "baseline should record per-file counts")
  local chunk = assert(load(source), "rendered baseline should be loadable Lua")
  local data = chunk()
  _assert_eq(data.base_threshold, 7, "loaded baseline should expose base_threshold")
  _assert_eq(data.files["src/a.lua"], 2, "loaded baseline should expose per-file counts")
end

return {
  name = "crap_tooling_contract",
  tests = {
    { name = "env_preserves_monopoly_paths", run = _test_env_preserves_monopoly_path_convention },
    { name = "install_monopoly_package_paths_only_installs_canonical_repo_patterns", run = _test_install_monopoly_package_paths_only_installs_canonical_repo_patterns },
    { name = "adapter_resolves_behavior_and_contract_lanes", run = _test_adapter_resolves_behavior_and_contract_lanes },
    { name = "cli_report_generates_report_json", run = _test_cli_report_generates_report_json },
    { name = "cli_collect_writes_coverage_json", run = _test_cli_collect_writes_coverage_json },
    { name = "cli_summary_out_prints_resolved_json_path", run = _test_cli_summary_out_prints_resolved_json_path },
    { name = "no_go_binary_references_in_reference_cli", run = _test_no_go_binary_references_in_reference_cli },
    { name = "gate_ceiling_is_complexity_aware", run = _test_gate_ceiling_is_complexity_aware },
    { name = "gate_is_violation_accepts_high_complexity_floor", run = _test_gate_is_violation_accepts_high_complexity_floor },
    { name = "gate_violations_group_by_file", run = _test_gate_violations_group_by_file },
    { name = "gate_evaluate_ratchets_against_baseline", run = _test_gate_evaluate_ratchets_against_baseline },
    { name = "gate_render_baseline_round_trips", run = _test_gate_render_baseline_round_trips },
  },
}

local bootstrap = require("spec.bootstrap")
local common = require("shared.lib.common")
local crap = require("quality.crap")
local adapter = require("quality.crap.adapter")
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
      arch_view_root = "/repo/vendor/arch_view",
    })
    _assert_contains(package.path, "/repo/tools/?.lua", "helper should keep canonical repo tool paths")
    _assert_contains(package.path, "/repo/spec/?.lua", "helper should keep canonical spec paths")
    _assert_not_contains(package.path, "/repo/vendor/arch_view/" .. "?.lua",
      "helper should not install arch_view compatibility paths")
    _assert_not_contains(package.path, "/repo/vendor/arch_view/" .. "?/?.lua",
      "helper should not install arch_view nested compatibility paths")
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

local function _test_no_go_binary_references_in_vendor_cli()
  local cli_path = crap.env.cwd .. "/vendor/crap4lua/lib/crap4lua/cli.lua"
  local content = common.read_file(cli_path)
  _assert_not_contains(content, "ensure_" .. "binary", "vendor cli should not reference removed binary resolver")
  _assert_not_contains(content, "_launcher_" .. "source", "vendor cli should not reference removed launcher")
  _assert_not_contains(content, "go " .. "build", "vendor cli should not reference removed build command")
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
    { name = "no_go_binary_references_in_vendor_cli", run = _test_no_go_binary_references_in_vendor_cli },
  },
}

local bootstrap = require("tests.bootstrap")
local crap = require("quality.crap")
local adapter = require("quality.crap.adapter")

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

local function _test_default_tmp_root_preserves_monopoly_path_convention()
  local override = "/tmp/monopoly_crap_override"
  _assert_eq(crap.resolve_cli_path("/repo", "tmp/demo.json"), crap.default_tmp_root() .. "/demo.json",
    "tmp alias should resolve relative to default tmp root")
  assert(crap.default_tmp_root():find("monopoly_crap", 1, true) ~= nil,
    "default tmp root should preserve monopoly-specific directory name")
  assert(crap.resolve_cli_path("/repo", override) == override,
    "absolute paths should bypass tmp alias handling")
end

local function _test_adapter_resolves_behavior_and_contract_lanes()
  local behavior_suites, behavior_mode = adapter.resolve_suites("behavior")
  assert(#behavior_suites > 0, "behavior lane should expose behavior suites")
  assert(behavior_mode == "dev" or behavior_mode == "release_trimmed",
    "behavior lane should resolve to a concrete regression mode")

  local contract_suites, contract_mode = adapter.resolve_suites("contract")
  assert(#contract_suites > 0, "contract lane should expose contract suites")
  _assert_eq(contract_mode, "dev", "contract lane should always use dev mode")
  assert(type(adapter.run) == "function", "adapter should expose the standalone run contract")
  _assert_eq(adapter.debug_api, debug, "adapter should expose debug api for coverage hooks")
end

local function _test_cli_report_translates_to_vendor_response_json()
  local captured_command = nil
  local ok = crap.run({
    "report",
    "--out", "tmp/crap_report.json",
    "--lane", "behavior",
    "--top", "25",
  }, {
    workspace_root = "/repo",
    ensure_binary = function(path)
      return path, nil
    end,
    run_command = function(command)
      captured_command = command
      return { ok = true, code = 0, output = "report ok\n" }
    end,
  })

  assert(ok == true, "cli report should return true")
  _assert_eq(captured_command[2], "report", "wrapper should dispatch vendor report command")
  _assert_contains(table.concat(captured_command, " "), "--config " .. crap.default_config_path(),
    "wrapper should inject default config path")
  _assert_contains(table.concat(captured_command, " "), "--response-json " .. crap.default_tmp_root() .. "/crap_report.json",
    "wrapper should translate --out into vendor --response-json")
  _assert_contains(table.concat(captured_command, " "), "--lane behavior",
    "wrapper should preserve lane flags")
  _assert_contains(table.concat(captured_command, " "), "--top 25",
    "wrapper should preserve non-path report flags")
end

local function _test_cli_viewer_resolves_tmp_alias_before_vendor_call()
  local captured_command = nil
  local ok = crap.run({
    "viewer",
    "--in-json", "tmp/crap_report.json",
    "--out-dir", "tmp/crap_view",
    "--open",
  }, {
    workspace_root = "/repo",
    ensure_binary = function(path)
      return path, nil
    end,
    run_command = function(command)
      captured_command = command
      return { ok = true, code = 0, output = "viewer ok\n" }
    end,
  })

  assert(ok == true, "cli viewer should return true")
  _assert_eq(captured_command[2], "viewer", "wrapper should dispatch vendor viewer command")
  _assert_contains(table.concat(captured_command, " "), "--in-json " .. crap.default_tmp_root() .. "/crap_report.json",
    "tmp input json should resolve under Monopoly tmp root")
  _assert_contains(table.concat(captured_command, " "), "--out-dir " .. crap.default_tmp_root() .. "/crap_view",
    "tmp output dir should resolve under Monopoly tmp root")
end

local function _test_cli_without_args_defaults_to_report_then_opened_viewer()
  local commands = {}
  local ok = crap.run({}, {
    workspace_root = "/repo",
    ensure_binary = function(path)
      return path, nil
    end,
    run_command = function(command)
      commands[#commands + 1] = command
      return { ok = true, code = 0, output = "" }
    end,
  })

  assert(ok == true, "bare cli should return true")
  _assert_eq(#commands, 2, "bare cli should run report and viewer")
  _assert_eq(commands[1][2], "report", "bare cli should generate a report first")
  _assert_eq(commands[2][2], "viewer", "bare cli should open the generated viewer second")
  _assert_contains(table.concat(commands[1], " "), "--response-json " .. crap.default_tmp_root() .. "/crap_report.json",
    "bare cli should generate the default tmp report json")
  _assert_contains(table.concat(commands[2], " "), "--in-json " .. crap.default_tmp_root() .. "/crap_report.json",
    "viewer should consume the generated report json")
  _assert_contains(table.concat(commands[2], " "), "--out-dir " .. crap.default_tmp_root() .. "/crap_view",
    "viewer should write to the default tmp viewer dir")
  _assert_contains(table.concat(commands[2], " "), "--open",
    "bare cli should auto-open the viewer")
end

local function _test_default_config_path_points_at_monopoly_wrapper_config()
  assert(crap.default_config_path():find("scripts/quality/crap/config.lua", 1, true) ~= nil,
    "wrapper should expose its default config path")
end

return {
  name = "architecture.crap_contract",
  tests = {
    { name = "default_tmp_root_preserves_monopoly_paths", run = _test_default_tmp_root_preserves_monopoly_path_convention },
    { name = "adapter_resolves_behavior_and_contract_lanes", run = _test_adapter_resolves_behavior_and_contract_lanes },
    { name = "cli_report_translates_to_vendor_response_json", run = _test_cli_report_translates_to_vendor_response_json },
    { name = "cli_viewer_resolves_tmp_alias_before_vendor_call", run = _test_cli_viewer_resolves_tmp_alias_before_vendor_call },
    { name = "cli_without_args_defaults_to_report_then_opened_viewer", run = _test_cli_without_args_defaults_to_report_then_opened_viewer },
    { name = "default_config_path_points_at_monopoly_wrapper_config", run = _test_default_config_path_points_at_monopoly_wrapper_config },
  },
}

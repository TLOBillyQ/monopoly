local bootstrap = require("spec.bootstrap")
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

local function _test_default_tmp_root_preserves_monopoly_path_convention()
  local override = "/tmp/monopoly_crap_override"
  _assert_eq(crap.resolve_cli_path("/repo", "tmp/demo.json"), crap.default_tmp_root() .. "/demo.json",
    "tmp alias should resolve relative to default tmp root")
  assert(crap.default_tmp_root():find("monopoly_crap", 1, true) ~= nil,
    "default tmp root should preserve monopoly-specific directory name")
  assert(crap.resolve_cli_path("/repo", override) == override,
    "absolute paths should bypass tmp alias handling")
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
    _assert_not_contains(package.path, "/repo/vendor/arch_view/?.lua", "helper should not install arch_view compatibility paths")
    _assert_not_contains(package.path, "/repo/vendor/arch_view/?/?.lua", "helper should not install arch_view nested compatibility paths")
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

local function _test_cli_report_prepares_request_then_calls_vendor_cli()
  local captured_request = nil
  local captured_command = nil
  local ensured_report_dir = nil
  local ok = crap.run({
    "report",
    "--out", "tmp/crap_report.json",
    "--lane", "behavior",
    "--top", "25",
    "--strict-tests",
  }, {
    workspace_root = "/repo",
    ensure_binary = function(path)
      return path, nil
    end,
    prepare_report_request = function(options)
      captured_request = options
      return "/tmp/crap-request.json"
    end,
    run_command = function(command)
      captured_command = command
      return { ok = true, code = 0, output = "report ok\n" }
    end,
    ensure_parent_dir = function(path)
      ensured_report_dir = path
      return true
    end,
  })

  assert(ok == true, "cli report should return true")
  _assert_eq(ensured_report_dir, crap.default_tmp_root() .. "/crap_report.json", "report should ensure the response json parent dir")
  _assert_eq(captured_request.config, crap.default_config_path(), "wrapper should inject default config path")
  _assert_eq(captured_request.out, crap.default_tmp_root() .. "/crap_report.json", "wrapper should resolve tmp output path")
  _assert_eq(captured_request.top, 25, "wrapper should preserve top option")
  _assert_eq(captured_request.strict_tests, true, "wrapper should preserve strict-tests")
  _assert_eq(captured_request.lanes[1], "behavior", "wrapper should preserve lane list")
  _assert_eq(captured_command[2], "report", "wrapper should dispatch vendor report command")
  _assert_contains(table.concat(captured_command, " "), "--request-json /tmp/crap-request.json",
    "wrapper should pass prepared request json to vendor CLI")
  _assert_contains(table.concat(captured_command, " "), "--response-json " .. crap.default_tmp_root() .. "/crap_report.json",
    "wrapper should translate --out into vendor response json")
end

local function _test_cli_collect_uses_public_bridge_surface()
  local captured_collect = nil
  local ok = crap.run({
    "collect",
    "--out", "tmp/crap_collect.json",
    "--lane", "contract",
  }, {
    collect_bridge_result = function(options)
      captured_collect = options
      return {
        project_root = "/repo",
        project_name = "Monopoly",
        source_roots = { "src" },
        coverage_result = {
          line_hits = {},
          lanes = {},
        },
      }
    end,
  })

  assert(ok == true, "collect should return true")
  _assert_eq(captured_collect.out, crap.default_tmp_root() .. "/crap_collect.json", "collect should resolve tmp output path")
  _assert_eq(captured_collect.lanes[1], "contract", "collect should preserve lane list")
end

local function _test_cli_viewer_resolves_tmp_alias_before_vendor_call()
  local captured_command = nil
  local ensured_view_dir = nil
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
    ensure_dir = function(path)
      ensured_view_dir = path
      return true
    end,
  })

  assert(ok == true, "cli viewer should return true")
  _assert_eq(ensured_view_dir, crap.default_tmp_root() .. "/crap_view", "viewer should ensure the output dir before launch")
  _assert_eq(captured_command[2], "viewer", "wrapper should dispatch vendor viewer command")
  _assert_contains(table.concat(captured_command, " "), "--in-json " .. crap.default_tmp_root() .. "/crap_report.json",
    "tmp input json should resolve under Monopoly tmp root")
  _assert_contains(table.concat(captured_command, " "), "--out-dir " .. crap.default_tmp_root() .. "/crap_view",
    "tmp output dir should resolve under Monopoly tmp root")
end

local function _test_cli_without_args_defaults_to_report_then_opened_viewer()
  local captured_request = nil
  local commands = {}
  local ok = crap.run({}, {
    workspace_root = "/repo",
    ensure_binary = function(path)
      return path, nil
    end,
    prepare_report_request = function(options)
      captured_request = options
      return "/tmp/default-crap-request.json"
    end,
    run_command = function(command)
      commands[#commands + 1] = command
      return { ok = true, code = 0, output = "" }
    end,
  })

  assert(ok == true, "bare cli should return true")
  _assert_eq(captured_request.out, crap.resolve_cli_path("/repo", "tmp/crap_report.json"),
    "bare cli should prepare the default tmp report json")
  _assert_eq(#commands, 2, "bare cli should run report and viewer")
  _assert_eq(commands[1][2], "report", "bare cli should generate a report first")
  _assert_eq(commands[2][2], "viewer", "bare cli should open the generated viewer second")
  _assert_contains(table.concat(commands[1], " "), "--request-json /tmp/default-crap-request.json",
    "bare cli should pass the prepared request json to vendor report")
  _assert_contains(table.concat(commands[1], " "), "--response-json " .. crap.default_tmp_root() .. "/crap_report.json",
    "bare cli should write the default report json")
  _assert_contains(table.concat(commands[2], " "), "--in-json " .. crap.default_tmp_root() .. "/crap_report.json",
    "viewer should consume the generated report json")
  _assert_contains(table.concat(commands[2], " "), "--out-dir " .. crap.default_tmp_root() .. "/crap_view",
    "viewer should write to the default tmp viewer dir")
  _assert_contains(table.concat(commands[2], " "), "--open",
    "bare cli should auto-open the viewer")
end

local function _test_default_config_path_points_at_monopoly_wrapper_config()
  local path = crap.default_config_path()
  local matches_canonical = path:find("tools/quality/crap/config.lua", 1, true) ~= nil
  assert(matches_canonical, "wrapper should expose the canonical monopoly config path")
end

return {
  name = "crap_tooling_contract",
  tests = {
    { name = "default_tmp_root_preserves_monopoly_paths", run = _test_default_tmp_root_preserves_monopoly_path_convention },
    { name = "install_monopoly_package_paths_only_installs_canonical_repo_patterns", run = _test_install_monopoly_package_paths_only_installs_canonical_repo_patterns },
    { name = "adapter_resolves_behavior_and_contract_lanes", run = _test_adapter_resolves_behavior_and_contract_lanes },
    { name = "cli_report_prepares_request_then_calls_vendor_cli", run = _test_cli_report_prepares_request_then_calls_vendor_cli },
    { name = "cli_collect_uses_public_bridge_surface", run = _test_cli_collect_uses_public_bridge_surface },
    { name = "cli_viewer_resolves_tmp_alias_before_vendor_call", run = _test_cli_viewer_resolves_tmp_alias_before_vendor_call },
    { name = "cli_without_args_defaults_to_report_then_opened_viewer", run = _test_cli_without_args_defaults_to_report_then_opened_viewer },
    { name = "default_config_path_points_at_monopoly_wrapper_config", run = _test_default_config_path_points_at_monopoly_wrapper_config },
  },
}

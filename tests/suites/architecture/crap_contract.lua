local bootstrap = require("tests.bootstrap")
local crap = require("crap")
local adapter = require("quality.crap_monopoly_adapter")

bootstrap.install_package_paths()

local function _assert_eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. "\nexpected: " .. tostring(expected) .. "\nactual: " .. tostring(actual))
  end
end

local function _test_default_tmp_root_preserves_monopoly_path_convention()
  local override = "/tmp/monopoly_crap_override"
  local ok, err = pcall(function()
    _assert_eq(crap.resolve_cli_path("/repo", "tmp/demo.json"), crap.default_tmp_root() .. "/demo.json",
      "tmp alias should resolve relative to default tmp root")
    assert(crap.default_tmp_root():find("monopoly_crap", 1, true) ~= nil,
      "default tmp root should preserve monopoly-specific directory name")
    assert(crap.resolve_cli_path("/repo", override) == override,
      "absolute paths should bypass tmp alias handling")
  end)
  if not ok then
    error(err)
  end
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

local function _test_cli_report_resolves_tmp_alias_before_runner()
  local captured_out_path = nil
  local ok = crap.run({
    "report",
    "--out", "tmp/crap_report.json",
  }, {
    run_report = function(opts)
      captured_out_path = opts.out_path
      return { exit_code = 0 }
    end,
  })
  assert(ok == true, "cli report should return true")
  _assert_eq(captured_out_path, crap.default_tmp_root() .. "/crap_report.json",
    "tmp alias should resolve under Monopoly tmp root")
end

local function _test_cli_viewer_resolves_tmp_alias_before_loader_and_writer()
  local captured_in_json = nil
  local captured_out_dir = nil
  local ok = crap.run({
    "viewer",
    "--in-json", "tmp/crap_report.json",
    "--out-dir", "tmp/crap_view",
  }, {
    load_report = function(path)
      captured_in_json = path
      return { summary = {}, modules = {}, functions = {} }
    end,
    write_viewer = function(paths, data)
      captured_out_dir = paths.out_dir
      return data and data.summary ~= nil
    end,
  })
  assert(ok == true, "cli viewer should return true")
  _assert_eq(captured_in_json, crap.default_tmp_root() .. "/crap_report.json",
    "tmp input json should resolve under Monopoly tmp root")
  _assert_eq(captured_out_dir, crap.default_tmp_root() .. "/crap_view",
    "tmp output dir should resolve under Monopoly tmp root")
end

local function _test_cli_without_args_defaults_to_opened_viewer()
  local captured_out_dir = nil
  local open_calls = 0
  local ok = crap.run({}, {
    run_report = function()
      return {
        summary = { module_count = 0, function_count = 0, total_crap = 0, critical_function_count = 0 },
        modules = {},
        functions = {},
      }
    end,
    write_viewer = function(paths, data, opts)
      captured_out_dir = paths.out_dir
      if opts and opts.open then
        open_calls = open_calls + 1
      end
      return data and data.summary ~= nil
    end,
  })
  assert(ok == true, "bare cli should return true")
  _assert_eq(captured_out_dir, crap.default_tmp_root() .. "/crap_view",
    "bare cli should use Monopoly tmp alias root")
  _assert_eq(open_calls, 1, "bare cli should auto-open viewer")
end

local function _test_default_config_path_points_at_monopoly_wrapper_config()
  assert(crap.default_config_path():find("scripts/quality/crap_monopoly.config.lua", 1, true) ~= nil,
    "wrapper should expose its default config path")
end

return {
  name = "architecture.crap_contract",
  tests = {
    { name = "default_tmp_root_preserves_monopoly_paths", run = _test_default_tmp_root_preserves_monopoly_path_convention },
    { name = "adapter_resolves_behavior_and_contract_lanes", run = _test_adapter_resolves_behavior_and_contract_lanes },
    { name = "cli_report_resolves_tmp_alias_before_runner", run = _test_cli_report_resolves_tmp_alias_before_runner },
    { name = "cli_viewer_resolves_tmp_alias_before_loader_and_writer", run = _test_cli_viewer_resolves_tmp_alias_before_loader_and_writer },
    { name = "cli_without_args_defaults_to_opened_viewer", run = _test_cli_without_args_defaults_to_opened_viewer },
    { name = "default_config_path_points_at_monopoly_wrapper_config", run = _test_default_config_path_points_at_monopoly_wrapper_config },
  },
}

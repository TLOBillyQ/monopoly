local bootstrap = require("spec.bootstrap")

bootstrap.install_package_paths()

local arch_view = require("arch_view")
local common = require("arch_view.runtime.common")
local json_reader = require("arch_view.runtime.json_reader")

local cached_scan_result = nil
local tmp_root = common.make_temp_path("arch_view_test_output", "")
local arch_view_root = "vendor/arch_view"
local _scan_architecture_json

local function _first_existing(paths)
  for _, path in ipairs(paths or {}) do
    if common.path_exists(path) == true then
      return path
    end
  end
  return paths and paths[1] or nil
end

local arch_config_path = _first_existing({
  "tools/quality/arch/config.json",
})

local function _assert_eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. "\nexpected: " .. tostring(expected) .. "\nactual: " .. tostring(actual))
  end
end

local function _read_file(path)
  local content, err = common.read_file(path)
  if content == nil then
    error(err)
  end
  return content
end

local function _exists(path)
  return common.path_exists(path) == true
end

function _scan_architecture_json()
  if cached_scan_result == nil then
    local out_path = tmp_root .. "/scan/architecture.json"
    local ok, err = common.ensure_parent_dir(out_path)
    if not ok then
      error(err)
    end

    arch_view.run_cli({
      "scan",
      "--out", out_path,
    }, {
      default_config_path = arch_config_path,
      asset_root = arch_view_root .. "/viewer",
      cwd = ".",
    })

    cached_scan_result = {
      out_path = out_path,
      payload = json_reader.decode(_read_file(out_path)),
    }
  end
  return cached_scan_result
end

local function _test_cli_scan_writes_metadata()
  local payload = _scan_architecture_json().payload
  _assert_eq(payload.schema_version, 1, "scan command should write schema_version")
  assert(payload.project_root ~= nil and payload.project_root ~= "", "scan command should write project_root")
  assert(payload.config_path ~= nil and payload.config_path ~= "", "scan command should write config_path")
end

local function _test_cli_viewer_supports_in_json()
  local out_dir = tmp_root .. "/viewer_from_json"
  local scan = _scan_architecture_json()

  arch_view.run_cli({
    "viewer",
    "--in-json", scan.out_path,
    "--out-dir", out_dir,
  }, {
    default_config_path = arch_config_path,
    asset_root = arch_view_root .. "/viewer",
    cwd = ".",
  })

  assert(_exists(out_dir .. "/index.html"), "viewer --in-json should export index.html")
  assert(_exists(out_dir .. "/architecture.json"), "viewer --in-json should export architecture.json")
end

local function _test_raw_scan_has_no_presentation_namespace_projection_cycles()
  local scan = _scan_architecture_json()
  local payload = json_reader.decode(_read_file(scan.out_path))
  for _, violation in ipairs((payload.check and payload.check.violations) or {}) do
    assert(violation.view ~= "ui", "raw scan should not report presentation namespace ui projection cycle")
    assert(violation.view ~= "ui.ctl", "raw scan should not report presentation namespace ui.ctl projection cycle")
  end
end

local tooling_tests = {
  { name = "cli_scan_writes_metadata", run = _test_cli_scan_writes_metadata },
  { name = "cli_viewer_supports_in_json", run = _test_cli_viewer_supports_in_json },
  { name = "raw_scan_has_no_presentation_namespace_projection_cycles", run = _test_raw_scan_has_no_presentation_namespace_projection_cycles },
}

return {
  name = "arch_view_live_tooling_contract",
  tests = tooling_tests,
}

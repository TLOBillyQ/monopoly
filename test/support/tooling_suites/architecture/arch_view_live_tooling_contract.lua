-- Cross-repo arch_view CLI contract: pin behavior, not output shape.
--
-- Sibling of arch_view_snapshot_tooling_contract.lua: that one drives the
-- analyze() API, this one drives the real `scan` CLI. Both assert only what
-- monopoly depends on across the pin — schema_version lands in the supported
-- range, and the gate payload has the right shape. arch_view owns the
-- authoritative statement of its own output schema (tests/test_contract.lua,
-- monopoly#245); the viewer-export / projection-cycle assertions that used to
-- live here are gone (see this ticket's resolution for the migration ledger).

local bootstrap = require("test.bootstrap")

bootstrap.install_package_paths()
assert(bootstrap.ensure_tool("arch_view"))

local arch_view = require("arch_view")
local common = require("arch_view.runtime.common")
local json_reader = require("arch_view.runtime.json_reader")
local paths = require("arch_view.internal.paths")

-- Keep in sync with the snapshot contract; bump when adopting a new schema.
local SUPPORTED_SCHEMA_VERSIONS = { [3] = true }

local cached_scan_result = nil
local tmp_root = common.make_temp_path("arch_view_test_output", "")

local function _first_existing(candidates)
  for _, path in ipairs(candidates or {}) do
    if common.path_exists(path) == true then
      return path
    end
  end
  return candidates and candidates[1] or nil
end

local arch_config_path = _first_existing({
  "tools/packages/arch_view/config.json",
})

local function _read_file(path)
  local content, err = common.read_file(path)
  if content == nil then
    error(err)
  end
  return content
end

local function _scan_payload()
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
      asset_root = paths.default_asset_root(),
      cwd = ".",
    })

    cached_scan_result = json_reader.decode(_read_file(out_path))
  end
  return cached_scan_result
end

local function _test_cli_scan_stamps_supported_schema_version()
  local payload = _scan_payload()
  assert(SUPPORTED_SCHEMA_VERSIONS[payload.schema_version] == true,
    "scan wrote schema_version " .. tostring(payload.schema_version) .. ", outside the supported range")
end

local function _test_cli_scan_gate_shape()
  local payload = _scan_payload()
  assert(type(payload.check) == "table", "scan output must carry a check table")
  assert(type(payload.check.ok) == "boolean", "check.ok must be a boolean")
  assert(type(payload.check.violations) == "table", "check.violations must be a table")
end

local tooling_tests = {
  { name = "cli_scan_stamps_supported_schema_version", run = _test_cli_scan_stamps_supported_schema_version },
  { name = "cli_scan_gate_shape", run = _test_cli_scan_gate_shape },
}

return {
  name = "arch_view_live_tooling_contract",
  tests = tooling_tests,
}

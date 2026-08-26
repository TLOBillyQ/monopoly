-- Cross-repo arch_view contract: pin behavior, not output shape.
--
-- Monopoly stops re-stating arch_view's output SHAPE here. The authoritative,
-- human-readable statement of the output schema now lives upstream in
-- arch_view's own contract layer (tests/test_contract.lua, monopoly#245). This
-- suite asserts only the two things monopoly actually depends on across the
-- pin:
--   1. schema_version lands in the range monopoly supports (currently {3}); and
--   2. the gate behaves correctly — check.ok/violations have the right shape,
--      and a KNOWN-violation fixture is judged with the right violation kinds
--      and fields.
--
-- Everything that used to assert viewer-model detail (display_label, full_name,
-- breadcrumb, drillable/leaf, per-node labels, projection collapse) is gone:
-- that is arch_view's own output shape, owned by its contract layer, not a
-- monopoly cross-repo concern. See this ticket's resolution for the per-
-- assertion migration ledger.

local bootstrap = require("test.bootstrap")

bootstrap.install_package_paths()
assert(bootstrap.ensure_tool("arch_view"))

local arch_view = require("arch_view")
local common = require("arch_view.runtime.common")
local module_path = require("arch_view.runtime.module_path")

-- The schema versions monopoly's guard + specs are written against. Bump this
-- set (not scattered == 2 checks) when adopting a new arch_view output schema.
local SUPPORTED_SCHEMA_VERSIONS = { [3] = true }

local function _first_existing(paths)
  for _, path in ipairs(paths or {}) do
    if common.path_exists(path) == true then
      return path
    end
  end
  return paths and paths[1] or nil
end

local arch_config_path = _first_existing({
  "tools/packages/arch_view/config.json",
})

local function _assert_eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. "\nexpected: " .. tostring(expected) .. "\nactual: " .. tostring(actual))
  end
end

-- ---------------------------------------------------------------------------
-- Real-config scan (schema_version + gate shape against monopoly's own config)
-- ---------------------------------------------------------------------------

local _cached_real = nil

local function _real_architecture()
  if _cached_real == nil then
    local architecture, err = arch_view.analyze({
      project_root = ".",
      config_path = arch_config_path,
    })
    if architecture == nil then
      error("analyze failed: " .. tostring(err))
    end
    _cached_real = architecture
  end
  return _cached_real
end

local function _test_analyze_stamps_supported_schema_version()
  local architecture = _real_architecture()
  assert(SUPPORTED_SCHEMA_VERSIONS[architecture.schema_version] == true,
    "schema_version " .. tostring(architecture.schema_version) .. " is outside the supported range")
end

local function _test_gate_shape_on_real_config()
  local architecture = _real_architecture()
  assert(type(architecture.check) == "table", "architecture.check must be a table")
  assert(type(architecture.check.ok) == "boolean", "check.ok must be a boolean")
  assert(type(architecture.check.violations) == "table", "check.violations must be a table")
end

-- ---------------------------------------------------------------------------
-- Known-violation fixture (does the gate actually CATCH violations, with the
-- right structure?). monopoly's real config passes the gate, so a synthetic
-- bad project is the only way to exercise the reject path from this side.
-- ---------------------------------------------------------------------------

local _cached_bad = nil

-- low -> high is a forbidden dependency; loose matches no component rule.
local function _bad_architecture()
  if _cached_bad == nil then
    local root = common.make_temp_path("arch_view_contract_bad", "")
    assert(common.ensure_dir(common.join_path(root, "src")))
    assert(common.write_file(common.join_path(root, "arch_view.config.json"), [[
{
  "source_roots": ["src"],
  "component_rules": [
    { "name": "high", "match": ["^src%.high$"], "component": "high" },
    { "name": "low", "match": ["^src%.low$"], "component": "low" }
  ],
  "forbidden_dependency_rules": [
    {
      "name": "low_no_high",
      "description": "low must not depend on high",
      "from": ["^src%.low$"],
      "to": ["^src%.high$"]
    }
  ]
}
]]))
    assert(common.write_file(common.join_path(root, "src/high.lua"), "return {}\n"))
    assert(common.write_file(common.join_path(root, "src/low.lua"), 'local high = require("src.high")\nreturn {}\n'))
    assert(common.write_file(common.join_path(root, "src/loose.lua"), "return {}\n"))

    local architecture, err = arch_view.analyze({
      project_root = root,
      config_path = common.join_path(root, "arch_view.config.json"),
    })
    common.remove_path(root)
    if architecture == nil then
      error("analyze of known-bad fixture failed: " .. tostring(err))
    end
    _cached_bad = architecture
  end
  return _cached_bad
end

local function _find_violation(check, predicate)
  for _, violation in ipairs((check and check.violations) or {}) do
    if predicate(violation) then
      return violation
    end
  end
  return nil
end

local function _test_gate_rejects_known_bad_fixture()
  local architecture = _bad_architecture()
  _assert_eq(architecture.check.ok, false, "known-bad fixture must fail the gate")
end

local function _test_forbidden_dependency_violation_structure()
  local architecture = _bad_architecture()
  local violation = _find_violation(architecture.check, function(v)
    return v.kind == "forbidden_dependency"
  end)
  assert(violation ~= nil, "gate must report the low -> high forbidden dependency")
  _assert_eq(violation.rule, "low_no_high", "forbidden_dependency must name its rule")
  _assert_eq(violation.from, "src.low", "forbidden_dependency must carry `from`")
  _assert_eq(violation.to, "src.high", "forbidden_dependency must carry `to`")
end

local function _test_unclassified_module_violation_structure()
  local architecture = _bad_architecture()
  local violation = _find_violation(architecture.check, function(v)
    return v.kind == "unclassified_module" and v.module_id == "src.loose"
  end)
  assert(violation ~= nil, "gate must report src.loose as an unclassified_module with its module_id")
end

-- arch_view's runtime must stay self-contained across the pin (no accidental
-- dependency on monopoly internals leaking into the vendored tool). Cheap
-- cross-repo insurance against a bad re-pin; unrelated to viewer shape.
local function _test_arch_view_runtime_is_self_contained()
  -- 从已加载模块定位源码(rock 形态在 lua_dir 下,不再有 clone 形态的 lib/ 树)。
  -- source_dir(0):0 级指向 module_path.lua 自身文件,其父目录即 runtime/。
  local runtime_dir = module_path.source_dir(0)
  local common_source = assert(common.read_file(common.join_path(runtime_dir, "common.lua")))
  local host_source = assert(common.read_file(common.join_path(runtime_dir, "host.lua")))
  -- #302:本仓底层模块已由 shared.lib.common 归位为 tools/foundation(tools/ 重设计决策)。
  -- 契约升级:arch_view runtime 自包含,不得依赖 monopoly foundation。
  assert(common_source:find('require("foundation.', 1, true) == nil,
    "arch_view runtime common must not depend on monopoly foundation")
  assert(host_source:find("src.foundation.number", 1, true) == nil,
    "arch_view runtime host must not depend on monopoly src modules")
end

local contract_tests = {
  { name = "analyze_stamps_supported_schema_version", run = _test_analyze_stamps_supported_schema_version },
  { name = "gate_shape_on_real_config", run = _test_gate_shape_on_real_config },
  { name = "gate_rejects_known_bad_fixture", run = _test_gate_rejects_known_bad_fixture },
  { name = "forbidden_dependency_violation_structure", run = _test_forbidden_dependency_violation_structure },
  { name = "unclassified_module_violation_structure", run = _test_unclassified_module_violation_structure },
  { name = "arch_view_runtime_is_self_contained", run = _test_arch_view_runtime_is_self_contained },
}

return {
  name = "arch_view_snapshot_tooling_contract",
  tests = contract_tests,
}

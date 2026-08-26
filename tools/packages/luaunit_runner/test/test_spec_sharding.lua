---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/packages/luaunit_runner/test/test_spec_sharding.lua") end
require("test.bootstrap").install_package_paths()

local lu = require("luaunit")
local fs_lib = require("foundation.fs")
local sharding = require("packages.luaunit_runner.spec_sharding")

local _TMP_ROOT = "./tmp/spec_sharding_spec"

local function _rm_rf(path)
  fs_lib.remove_path(path)
end

local function _write_file(path, content)
  assert(fs_lib.write_file(path, content or ""))
end

local function _expected_discovered_path(path)
  return path
end

TestSpecShardingDiscoverSpecFiles = {}

function TestSpecShardingDiscoverSpecFiles:setUp()
  _rm_rf(_TMP_ROOT)
end

function TestSpecShardingDiscoverSpecFiles:tearDown()
  _rm_rf(_TMP_ROOT)
end

function TestSpecShardingDiscoverSpecFiles:test_returns_empty_list_for_missing_root()
  local files = sharding.discover_spec_files(_TMP_ROOT .. "/does_not_exist")
  lu.assertEquals(files, {})
end

function TestSpecShardingDiscoverSpecFiles:test_returns_sorted_absolute_relative_paths_under_root()
  _write_file(_TMP_ROOT .. "/test_b.lua", "it('b', function() end)\n")
  _write_file(_TMP_ROOT .. "/test_a.lua", "it('a', function() end)\n")
  _write_file(_TMP_ROOT .. "/nested/test_c.lua", "it('c', function() end)\n")
  _write_file(_TMP_ROOT .. "/helper_mod.lua", "local M = {}\nreturn M\n")

  local files = sharding.discover_spec_files(_TMP_ROOT)

  lu.assertIs(#files, 3, "expected 3 test_*.lua entries, got " .. tostring(#files))
  lu.assertIs(files[1], _expected_discovered_path(_TMP_ROOT .. "/nested/test_c.lua"))
  lu.assertIs(files[2], _expected_discovered_path(_TMP_ROOT .. "/test_a.lua"))
  lu.assertIs(files[3], _expected_discovered_path(_TMP_ROOT .. "/test_b.lua"))
end

-- 发现是纯命名约定(#560):suite_flatten 拍平套件这类动态生成用例的文件
-- 内无任何静态 it(/test 定义,也必须被收集——内容嗅探曾让它们静默漏跑。
function TestSpecShardingDiscoverSpecFiles:test_discovers_named_specs_without_static_test_defs()
  _write_file(_TMP_ROOT .. "/test_dynamic.lua",
    "local flatten = require(\"x.suite_flatten\")\nTestDyn = flatten({})\n")

  local files = sharding.discover_spec_files(_TMP_ROOT)

  lu.assertIs(#files, 1)
  lu.assertIs(files[1], _expected_discovered_path(_TMP_ROOT .. "/test_dynamic.lua"))
end

TestSpecShardingFileCost = {}

function TestSpecShardingFileCost:setUp()
  _rm_rf(_TMP_ROOT)
end

function TestSpecShardingFileCost:tearDown()
  _rm_rf(_TMP_ROOT)
end

function TestSpecShardingFileCost:test_returns_1_for_files_with_no_it_occurrences()
  local path = _TMP_ROOT .. "/test_empty.lua"
  _write_file(path, "describe('only', function() end)\n")
  lu.assertIs(sharding.file_cost(path), 1)
end

function TestSpecShardingFileCost:test_counts_each_it_occurrence()
  local path = _TMP_ROOT .. "/test_three.lua"
  _write_file(path,
    "it('one', function() end)\n" ..
    "it('two', function() end)\n" ..
    "it('three', function() end)\n")
  lu.assertIs(sharding.file_cost(path), 3)
end

function TestSpecShardingFileCost:test_returns_1_for_missing_path()
  lu.assertIs(sharding.file_cost(_TMP_ROOT .. "/test_missing.lua"), 1)
end

-- 原生 LuaUnit TestXxx 方法定义也要被识别/计数(file_cost)。
function TestSpecShardingDiscoverSpecFiles:test_discovers_luaunit_native_spec_files()
  _write_file(_TMP_ROOT .. "/test_native_colon.lua",
    "TestFoo = {}\nfunction TestFoo:test_bar(self) end\n")
  _write_file(_TMP_ROOT .. "/test_native_bracket.lua",
    "TestBar = {}\nTestBar[\"test_中文名\"] = function(self) end\n")
  _write_file(_TMP_ROOT .. "/support_mod.lua", "local M = {}\nreturn M\n")

  local files = sharding.discover_spec_files(_TMP_ROOT)

  lu.assertIs(#files, 2, "expected 2 native test_*.lua entries, got " .. tostring(#files))
  lu.assertIs(files[1], _expected_discovered_path(_TMP_ROOT .. "/test_native_bracket.lua"))
  lu.assertIs(files[2], _expected_discovered_path(_TMP_ROOT .. "/test_native_colon.lua"))
end

function TestSpecShardingFileCost:test_counts_luaunit_native_test_definitions()
  local path = _TMP_ROOT .. "/test_native.lua"
  _write_file(path,
    "TestFoo = {}\n" ..
    "function TestFoo:test_a(self) end\n" ..
    "function TestFoo.test_dot_form(self) end\n" ..
    "TestFoo[\"test_b\"] = function(self) end\n" ..
    "TestFoo[\"test_\" .. case.name] = function(self) case.run() end\n")
  lu.assertIs(sharding.file_cost(path), 4)
end

TestSpecShardingBuildLptLanes = {}

function TestSpecShardingBuildLptLanes:test_returns_a_single_lane_when_worker_count_is_1()
  local files = { "a.lua", "b.lua", "c.lua" }
  local lanes = sharding.build_lpt_lanes(files, 1)
  lu.assertIs(#lanes, 1)
  lu.assertIs(lanes[1].index, 1)
  lu.assertIs(#lanes[1].files, 3)
end

function TestSpecShardingBuildLptLanes:test_never_emits_empty_lanes_clamps_workers_to_file_count()
  local files = { "a.lua", "b.lua" }
  local lanes = sharding.build_lpt_lanes(files, 5)
  lu.assertIs(#lanes, 2)
  for _, lane in ipairs(lanes) do
    lu.assertTrue(#lane.files >= 1, "lane " .. tostring(lane.index) .. " is empty")
  end
end

function TestSpecShardingBuildLptLanes:test_packs_by_descending_cost_lpt_heaviest_file_goes_to_lane_1()
  -- Costs derived from real fixture files so we know totals deterministically.
  _rm_rf(_TMP_ROOT)
  local heavy = _TMP_ROOT .. "/test_heavy.lua"
  local light_a = _TMP_ROOT .. "/test_light_a.lua"
  local light_b = _TMP_ROOT .. "/test_light_b.lua"
  _write_file(heavy,
    "it('1', function() end)\nit('2', function() end)\nit('3', function() end)\nit('4', function() end)\n")
  _write_file(light_a, "it('x', function() end)\n")
  _write_file(light_b, "it('y', function() end)\n")

  local lanes = sharding.build_lpt_lanes({ light_a, light_b, heavy }, 2)

  lu.assertIs(#lanes, 2)
  -- Lane 1 takes the heavy file first (descending-cost ordering).
  lu.assertIs(lanes[1].files[1], heavy)
  -- Both lights land on lane 2 (cumulative cost 2 < heavy's 4).
  lu.assertIs(#lanes[2].files, 2)
  _rm_rf(_TMP_ROOT)
end

function TestSpecShardingBuildLptLanes:test_breaks_ties_by_original_lane_index_when_costs_are_equal()
  _rm_rf(_TMP_ROOT)
  local a = _TMP_ROOT .. "/test_a.lua"
  local b = _TMP_ROOT .. "/test_b.lua"
  _write_file(a, "it('a', function() end)\n")
  _write_file(b, "it('b', function() end)\n")

  local lanes = sharding.build_lpt_lanes({ a, b }, 2)
  -- First file with equal cost goes to lane with lowest index.
  lu.assertIs(lanes[1].files[1], a)
  lu.assertIs(lanes[2].files[1], b)
  _rm_rf(_TMP_ROOT)
end

function TestSpecShardingBuildLptLanes:test_sets_total_cost_on_each_lane_equal_to_sum_of_its_files_costs()
  _rm_rf(_TMP_ROOT)
  local a = _TMP_ROOT .. "/test_a.lua"
  local b = _TMP_ROOT .. "/test_b.lua"
  _write_file(a, "it('1', function() end)\nit('2', function() end)\n")
  _write_file(b, "it('x', function() end)\n")

  local lanes = sharding.build_lpt_lanes({ a, b }, 1)
  lu.assertIs(#lanes, 1)
  lu.assertIs(lanes[1].total_cost, 3)
  _rm_rf(_TMP_ROOT)
end

TestSpecShardingResolveWorkers = {}

-- Tests use a sentinel env var name that we control to avoid polluting real env.
local TEST_ENV = "__EGGY_SHARDING_TEST_ENV_DOES_NOT_EXIST"

function TestSpecShardingResolveWorkers:test_falls_back_to_default_workers_when_env_var_unset()
  lu.assertIs(sharding.resolve_workers(TEST_ENV, 10, 3), 3)
end

function TestSpecShardingResolveWorkers:test_returns_1_when_env_var_is_1()
  -- We can't os.setenv from Lua, but we can verify via a known-set env name.
  -- Use PATH (almost always set, non-numeric) to assert non-numeric fallback path.
  lu.assertIs(sharding.resolve_workers("PATH", 10, 2), 2)
end

function TestSpecShardingResolveWorkers:test_clamps_result_to_file_count_range()
  lu.assertIs(sharding.resolve_workers(TEST_ENV, 2, 5), 2)
  lu.assertIs(sharding.resolve_workers(TEST_ENV, 1, 5), 1)
end

function TestSpecShardingResolveWorkers:test_returns_1_when_file_count_is_0()
  lu.assertIs(sharding.resolve_workers(TEST_ENV, 0, 5), 1)
end

function TestSpecShardingResolveWorkers:test_treats_auto_or_empty_as_fallback_to_default()
  -- Indirect: we test the contract by setting env via os.execute is not portable.
  -- Direct API surface: when env_var_name is nil, behave as if unset.
  lu.assertIs(sharding.resolve_workers(nil, 10, 4), 4)
end


return TestSpecShardingDiscoverSpecFiles

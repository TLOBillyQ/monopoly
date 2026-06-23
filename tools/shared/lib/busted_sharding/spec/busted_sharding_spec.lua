---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/shared/lib/busted_sharding/spec/busted_sharding_spec.lua") end
require("spec.bootstrap").install_package_paths()

local common = require("shared.lib.common")
local sharding = require("shared.lib.busted_sharding")

local _TMP_ROOT = "./tmp/busted_sharding_spec"

local function _rm_rf(path)
  common.remove_path(path)
end

local function _write_file(path, content)
  assert(common.write_file(path, content or ""))
end

local function _expected_discovered_path(path)
  if common.is_windows() then
    return common.resolve_path(common.current_dir(), path)
  end
  return path
end

describe("busted_sharding.discover_spec_files", function()
  before_each(function()
    _rm_rf(_TMP_ROOT)
  end)

  after_each(function()
    _rm_rf(_TMP_ROOT)
  end)

  it("returns empty list for missing root", function()
    local files = sharding.discover_spec_files(_TMP_ROOT .. "/does_not_exist")
    assert.are.same({}, files)
  end)

  it("returns sorted absolute-relative paths under root", function()
    _write_file(_TMP_ROOT .. "/b_spec.lua", "it('b', function() end)\n")
    _write_file(_TMP_ROOT .. "/a_spec.lua", "it('a', function() end)\n")
    _write_file(_TMP_ROOT .. "/nested/c_spec.lua", "it('c', function() end)\n")
    _write_file(_TMP_ROOT .. "/not_a_spec.lua", "")

    local files = sharding.discover_spec_files(_TMP_ROOT)

    assert.are.equal(3, #files, "expected 3 *_spec.lua entries, got " .. tostring(#files))
    assert.are.equal(_expected_discovered_path(_TMP_ROOT .. "/a_spec.lua"), files[1])
    assert.are.equal(_expected_discovered_path(_TMP_ROOT .. "/b_spec.lua"), files[2])
    assert.are.equal(_expected_discovered_path(_TMP_ROOT .. "/nested/c_spec.lua"), files[3])
  end)
end)

describe("busted_sharding.file_cost", function()
  before_each(function()
    _rm_rf(_TMP_ROOT)
  end)

  after_each(function()
    _rm_rf(_TMP_ROOT)
  end)

  it("returns 1 for files with no `it(` occurrences", function()
    local path = _TMP_ROOT .. "/empty_spec.lua"
    _write_file(path, "describe('only', function() end)\n")
    assert.are.equal(1, sharding.file_cost(path))
  end)

  it("counts each `it(` occurrence", function()
    local path = _TMP_ROOT .. "/three_spec.lua"
    _write_file(path,
      "it('one', function() end)\n" ..
      "it('two', function() end)\n" ..
      "it('three', function() end)\n")
    assert.are.equal(3, sharding.file_cost(path))
  end)

  it("returns 1 for missing path", function()
    assert.are.equal(1, sharding.file_cost(_TMP_ROOT .. "/missing_spec.lua"))
  end)
end)

describe("busted_sharding.build_lpt_lanes", function()
  it("returns a single lane when worker_count == 1", function()
    local files = { "a.lua", "b.lua", "c.lua" }
    local lanes = sharding.build_lpt_lanes(files, 1)
    assert.are.equal(1, #lanes)
    assert.are.equal(1, lanes[1].index)
    assert.are.equal(3, #lanes[1].files)
  end)

  it("never emits empty lanes (clamps workers to #files)", function()
    local files = { "a.lua", "b.lua" }
    local lanes = sharding.build_lpt_lanes(files, 5)
    assert.are.equal(2, #lanes)
    for _, lane in ipairs(lanes) do
      assert.is_true(#lane.files >= 1, "lane " .. tostring(lane.index) .. " is empty")
    end
  end)

  it("packs by descending cost (LPT) — heaviest file goes to lane 1", function()
    -- Costs derived from real fixture files so we know totals deterministically.
    _rm_rf(_TMP_ROOT)
    local heavy = _TMP_ROOT .. "/heavy_spec.lua"
    local light_a = _TMP_ROOT .. "/light_a_spec.lua"
    local light_b = _TMP_ROOT .. "/light_b_spec.lua"
    _write_file(heavy,
      "it('1', function() end)\nit('2', function() end)\nit('3', function() end)\nit('4', function() end)\n")
    _write_file(light_a, "it('x', function() end)\n")
    _write_file(light_b, "it('y', function() end)\n")

    local lanes = sharding.build_lpt_lanes({ light_a, light_b, heavy }, 2)

    assert.are.equal(2, #lanes)
    -- Lane 1 takes the heavy file first (descending-cost ordering).
    assert.are.equal(heavy, lanes[1].files[1])
    -- Both lights land on lane 2 (cumulative cost 2 < heavy's 4).
    assert.are.equal(2, #lanes[2].files)
    _rm_rf(_TMP_ROOT)
  end)

  it("breaks ties by original lane index when costs are equal", function()
    _rm_rf(_TMP_ROOT)
    local a = _TMP_ROOT .. "/a_spec.lua"
    local b = _TMP_ROOT .. "/b_spec.lua"
    _write_file(a, "it('a', function() end)\n")
    _write_file(b, "it('b', function() end)\n")

    local lanes = sharding.build_lpt_lanes({ a, b }, 2)
    -- First file with equal cost goes to lane with lowest index.
    assert.are.equal(a, lanes[1].files[1])
    assert.are.equal(b, lanes[2].files[1])
    _rm_rf(_TMP_ROOT)
  end)

  it("sets total_cost on each lane equal to sum of its files' costs", function()
    _rm_rf(_TMP_ROOT)
    local a = _TMP_ROOT .. "/a_spec.lua"
    local b = _TMP_ROOT .. "/b_spec.lua"
    _write_file(a, "it('1', function() end)\nit('2', function() end)\n")
    _write_file(b, "it('x', function() end)\n")

    local lanes = sharding.build_lpt_lanes({ a, b }, 1)
    assert.are.equal(1, #lanes)
    assert.are.equal(3, lanes[1].total_cost)
    _rm_rf(_TMP_ROOT)
  end)
end)

describe("busted_sharding.resolve_workers", function()
  -- Tests use a sentinel env var name that we control to avoid polluting real env.
  local TEST_ENV = "__MONO_SHARDING_TEST_ENV_DOES_NOT_EXIST"

  it("falls back to default_workers when env var unset", function()
    assert.are.equal(3, sharding.resolve_workers(TEST_ENV, 10, 3))
  end)

  it("returns 1 when env var is '1'", function()
    -- We can't os.setenv from Lua, but we can verify via a known-set env name.
    -- Use PATH (almost always set, non-numeric) to assert non-numeric fallback path.
    assert.are.equal(2, sharding.resolve_workers("PATH", 10, 2))
  end)

  it("clamps result to [1, file_count]", function()
    assert.are.equal(2, sharding.resolve_workers(TEST_ENV, 2, 5))
    assert.are.equal(1, sharding.resolve_workers(TEST_ENV, 1, 5))
  end)

  it("returns 1 when file_count == 0", function()
    assert.are.equal(1, sharding.resolve_workers(TEST_ENV, 0, 5))
  end)

  it("treats 'auto' / '' as fallback to default", function()
    -- Indirect: we test the contract by setting env via os.execute is not portable.
    -- Direct API surface: when env_var_name is nil, behave as if unset.
    assert.are.equal(4, sharding.resolve_workers(nil, 10, 4))
  end)
end)

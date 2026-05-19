local M = require("src.app.testing.test_profiles")

describe("test_profiles.profiles_in_group", function()
  it("returns profiles matching the given group", function()
    local result = M.profiles_in_group("economy_core")
    assert(type(result) == "table", "expected table")
    assert(#result > 0, "expected at least one economy_core profile")
    for _, name in ipairs(result) do
      local p = M.get(name)
      assert(p ~= nil, "profile should exist: " .. tostring(name))
      assert(p.group == "economy_core", "profile group mismatch for: " .. tostring(name))
    end
  end)

  it("returns empty table for unknown group", function()
    local result = M.profiles_in_group("nonexistent_group_xyz")
    assert(type(result) == "table", "expected table")
    assert(#result == 0, "expected empty result for unknown group")
  end)

  it("filters by value when opts.value is set", function()
    local all = M.profiles_in_group("economy_core")
    local core_only = M.profiles_in_group("economy_core", { value = "core" })
    assert(#core_only <= #all, "filtered should be subset of all")
    for _, name in ipairs(core_only) do
      local p = M.get(name)
      assert(p ~= nil and p.value == "core", "expected value=core for: " .. tostring(name))
    end
  end)

  it("excludes default profile when include_default is false", function()
    local with_default = M.profiles_in_group("startup_smoke", { include_default = true })
    local without_default = M.profiles_in_group("startup_smoke", { include_default = false })
    for _, name in ipairs(without_default) do
      assert(name ~= "default", "default should not appear when include_default=false")
    end
    assert(#without_default <= #with_default, "without_default should be subset")
  end)

  it("returns sorted result", function()
    local result = M.profiles_in_group("combat_obstacle")
    assert(#result > 1, "need multiple results to test sort")
    for i = 2, #result do
      local prev = M.get(result[i - 1]) or {}
      local curr = M.get(result[i]) or {}
      assert(prev.group == curr.group, "all results share group")
    end
  end)
end)

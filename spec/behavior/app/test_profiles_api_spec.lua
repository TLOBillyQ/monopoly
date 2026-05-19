local M = require("src.app.testing.test_profiles")

describe("test_profiles API", function()
  describe("M.resolve", function()
    it("_test_resolve_nil_returns_default", function()
      local p = M.resolve(nil)
      assert(type(p) == "table", "should return table")
      assert(p.group == "startup_smoke", "default group: " .. tostring(p.group))
      assert(p.value == "smoke", "default value: " .. tostring(p.value))
      assert(p.goal == "baseline_startup_and_roster", "default goal")
    end)

    it("_test_resolve_default_covers_and_owner_tests_exact_values", function()
      local p = M.resolve("default")
      assert(#p.covers == 3, "default has 3 covers")
      assert(p.covers[1] == "startup", "first cover is startup")
      assert(p.covers[2] == "roster", "second cover is roster")
      assert(p.covers[3] == "render_bootstrap", "third cover is render_bootstrap")
      assert(type(p.owner_tests) == "table" and #p.owner_tests > 0, "owner_tests present")
      assert(p.owner_tests[1] == "runtime.startup_profile", "owner_tests[1]: " .. tostring(p.owner_tests[1]))
    end)

    it("_test_resolve_empty_string_returns_default", function()
      local p = M.resolve("")
      assert(p.group == "startup_smoke", "empty string returns default")
      assert(p.value == "smoke", "empty string returns default value")
    end)

    it("_test_resolve_default_string_returns_default", function()
      local p = M.resolve("default")
      assert(p.group == "startup_smoke", "'default' string returns default")
    end)

    it("_test_resolve_unknown_profile_returns_default", function()
      local p = M.resolve("does_not_exist_ever")
      assert(p.group == "startup_smoke", "unknown name falls back to default")
    end)

    it("_test_resolve_known_non_default_profile_returns_its_group", function()
      -- combo_exile_vs_angel_target is a real combat_obstacle/core profile
      local p = M.resolve("combo_exile_vs_angel_target")
      assert(p.group == "combat_obstacle", "known profile returns its own group, not default: " .. tostring(p.group))
      assert(p.value == "core", "known profile returns its own value")
    end)

    it("_test_resolve_returns_independent_copy", function()
      local p1 = M.resolve("default")
      local p2 = M.resolve("default")
      assert(p1 ~= p2, "each resolve returns a new copy")
    end)
  end)

  describe("M.has", function()
    it("_test_has_default_returns_true", function()
      assert(M.has("default") == true, "'default' is always present")
    end)

    it("_test_has_nil_returns_false", function()
      assert(M.has(nil) == false, "nil is not present")
    end)

    it("_test_has_unknown_returns_false", function()
      assert(M.has("totally_unknown_xyz") == false, "unknown profile not present")
    end)

    it("_test_has_known_profile_returns_true", function()
      local names = M.names()
      for _, n in ipairs(names) do
        assert(M.has(n) == true, "named profile should be present: " .. tostring(n))
      end
    end)
  end)

  describe("M.get", function()
    it("_test_get_default_returns_table", function()
      local p = M.get("default")
      assert(type(p) == "table", "get default returns table")
      assert(p.group == "startup_smoke", "default group correct")
    end)

    it("_test_get_unknown_returns_nil", function()
      assert(M.get("unknown_xyz_abc") == nil, "get unknown returns nil")
    end)

    it("_test_get_nil_returns_nil", function()
      assert(M.get(nil) == nil, "get nil returns nil")
    end)

    it("_test_get_returns_independent_copy", function()
      local p1 = M.get("default")
      local p2 = M.get("default")
      assert(p1 ~= p2, "each get returns a new copy")
      p1.group = "modified"
      assert(p2.group ~= "modified", "copies are independent")
    end)
  end)

  describe("M.names", function()
    it("_test_names_includes_default", function()
      local found = false
      for _, n in ipairs(M.names()) do
        if n == "default" then found = true break end
      end
      assert(found, "names() should include 'default'")
    end)

    it("_test_names_returns_sorted_list", function()
      local names = M.names()
      assert(#names > 0, "at least one name")
      for i = 2, #names do
        local p_prev = M.get(names[i - 1]) or M.resolve("default")
        local p_curr = M.get(names[i]) or M.resolve("default")
        local prev_group = p_prev.group
        local curr_group = p_curr.group
        if prev_group == curr_group then
          assert(names[i - 1] <= names[i], "same-group names sorted alphabetically")
        end
      end
    end)
  end)

  describe("M.groups", function()
    it("_test_groups_returns_table", function()
      local g = M.groups()
      assert(type(g) == "table" and #g > 0, "groups returns non-empty table")
    end)

    it("_test_groups_includes_startup_smoke", function()
      local found = false
      for _, g in ipairs(M.groups()) do
        if g == "startup_smoke" then found = true break end
      end
      assert(found, "groups includes startup_smoke (default group)")
    end)

    it("_test_groups_sorted_by_order", function()
      local group_order = {
        startup_smoke = 1, combat_obstacle = 2, relocation_status = 3,
        interrupt_resume = 4, property_control = 5, economy_core = 6, commerce_paid = 7,
      }
      local g = M.groups()
      for i = 2, #g do
        local prev = group_order[g[i - 1]] or 999
        local curr = group_order[g[i]] or 999
        assert(prev <= curr, "groups should be sorted: " .. tostring(g[i - 1]) .. " before " .. tostring(g[i]))
      end
    end)
  end)
end)

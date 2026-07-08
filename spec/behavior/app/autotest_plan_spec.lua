local autotest_plan = require("src.app.testing.autotest_plan")
local test_profiles = require("src.app.testing.test_profiles")

describe("autotest_plan.resolve", function()
  it("all_expands_to_every_profile_without_default", function()
    local plan = autotest_plan.resolve("all")
    local expected = 0
    for _, name in ipairs(test_profiles.names()) do
      if name ~= "default" then
        expected = expected + 1
      end
    end
    assert(#plan == expected, "all should cover every non-default profile")
    for _, name in ipairs(plan) do
      assert(name ~= "default", "all must not include default")
      assert(test_profiles.has(name), "unknown profile in plan: " .. tostring(name))
    end
  end)

  it("all_keeps_group_order_stable", function()
    local plan = autotest_plan.resolve("all")
    local names = {}
    for _, name in ipairs(test_profiles.names()) do
      if name ~= "default" then
        names[#names + 1] = name
      end
    end
    for i, name in ipairs(names) do
      assert(plan[i] == name, "plan order should mirror test_profiles.names()")
    end
  end)

  it("group_selector_expands_to_group_members_only", function()
    local plan = autotest_plan.resolve("group:combat_obstacle")
    assert(#plan > 0, "combat_obstacle group should be non-empty")
    for _, name in ipairs(plan) do
      assert(test_profiles.get(name).group == "combat_obstacle",
        "group plan leaked foreign profile: " .. tostring(name))
    end
  end)

  it("comma_list_preserves_written_order", function()
    local plan = autotest_plan.resolve("solo_missile, solo_mine")
    assert(#plan == 2, "list should keep both entries")
    assert(plan[1] == "solo_missile" and plan[2] == "solo_mine",
      "list order should follow the selector text")
  end)

  it("rejects_unknown_profile_group_and_default", function()
    assert(not pcall(autotest_plan.resolve, "no_such_profile"), "unknown profile must fail")
    assert(not pcall(autotest_plan.resolve, "group:no_such_group"), "unknown group must fail")
    assert(not pcall(autotest_plan.resolve, "default"), "default is not a testable profile")
    assert(not pcall(autotest_plan.resolve, "solo_mine,solo_mine"), "duplicates must fail")
    assert(not pcall(autotest_plan.resolve, ""), "empty selector must fail")
    assert(not pcall(autotest_plan.resolve, nil), "nil selector must fail")
  end)
end)

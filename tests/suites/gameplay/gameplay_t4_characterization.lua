local bankruptcy = require("src.game.systems.endgame.bankruptcy")

local function _test_call_life_die_with_role_param_succeeds()
  local life_comp = {
    die = function(self, role)
      return true
    end,
  }
  local role = { id = 1 }
  local result = bankruptcy._call_life_die(life_comp, role)
  assert(result == true, "should return true when life_comp.die with role succeeds")
end

local function _test_call_life_die_fallback_to_just_role()
  local call_count = 0
  local life_comp = {
    die = function(self, arg)
      call_count = call_count + 1
      if arg == nil then
        return false
      end
      return true
    end,
  }
  local role = { id = 2 }
  local result = bankruptcy._call_life_die(life_comp, role)
  assert(result == true, "should fallback to just role param")
  assert(call_count >= 1, "should have called die at least once")
end

local function _test_call_life_die_fallback_to_nil()
  local call_count = 0
  local life_comp = {
    die = function(self, arg)
      call_count = call_count + 1
      if arg == nil then
        return true
      end
      return false
    end,
  }
  local role = { id = 3 }
  local result = bankruptcy._call_life_die(life_comp, role)
  assert(result == true, "should fallback to nil param eventually")
end

local function _test_call_life_die_non_table_returns_false()
  local result = bankruptcy._call_life_die("not a table", {})
  assert(result == false, "should return false for non-table life_comp")
  result = bankruptcy._call_life_die(nil, {})
  assert(result == false, "should return false for nil life_comp")
  result = bankruptcy._call_life_die(123, {})
  assert(result == false, "should return false for numeric life_comp")
end

local function _test_merge_executor_groups_combines_multiple_groups()
  local executors = require("src.game.systems.land.executors")
  local merged = executors._merge_executor_groups({
    { buy_land = { name = "buy" }, upgrade_land = { name = "upgrade" } },
    { pay_rent = { name = "rent" }, tax = { name = "tax" } },
  })
  assert(merged.buy_land ~= nil, "should have buy_land executor")
  assert(merged.upgrade_land ~= nil, "should have upgrade_land executor")
  assert(merged.pay_rent ~= nil, "should have pay_rent executor")
  assert(merged.tax ~= nil, "should have tax executor")
end

local function _test_merge_executor_groups_later_overrides_earlier()
  local executors = require("src.game.systems.land.executors")
  local merged = executors._merge_executor_groups({
    { buy_land = { name = "original" } },
    { buy_land = { name = "override" } },
  })
  assert(merged.buy_land.name == "override", "later group should override earlier")
end

local function _test_merge_executor_groups_handles_empty_groups()
  local executors = require("src.game.systems.land.executors")
  local merged = executors._merge_executor_groups({
    {},
    { buy_land = { name = "buy" } },
    {},
  })
  assert(merged.buy_land ~= nil, "should handle empty groups")
  assert(merged.buy_land.name == "buy", "should have correct executor after empty groups")
end

return {
  name = "gameplay_t4_characterization",
  tests = {
    { name = "_test_call_life_die_with_role_param_succeeds", run = _test_call_life_die_with_role_param_succeeds },
    { name = "_test_call_life_die_fallback_to_just_role", run = _test_call_life_die_fallback_to_just_role },
    { name = "_test_call_life_die_fallback_to_nil", run = _test_call_life_die_fallback_to_nil },
    { name = "_test_call_life_die_non_table_returns_false", run = _test_call_life_die_non_table_returns_false },
    { name = "_test_merge_executor_groups_combines_multiple_groups", run = _test_merge_executor_groups_combines_multiple_groups },
    { name = "_test_merge_executor_groups_later_overrides_earlier", run = _test_merge_executor_groups_later_overrides_earlier },
    { name = "_test_merge_executor_groups_handles_empty_groups", run = _test_merge_executor_groups_handles_empty_groups },
  },
}

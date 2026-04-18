local bankruptcy = require("src.rules.endgame.bankruptcy")

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

return {
  name = "bankruptcy_elimination",
  tests = {
    { name = "_test_call_life_die_with_role_param_succeeds", run = _test_call_life_die_with_role_param_succeeds },
    { name = "_test_call_life_die_fallback_to_just_role", run = _test_call_life_die_fallback_to_just_role },
    { name = "_test_call_life_die_fallback_to_nil", run = _test_call_life_die_fallback_to_nil },
    { name = "_test_call_life_die_non_table_returns_false", run = _test_call_life_die_non_table_returns_false },
  },
}

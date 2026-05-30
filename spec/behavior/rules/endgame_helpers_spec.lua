local P = require("spec.support.shared_support")
local _assert_eq = P.assert_eq
local endgame = require("src.rules.endgame")

describe("endgame._resolve_life_component", function()
  it("returns_nil_for_non_table_role", function()
    local result = endgame._resolve_life_component("not a table")
    _assert_eq(result, nil, "string role returns nil")
    result = endgame._resolve_life_component(42)
    _assert_eq(result, nil, "number role returns nil")
    result = endgame._resolve_life_component(nil)
    _assert_eq(result, nil, "nil role returns nil")
  end)

  it("returns_nil_when_get_component_missing", function()
    local result = endgame._resolve_life_component({})
    _assert_eq(result, nil, "table without get_component returns nil")
  end)

  it("returns_nil_when_get_component_not_function", function()
    local result = endgame._resolve_life_component({ get_component = "not a function" })
    _assert_eq(result, nil, "non-function get_component returns nil")
  end)

  it("returns_component_when_get_component_succeeds", function()
    local life_comp = { hp = 0 }
    local role = {
      get_component = function(self, name)
        if name == "LifeComp" then return life_comp end
        return nil
      end,
    }
    local result = endgame._resolve_life_component(role)
    _assert_eq(result, life_comp, "returns the LifeComp")
  end)

  it("returns_nil_when_get_component_errors", function()
    local role = {
      get_component = function() error("boom") end,
    }
    local result = endgame._resolve_life_component(role)
    _assert_eq(result, nil, "pcall failure returns nil")
  end)
end)

describe("endgame._try_call_life_die", function()
  it("returns_false_for_nil_role", function()
    local result = endgame._try_call_life_die(nil)
    _assert_eq(result, false, "nil role returns false")
  end)

  it("returns_true_when_role_die_succeeds", function()
    local role = {
      die = function(self, arg) return true end,
    }
    local result = endgame._try_call_life_die(role)
    _assert_eq(result, true, "role.die success returns true")
  end)

  it("falls_back_to_life_component_die", function()
    local called = false
    local life_comp = {
      die = function(self, role) called = true; return true end,
    }
    local role = {
      get_component = function(self, name)
        if name == "LifeComp" then return life_comp end
        return nil
      end,
    }
    local result = endgame._try_call_life_die(role)
    _assert_eq(result, true, "life_comp.die fallback succeeds")
    _assert_eq(called, true, "life_comp.die was called")
  end)
end)

describe("endgame._resolve_bankruptcy_text", function()
  it("uses_reason_from_opts_when_present", function()
    local player = { name = "玩家A" }
    local text = endgame._resolve_bankruptcy_text(player, { reason = "自定义原因" })
    _assert_eq(text, "自定义原因", "custom reason used")
  end)

  it("falls_back_to_default_text", function()
    local player = { name = "玩家A" }
    local text = endgame._resolve_bankruptcy_text(player, {})
    _assert_eq(text, "玩家A 破产出局", "default text used")
  end)

  it("falls_back_when_opts_nil", function()
    local player = { name = "玩家B" }
    local text = endgame._resolve_bankruptcy_text(player, nil)
    _assert_eq(text, "玩家B 破产出局", "nil opts uses default")
  end)

  it("falls_back_when_reason_empty", function()
    local player = { name = "玩家C" }
    local text = endgame._resolve_bankruptcy_text(player, { reason = "" })
    _assert_eq(text, "玩家C 破产出局", "empty reason uses default")
  end)
end)

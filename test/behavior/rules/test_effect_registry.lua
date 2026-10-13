require("test.bootstrap").install_package_paths()
local luassert = assert
local effect_registry = require("src.rules.effects.registry")

local function _new()
  return effect_registry:new()
end

local function _executor(tag)
  return { apply = function() return tag end }
end

describe("TestEffectRegistry", function()
it("test_register_stores_executor_by_effect_id", function()
  local reg = _new()
  local executor = _executor("buy")
  reg:register("buy_land", executor)
  luassert.truthy(reg:get("buy_land") == executor, "registered executor is retrievable")
end)

it("test_get_unknown_effect_id_returns_nil", function()
  local reg = _new()
  luassert.truthy(reg:get("unknown_effect") == nil, "unknown effect id has no executor")
end)

it("test_register_invalid_executor_raises", function()
  local reg = _new()
  local ok, err = pcall(function()
    reg:register("bad_effect", { apply = "not_a_function" })
  end)
  luassert.is_false(ok, "should raise on executor without apply function")
  luassert.truthy(tostring(err):find("missing executor apply"), "error mentions apply: " .. tostring(err))
end)

it("test_register_many_registers_every_entry", function()
  local reg = _new()
  local buy = _executor("buy")
  local pay = _executor("pay")
  reg:register_many({ buy_land = buy, pay_toll = pay })
  luassert.truthy(reg:get("buy_land") == buy, "first entry registered")
  luassert.truthy(reg:get("pay_toll") == pay, "second entry registered")
end)

it("test_register_many_nil_entries_registers_nothing", function()
  local reg = _new()
  reg:register_many(nil)
  luassert.truthy(reg:get("buy_land") == nil, "nil entries leave registry empty")
end)

it("test_register_defaults_registers_every_group", function()
  local reg = _new()
  local buy = _executor("buy")
  local market = _executor("market")
  reg:register_defaults({
    { buy_land = buy },
    { market = market },
  })
  luassert.truthy(reg:get("buy_land") == buy, "executor from first group registered")
  luassert.truthy(reg:get("market") == market, "executor from second group registered")
end)

it("test_register_defaults_later_group_overrides_same_effect_id", function()
  local reg = _new()
  local first = _executor("first")
  local second = _executor("second")
  reg:register_defaults({
    { buy_land = first },
    { buy_land = second },
  })
  luassert.truthy(reg:get("buy_land") == second, "later group wins for the same effect id")
end)

it("test_register_defaults_nil_groups_registers_nothing", function()
  local reg = _new()
  reg:register_defaults(nil)
  luassert.truthy(reg:get("buy_land") == nil, "nil groups leave registry empty")
end)

it("test_register_defaults_invalid_executor_in_group_raises", function()
  local reg = _new()
  local ok, err = pcall(function()
    reg:register_defaults({ { bad_effect = { apply = nil } } })
  end)
  luassert.is_false(ok, "should raise when a group carries an invalid executor")
  luassert.truthy(tostring(err):find("missing executor apply"), "error mentions apply: " .. tostring(err))
end)


end)

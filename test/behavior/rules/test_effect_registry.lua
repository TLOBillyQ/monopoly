local lu = require("luaunit")
local effect_registry = require("src.rules.effects.registry")

local function _new()
  return effect_registry:new()
end

local function _executor(tag)
  return { apply = function() return tag end }
end

TestEffectRegistry = {}

function TestEffectRegistry:test_register_stores_executor_by_effect_id()
  local reg = _new()
  local executor = _executor("buy")
  reg:register("buy_land", executor)
  lu.assertEvalToTrue(reg:get("buy_land") == executor, "registered executor is retrievable")
end

function TestEffectRegistry:test_get_unknown_effect_id_returns_nil()
  local reg = _new()
  lu.assertEvalToTrue(reg:get("unknown_effect") == nil, "unknown effect id has no executor")
end

function TestEffectRegistry:test_register_invalid_executor_raises()
  local reg = _new()
  local ok, err = pcall(function()
    reg:register("bad_effect", { apply = "not_a_function" })
  end)
  lu.assertFalse(ok, "should raise on executor without apply function")
  lu.assertEvalToTrue(tostring(err):find("missing executor apply"), "error mentions apply: " .. tostring(err))
end

function TestEffectRegistry:test_register_many_registers_every_entry()
  local reg = _new()
  local buy = _executor("buy")
  local pay = _executor("pay")
  reg:register_many({ buy_land = buy, pay_toll = pay })
  lu.assertEvalToTrue(reg:get("buy_land") == buy, "first entry registered")
  lu.assertEvalToTrue(reg:get("pay_toll") == pay, "second entry registered")
end

function TestEffectRegistry:test_register_many_nil_entries_registers_nothing()
  local reg = _new()
  reg:register_many(nil)
  lu.assertEvalToTrue(reg:get("buy_land") == nil, "nil entries leave registry empty")
end

function TestEffectRegistry:test_register_defaults_registers_every_group()
  local reg = _new()
  local buy = _executor("buy")
  local market = _executor("market")
  reg:register_defaults({
    { buy_land = buy },
    { market = market },
  })
  lu.assertEvalToTrue(reg:get("buy_land") == buy, "executor from first group registered")
  lu.assertEvalToTrue(reg:get("market") == market, "executor from second group registered")
end

function TestEffectRegistry:test_register_defaults_later_group_overrides_same_effect_id()
  local reg = _new()
  local first = _executor("first")
  local second = _executor("second")
  reg:register_defaults({
    { buy_land = first },
    { buy_land = second },
  })
  lu.assertEvalToTrue(reg:get("buy_land") == second, "later group wins for the same effect id")
end

function TestEffectRegistry:test_register_defaults_nil_groups_registers_nothing()
  local reg = _new()
  reg:register_defaults(nil)
  lu.assertEvalToTrue(reg:get("buy_land") == nil, "nil groups leave registry empty")
end

function TestEffectRegistry:test_register_defaults_invalid_executor_in_group_raises()
  local reg = _new()
  local ok, err = pcall(function()
    reg:register_defaults({ { bad_effect = { apply = nil } } })
  end)
  lu.assertFalse(ok, "should raise when a group carries an invalid executor")
  lu.assertEvalToTrue(tostring(err):find("missing executor apply"), "error mentions apply: " .. tostring(err))
end


return TestEffectRegistry

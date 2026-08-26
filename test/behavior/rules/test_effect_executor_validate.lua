-- effect_executor.validate 直测:effect_id 非空与 executor 形状守卫。
-- 守卫变异(and→or / ""→nil 同义)只有逐臂断言才能区分。
local lu = require("luaunit")
local luax = require("test.support.luax")

local effect_executor = require("src.rules.effects.executor")

TestEffectExecutorValidate = {}

function TestEffectExecutorValidate:test_accepts_a_valid_executor()
  local ok = effect_executor.validate("mine", { apply = function() end })
  lu.assertEvalToTrue(ok == nil, "validate returns nothing on success")
end

function TestEffectExecutorValidate:test_rejects_a_nil_effect_id()
  luax.has_error(function()
    effect_executor.validate(nil, { apply = function() end })
  end, "missing effect_id")
end

function TestEffectExecutorValidate:test_rejects_an_empty_effect_id()
  luax.has_error(function()
    effect_executor.validate("", { apply = function() end })
  end, "missing effect_id")
end

function TestEffectExecutorValidate:test_rejects_a_non_table_executor()
  luax.has_error(function()
    effect_executor.validate("mine", "not-a-table")
  end, "invalid executor: mine")
end

function TestEffectExecutorValidate:test_rejects_an_executor_without_apply()
  luax.has_error(function()
    effect_executor.validate("mine", {})
  end, "missing executor apply: mine")
end

return TestEffectExecutorValidate

-- effect_executor.validate 直测:effect_id 非空与 executor 形状守卫。
-- 守卫变异(and→or / ""→nil 同义)只有逐臂断言才能区分。
require("test.bootstrap").install_package_paths()
local luassert = assert

local effect_executor = require("src.rules.effects.executor")

describe("TestEffectExecutorValidate", function()
it("test_accepts_a_valid_executor", function()
  local ok = effect_executor.validate("mine", { apply = function() end })
  luassert.truthy(ok == nil, "validate returns nothing on success")
end)

it("test_rejects_a_nil_effect_id", function()
  luassert.has_error(function()
    effect_executor.validate(nil, { apply = function() end })
  end, "missing effect_id")
end)

it("test_rejects_an_empty_effect_id", function()
  luassert.has_error(function()
    effect_executor.validate("", { apply = function() end })
  end, "missing effect_id")
end)

it("test_rejects_a_non_table_executor", function()
  luassert.has_error(function()
    effect_executor.validate("mine", "not-a-table")
  end, "invalid executor: mine")
end)

it("test_rejects_an_executor_without_apply", function()
  luassert.has_error(function()
    effect_executor.validate("mine", {})
  end, "missing executor apply: mine")
end)

end)

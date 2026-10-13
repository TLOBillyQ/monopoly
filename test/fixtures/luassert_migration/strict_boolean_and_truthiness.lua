--- 反例 fixture:严格布尔与 truthiness(#74 断言层迁移试点)。
---
--- 契约见同目录 deep_compare_and_identity.lua 的文件头。
require("test.bootstrap").install_package_paths()

local luassert = assert(require("test.support.luassert_loader").load())

TestLuassertFixtureStrictBooleanAndTruthiness = {}

-- 控制:is_true/is_false 只认真布尔,truthy/falsy 只看 Lua truthiness
-- (0 与 "" 在 Lua 里都是真)——两族断言各自成立,互不代偿。
function TestLuassertFixtureStrictBooleanAndTruthiness:test_control_strict_boolean_and_truthiness_each_hold()
  luassert.is_true(true)
  luassert.is_false(false)
  luassert.truthy(0)
  luassert.truthy("")
  luassert.falsy(nil)
  luassert.falsy(false)
end

-- 反例:is_true 是严格布尔,真值意义上的 1 在这里必须红。LuaUnit 的
-- lu.assertEvalToTrue 是 truthiness,lu.assertFalse 是严格布尔——两个名字互换
-- 都会改变断言语义,这条就是严格侧的证人。
function TestLuassertFixtureStrictBooleanAndTruthiness:test_counterexample_strict_true_rejects_a_truthy_number()
  luassert.is_true(1)
end

return TestLuassertFixtureStrictBooleanAndTruthiness

--- 反例 fixture:nil 与 false 的区分(#74 断言层迁移试点)。
---
--- 契约见同目录 deep_compare_and_identity.lua 的文件头。
require("test.bootstrap").install_package_paths()

local luassert = assert(require("test.support.luassert_loader").load())

TestLuassertFixtureNilAndFalse = {}

-- 控制:nil 与 false 是两件事——is_nil 只收 nil,is_not_nil(false) 为真,
-- is_false(false) 为真;`is.equal(nil, nil)` 也不因 nil 而失效。
function TestLuassertFixtureNilAndFalse:test_control_nil_and_false_are_distinguished()
  luassert.is_nil(nil)
  luassert.is_not_nil(false)
  luassert.is_false(false)
  luassert.is.equal(nil, nil)
end

-- 反例:is_nil 只认 nil,false 必须红。LuaUnit 的 lu.assertNil 同为严格 nil,
-- 但把它译成 is_falsy / truthy 判别就会把 false 一起放过去——这条钉住严格侧。
function TestLuassertFixtureNilAndFalse:test_counterexample_nil_assertion_rejects_false()
  luassert.is_nil(false)
end

return TestLuassertFixtureNilAndFalse

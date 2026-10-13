--- 反例 fixture:表型 error 载荷与类型断言(#74 断言层迁移试点)。
---
--- 契约见同目录 deep_compare_and_identity.lua 的文件头。
require("test.bootstrap").install_package_paths()

local luassert = assert(require("test.support.luassert_loader").load())

-- 抛表型 error:没有位置前缀可剥,has_error 只能走深比较。
local function _boom_table()
  error({ code = 9, kind = "guard" })
end

TestLuassertFixtureErrorTablePayload = {}

-- 控制:表型期望值走深比较;类型断言走 type(),与内容无关。
function TestLuassertFixtureErrorTablePayload:test_control_table_error_payload_deep_compares_and_type_assertions_hold()
  luassert.has_error(_boom_table, { code = 9, kind = "guard" })
  luassert.is_table({})
  luassert.is_string("x")
  luassert.is_number(1)
end

-- 反例:表型载荷深比较不等必须红(不能因为「类型都是 table」就放过)。
function TestLuassertFixtureErrorTablePayload:test_counterexample_mismatched_table_error_payload_fails()
  luassert.has_error(_boom_table, { code = 8, kind = "guard" })
end

return TestLuassertFixtureErrorTablePayload

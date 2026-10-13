--- 反例 fixture:异常模式(#74 断言层迁移试点)。
---
--- 契约见同目录 deep_compare_and_identity.lua 的文件头。
require("test.bootstrap").install_package_paths()

local luassert = assert(require("test.support.luassert_loader").load())

-- 抛真实项目里的边界断言文本,带冒号与数字,用来验模式匹配不被前缀干扰。
local function _boom()
  error("remove_by_index: index out of bounds: 7")
end

TestLuassertFixtureErrorPattern = {}

-- 控制:has_error.match 走 Lua 模式(`%d+` 是量词);第 4 参 plain=true 时退化成
-- 子串匹配——后者正是 LuaUnit 的 lu.assertErrorMsgContains 口径。
function TestLuassertFixtureErrorPattern:test_control_error_pattern_and_plain_substring_both_match()
  luassert.has_error.match(_boom, "index out of bounds: %d+")
  luassert.has_error.match(_boom, "out of bounds: 7", 1, true)
end

-- 反例:模式在剥前缀后的报错文本里不存在必须红。
function TestLuassertFixtureErrorPattern:test_counterexample_non_matching_error_pattern_fails()
  luassert.has_error.match(_boom, "NEVER_MATCHES_THIS_PATTERN", 1, true)
end

return TestLuassertFixtureErrorPattern

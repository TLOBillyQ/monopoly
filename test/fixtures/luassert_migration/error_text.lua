--- 反例 fixture:异常文本(#74 断言层迁移试点)。
---
--- 契约见同目录 deep_compare_and_identity.lua 的文件头。
require("test.bootstrap").install_package_paths()

local luassert = assert(require("test.support.luassert_loader").load())

-- 抛真实项目里的中文断言文本,顺带覆盖非 ASCII 报错内容的比对。
local function _boom()
  error("余额不足: -1")
end

TestLuassertFixtureErrorText = {}

-- 控制:has_error 的文本期望值是精确比较,且先剥掉一层 `文件:行: ` 位置前缀
-- (前缀里的冒号不会被误剥——剥的是第一处 `:数字: `)。
function TestLuassertFixtureErrorText:test_control_error_text_matches_exactly_after_location_stripping()
  luassert.has_error(_boom, "余额不足: -1")
  luassert.has_error(function()
    error("plain", 0)
  end, "plain")
end

-- 反例:期望文本与实抛文本不同必须红——has_error 不是子串匹配。LuaUnit 的
-- lu.assertErrorMsgContains 才是子串口径,直译成 has_error 会从子串收窄成精确,
-- 这条钉住精确侧(子串口径走 has_error.match 的 plain 模式)。
function TestLuassertFixtureErrorText:test_counterexample_wrong_expected_error_text_fails()
  luassert.has_error(_boom, "余额不足")
end

return TestLuassertFixtureErrorText

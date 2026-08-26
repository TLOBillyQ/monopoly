-- suite_flatten.lua —— 套件 case 表拍平成 LuaUnit 类方法的共享 helper(#322 收尾 3)。
--
-- 背景:packages/{arch_view,mutate}/test/test_script_tools_contract.lua 曾各内联
-- 一份近逐字节相同的双循环拍平(suite.tests + suite.tooling_tests 按 owner 过滤,
-- 每个 case 生成一个 test_ 前缀方法)。本 helper 把拍平收敛为单点,调用方只给
-- 类表、套件模块与 owner。encoding/ops/spec_lane 等既有文件形态相同,可自愿迁用,
-- 不强制统一(#322 只收敛 arch_view/mutate 两份)。
--
-- 契约:套件模块须提供 cases_for_owner(cases, owner) 与 tests/tooling_tests 两张
-- case 表;case = { name = <string>, run = <function> }。生成的方法形如
-- function(self) case.run() end —— self 形参保留以对齐 LuaUnit 方法调用约定,
-- 方法名 test_ 前缀是 LuaUnit 发现要求。
local M = {}

function M.flatten_owner_cases(class, suite, owner)
  for _, cases in ipairs({ suite.tests, suite.tooling_tests }) do
    for _, case in ipairs(suite.cases_for_owner(cases, owner)) do
      class["test_" .. case.name] = function(self)
        case.run()
      end
    end
  end
  return class
end

return M

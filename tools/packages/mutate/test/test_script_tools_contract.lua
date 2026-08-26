if arg then rawset(arg, 0, "tools/packages/mutate/test/test_script_tools_contract.lua") end
local suite = require("test.support.tooling_suites.architecture.script_tools_contract")
local flatten = require("test.support.tooling_suites.suite_flatten")

-- 原生 LuaUnit 迁移:套件循环拍平 —— 每个 case 生成一个 test_ 前缀方法
-- (LuaUnit 方法名必须以 test 开头),无参调用 case.run()。拍平双循环已随
-- #322 收尾 3 收敛进 test.support.tooling_suites.suite_flatten 单点。
--
-- wrappers 薄壳包迁(#311/#320)前为 tools/quality/mutate/test/ 与合并的
-- wrappers/test/ 各一份;随包退场迁入 packages/mutate/test/,只过滤 owner =
-- mutate 的用例(arch 侧用例已随包迁入 packages/arch_view/test/)。

TestScriptToolsContractMutate = flatten.flatten_owner_cases({}, suite, "mutate")

return TestScriptToolsContractMutate

---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/foundation/test/test_platform_boundary.lua") end
require("test.bootstrap").install_package_paths()

-- 平台保证边界(#96 / 母规格 #69 / ADR 0066)的唯一真源:dry(结构重复检测)与
-- acceptance-mutate(中文验收变异)当前按 POSIX 专用能力声明。本套件只钉纯演算面
-- ——分类结果(不可用 / 显式跳过 / 放行)、退出码与诊断文案;真跑 CLI 的窄反馈在
-- 各包自己的 cli 用例里(real CLI,不是替身)。
local lu = require("luaunit")
local boundary = require("foundation.platform_boundary")

TestPlatformBoundary = {}

-- 反例:原生 Windows 上请求 dry 必须判「不可用」,而不是放行给上游装作跑过。
function TestPlatformBoundary:test_declares_the_posix_only_capability_unavailable_on_windows()
  local verdict = boundary.evaluate("dry", { "src" }, "windows")

  lu.assertEquals(verdict.status, boundary.UNAVAILABLE)
  lu.assertEquals(verdict.exit_code, boundary.UNAVAILABLE_EXIT_CODE)
  lu.assertIs(verdict.stream, "stderr")
  lu.assertEvalToTrue(verdict.message:find("status=unavailable", 1, true) ~= nil,
    "诊断要带可机读的状态词: " .. tostring(verdict.message))
end

-- 正例:PASS 之外的平台(能力声明支持的 POSIX)不下判定,请求原样交给真实工具。
function TestPlatformBoundary:test_leaves_a_supported_platform_request_to_the_real_tool()
  local verdict = boundary.evaluate("dry", { "src", "--json" }, "posix")

  lu.assertIs(verdict.status, nil)
  lu.assertIs(verdict.exit_code, nil)
  lu.assertEquals(verdict.args, { "src", "--json" })
end

-- 不可用与显式跳过必须是两个可区分的状态(输出流 + 状态词 + 退出码都不同)。
function TestPlatformBoundary:test_explicit_skip_is_distinguishable_from_unavailable()
  local unavailable = boundary.evaluate("dry", { "src" }, "windows")
  local skipped = boundary.evaluate("dry", { "--skip-if-unavailable", "src" }, "windows")

  lu.assertEquals(skipped.status, boundary.SKIPPED)
  lu.assertEquals(skipped.exit_code, boundary.SKIPPED_EXIT_CODE)
  lu.assertIs(skipped.stream, "stdout")
  lu.assertEvalToTrue(skipped.message:find("status=skipped", 1, true) ~= nil,
    tostring(skipped.message))
  lu.assertNotEquals(skipped.status, unavailable.status)
  lu.assertNotEquals(skipped.exit_code, unavailable.exit_code)
  lu.assertNotEquals(skipped.stream, unavailable.stream)
end

-- 跳过开关由本模块消费:漏给上游会被当成未知选项退 2(把平台边界伪装成用法错误)。
function TestPlatformBoundary:test_strips_the_skip_flag_before_forwarding()
  local verdict = boundary.evaluate("dry", { "--skip-if-unavailable", "--json", "src" }, "posix")

  lu.assertIs(verdict.status, nil)
  lu.assertEquals(verdict.args, { "--json", "src" })
end

function TestPlatformBoundary:test_declares_acceptance_mutate_on_the_same_boundary()
  local verdict = boundary.evaluate("acceptance-mutate", { "--level", "soft" }, "windows")

  lu.assertEquals(verdict.status, boundary.UNAVAILABLE)
  lu.assertEquals(verdict.exit_code, boundary.UNAVAILABLE_EXIT_CODE)
  lu.assertEvalToTrue(verdict.message:find("acceptance-mutate", 1, true) ~= nil,
    tostring(verdict.message))
end

-- 未登记的能力名一律大声失败:拼错的能力 id 静默放行等于边界形同虚设。
function TestPlatformBoundary:test_rejects_an_undeclared_capability()
  lu.assertError(function()
    boundary.evaluate("dryy", {}, "windows")
  end)
end

-- ADR 0066:原生 Windows 是唯一受支持的开发平台。这条断言在别的平台上红,
-- 是显式事实而不是注释里的约定。
function TestPlatformBoundary:test_reports_the_host_platform_as_windows()
  lu.assertEquals(boundary.host_platform(), "windows")
end

-- 退出码约定扩展(#300 Q2 → #96):0 成功 / 1 业务失败 / 2 用法错误 / 3 不可用。
-- 三态必须互不相同,否则调用方分不清「工具没跑」与「工具跑了但失败」。
function TestPlatformBoundary:test_exit_codes_separate_unavailable_from_usage_and_failure()
  lu.assertEquals(boundary.UNAVAILABLE_EXIT_CODE, 3)
  lu.assertNotEquals(boundary.UNAVAILABLE_EXIT_CODE, 0)
  lu.assertNotEquals(boundary.UNAVAILABLE_EXIT_CODE, 1)
  lu.assertNotEquals(boundary.UNAVAILABLE_EXIT_CODE, 2)
end

return TestPlatformBoundary

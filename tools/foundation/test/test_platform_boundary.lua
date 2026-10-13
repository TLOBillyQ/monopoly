---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/foundation/test/test_platform_boundary.lua") end
require("test.bootstrap").install_package_paths()

-- 平台保证边界(#96 / 母规格 #69 / ADR 0066)的唯一真源:dry(结构重复检测)与
-- acceptance-mutate(中文验收变异)当前按 POSIX 专用能力声明。本套件只钉纯演算面
-- ——分类结果(不可用 / 显式跳过 / 放行)、退出码与诊断文案;真跑 CLI 的窄反馈在
-- 各包自己的 cli 用例里(real CLI,不是替身)。
local check = require("luassert")
local boundary = require("foundation.platform_boundary")

describe("platform boundary", function()

-- 反例:原生 Windows 上请求 dry 必须判「不可用」,而不是放行给上游装作跑过。
it("declares the posix only capability unavailable on windows", function()
  local verdict = boundary.evaluate("dry", { "src" }, "windows")

  check.same(verdict.status, boundary.UNAVAILABLE)
  check.same(verdict.exit_code, boundary.UNAVAILABLE_EXIT_CODE)
  check.equal(verdict.stream, "stderr")
  check.truthy(verdict.message:find("status=unavailable", 1, true) ~= nil,
    "诊断要带可机读的状态词: " .. tostring(verdict.message))
end)

-- 正例:PASS 之外的平台(能力声明支持的 POSIX)不下判定,请求原样交给真实工具。
it("leaves a supported platform request to the real tool", function()
  local verdict = boundary.evaluate("dry", { "src", "--json" }, "posix")

  check.equal(verdict.status, nil)
  check.equal(verdict.exit_code, nil)
  check.same(verdict.args, { "src", "--json" })
end)

-- 不可用与显式跳过必须是两个可区分的状态(输出流 + 状态词 + 退出码都不同)。
it("explicit skip is distinguishable from unavailable", function()
  local unavailable = boundary.evaluate("dry", { "src" }, "windows")
  local skipped = boundary.evaluate("dry", { "--skip-if-unavailable", "src" }, "windows")

  check.same(skipped.status, boundary.SKIPPED)
  check.same(skipped.exit_code, boundary.SKIPPED_EXIT_CODE)
  check.equal(skipped.stream, "stdout")
  check.truthy(skipped.message:find("status=skipped", 1, true) ~= nil,
    tostring(skipped.message))
  check.is_not.same(skipped.status, unavailable.status)
  check.is_not.same(skipped.exit_code, unavailable.exit_code)
  check.is_not.same(skipped.stream, unavailable.stream)
end)

-- 跳过开关由本模块消费:漏给上游会被当成未知选项退 2(把平台边界伪装成用法错误)。
it("strips the skip flag before forwarding", function()
  local verdict = boundary.evaluate("dry", { "--skip-if-unavailable", "--json", "src" }, "posix")

  check.equal(verdict.status, nil)
  check.same(verdict.args, { "--json", "src" })
end)

it("declares acceptance mutate on the same boundary", function()
  local verdict = boundary.evaluate("acceptance-mutate", { "--level", "soft" }, "windows")

  check.same(verdict.status, boundary.UNAVAILABLE)
  check.same(verdict.exit_code, boundary.UNAVAILABLE_EXIT_CODE)
  check.truthy(verdict.message:find("acceptance-mutate", 1, true) ~= nil,
    tostring(verdict.message))
end)

-- 未登记的能力名一律大声失败:拼错的能力 id 静默放行等于边界形同虚设。
it("rejects an undeclared capability", function()
  check.has_error(function()
    boundary.evaluate("dryy", {}, "windows")
  end)
end)

-- ADR 0066:原生 Windows 是唯一受支持的开发平台。这条断言在别的平台上红,
-- 是显式事实而不是注释里的约定。
it("reports the host platform as windows", function()
  check.same(boundary.host_platform(), "windows")
end)

-- 退出码约定扩展(#300 Q2 → #96):0 成功 / 1 业务失败 / 2 用法错误 / 3 不可用。
-- 三态必须互不相同,否则调用方分不清「工具没跑」与「工具跑了但失败」。
it("exit codes separate unavailable from usage and failure", function()
  check.same(boundary.UNAVAILABLE_EXIT_CODE, 3)
  check.is_not.same(boundary.UNAVAILABLE_EXIT_CODE, 0)
  check.is_not.same(boundary.UNAVAILABLE_EXIT_CODE, 1)
  check.is_not.same(boundary.UNAVAILABLE_EXIT_CODE, 2)
end)

it("retained test capabilities partition only the named engine files", function()
  local excluded, selected = {}, {}
  local files = require("foundation.proc").collect_files("tools/packages/acceptance_mutate/test", ".lua")
  for _, file in ipairs(files) do
    local verdict = boundary.test_verdict(file)
    if verdict then excluded[#excluded + 1] = verdict else selected[#selected + 1] = file end
  end
  check.same(#excluded, 2)
  check.same(#selected + #excluded, #files)
  local cases = 0
  for _, verdict in ipairs(excluded) do
    check.same(verdict.exit_code, 3)
    check.same(boundary.test_capabilities[verdict.identity], "acceptance-mutate")
    cases = cases + verdict.cases
  end
  check.same(cases, 14)
  check.is_nil(boundary.test_verdict("tools/packages/acceptance_mutate/test/test_mutator_status_format.lua"))
  check.is_nil(boundary.test_verdict("tools/packages/acceptance_mutate/test/test_mutator_report_skipped.lua"))
end)

end)

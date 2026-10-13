---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/packages/acceptance_mutate/test/test_acceptance_mutate_cli.lua") end

require("test.bootstrap").install_package_paths()

-- acceptance-mutate 的真实 CLI 窄反馈(#96 / 母规格 #69 / ADR 0066)。
-- 中文验收变异当前是规格声明的 POSIX 专用能力:原生 Windows 上请求时必须给出
-- 可辨认的不可用诊断,不安装、不 spawn、不把基础设施故障伪装成变异结果。
--
-- 被这条边界挡住的旧行为是:车道健康探针把 job 经 stdin 喂给 runner_worker,
-- 而探针在此之前已经跑过 ensure_tool 装工具;在原生 Windows 上那一串子进程会把
-- 进程 stdin 抽干,于是 runner_worker 读不到任何 job、什么都不吐,车道报
-- 「runner_worker 没吐出可解析的 job 响应」——一条把基础设施故障说成变异失败的
-- 假诊断。本票不去修那条链(移交范围外),只保证它不再被当作变异结论。
local lu = require("luaunit")
local proc_lib = require("foundation.proc")

local CLI = "tools/cli.lua"
local LANE = "tools/packages/acceptance_mutate/mutate_lane.lua"

-- 探针误诊文案:它出现即说明车道真的跑进了 POSIX 专用链。
local PROBE_MISDIAGNOSIS = "runner_worker 没吐出可解析的 job 响应"

local function _run(tail)
  local command = { "lua", CLI, "acceptance-mutate" }
  for _, value in ipairs(tail) do
    command[#command + 1] = value
  end
  return proc_lib.run_command(command)
end

TestAcceptanceMutateCli = {}

-- 正例:--help 仍然有用(退出码 0),并说清能力边界与逃生开关。
function TestAcceptanceMutateCli:test_help_stays_useful_and_states_the_windows_boundary()
  local result = _run({ "--help" })

  lu.assertEquals(result.code, 0, result.output)
  lu.assertEvalToTrue(result.output:find("acceptance-mutate", 1, true) ~= nil, result.output)
  lu.assertEvalToTrue(result.output:find("--skip-if-unavailable", 1, true) ~= nil,
    "帮助要写出显式跳过开关: " .. result.output)
  lu.assertEvalToTrue(result.output:find("status=skipped", 1, true) ~= nil,
    "帮助要写出跳过状态词: " .. result.output)
end

-- 反例(本票核心):显式请求判「不可用」,而不是让探针把假诊断当结论。
function TestAcceptanceMutateCli:test_an_explicit_request_is_unavailable_not_a_mutation_verdict()
  local result = _run({ "--level", "soft" })

  lu.assertEquals(result.code, 3, result.output)
  lu.assertEvalToTrue(result.output:find("status=unavailable", 1, true) ~= nil,
    "诊断要带可机读状态词: " .. result.output)
  lu.assertEvalToTrue(result.output:find("POSIX", 1, true) ~= nil,
    "诊断要点明 POSIX 专用: " .. result.output)
  lu.assertNil(result.output:find(PROBE_MISDIAGNOSIS, 1, true),
    "不可用路径不得给出探针误诊: " .. result.output)
end

-- 显式跳过:调用方确认边界后跳过,状态与退出码都与不可用不同。
function TestAcceptanceMutateCli:test_an_explicit_skip_exits_zero_with_a_skipped_status()
  local result = _run({ "--skip-if-unavailable", "--level", "soft" })

  lu.assertEquals(result.code, 0, result.output)
  lu.assertEvalToTrue(result.output:find("status=skipped", 1, true) ~= nil,
    "跳过要带可机读状态词: " .. result.output)
  lu.assertNil(result.output:find(PROBE_MISDIAGNOSIS, 1, true), result.output)
end

-- 脚本形态入口(cli 以子进程转发的真实入口)与 CLI 同口径:旁门不许假绿。
function TestAcceptanceMutateCli:test_the_lane_script_form_reports_the_same_boundary()
  local result = proc_lib.run_command({ "lua", LANE, "--level", "soft" })

  lu.assertEquals(result.code, 3, result.output)
  lu.assertEvalToTrue(result.output:find("status=unavailable", 1, true) ~= nil, result.output)
  lu.assertNil(result.output:find(PROBE_MISDIAGNOSIS, 1, true), result.output)
end

return TestAcceptanceMutateCli

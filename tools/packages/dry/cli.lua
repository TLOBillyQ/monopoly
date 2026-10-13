-- packages/dry/cli.lua —— dry 子命令(wayfinder #304 骨架 / #320 包退场)
--
-- 统一接口形态(#300 决议):本文件 return 纯接口模块:
--   M.main(args, env) -> 退出码(0 成功 / 1 业务失败 / 2 用法错误)
--   M.usage()         -> 完整 usage 文本(包内单一真源,顶层 <cmd> --help 转发)
--
-- 实现(#320/#322):薄壳已随包迁落位,进程内调用 packages.dry.runner(不再
-- 子进程转发 tools/wrappers/dry.lua);进程内适配收敛在 foundation.tool_cli
-- 单点。runner.lua 顶部的 script_bootstrap + ensure_tool 是唯一一次引导
-- (原 cli 侧重做的双重 bootstrap 形态已随 #322 消亡),runner 同时保留
-- CLI 脚本形态,供 verify/lint 类直接以入口引用。
--
-- 平台保证边界(#96):dry 当前按 POSIX 专用能力声明,原生 Windows 上不可用。
-- 判定与诊断收在 foundation.platform_boundary 一处,且必须发生在 tool_cli.run
-- 之前 —— runner 顶部的 ensure_tool 会先从私有 Gitea 装工具,再让上游的
-- `find` + `2>/dev/null` 扫描静默零候选退 0;把边界挡在装工具之前,才不会
-- 出现「一次扫描都没跑却报通过」。
local M = {}

local tool_cli = require("foundation.tool_cli")
local platform_boundary = require("foundation.platform_boundary")

local RUN_OPTS = {
  runner_module = "packages.dry.runner",
  runner_script = "tools/packages/dry/runner.lua",
}

function M.usage()
  return table.concat({
    "用法: lua tools/cli.lua dry [args...]",
    "",
    "结构重复检测(软车道,dry4lua):抽函数 / 重构前扫候选;选项经 args 直通。",
    "详细语义见 dry skill 与 tools/packages/dry/runner.lua。",
    "",
    "平台保证边界(#96 / ADR 0066):本能力当前按 POSIX 专用能力声明,",
    "原生 Windows 不在保证面内 —— 请求时打印 status=unavailable 并退 3,",
    "不安装工具、不运行、不报通过(退出码约定:0 成功 / 1 业务失败 / 2 用法错误 / 3 不可用)。",
    "确认边界后要显式跳过,加 --skip-if-unavailable:打印 status=skipped 并退 0;",
    "它记录的是「不在这条平台上跑」,不代表检测通过。",
    "",
  }, "\n") .. "\n"
end

function M.main(args, env)
  for _, value in ipairs(args or {}) do
    if value == "--help" or value == "-h" then
      io.write(M.usage())
      return 0
    end
  end
  local verdict = platform_boundary.evaluate("dry", args)
  if verdict.status ~= nil then
    return platform_boundary.emit(verdict)
  end
  return tool_cli.run(RUN_OPTS, verdict.args, env)
end

return M

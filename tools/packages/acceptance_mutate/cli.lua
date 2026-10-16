-- packages/acceptance_mutate/cli.lua —— acceptance-mutate 子命令
-- (wayfinder #310 包内实现)
--
-- 统一接口形态(#300 决议):本文件 return 纯接口模块:
--   M.main(args, env) -> 退出码(0 成功 / 1 业务失败 / 2 用法错误)
--   M.usage()         -> 完整 usage 文本(包内单一真源,顶层 <cmd> --help 转发)
--
-- 实现：转发到包内软车道入口 mutate_lane.lua（与 mutate
-- 并列的独立软车道;mutator 薄壳 mutator.lua 同住本包)。
--
-- 平台保证边界(#96):中文验收变异当前按 POSIX 专用能力声明,原生 Windows 上
-- 不可用。判定与诊断收在 foundation.platform_boundary 一处,且必须发生在
-- _forward 之前 —— 车道入口的探针链会先装工具、再经 stdin 喂 job 给
-- runner_worker,在原生 Windows 上只会回一条把基础设施故障说成变异失败的假诊断。
local M = {}
local shell = require("foundation.shell")
local lua54 = require("foundation.lua54")

local ENTRY = "tools/packages/acceptance_mutate/mutate_lane.lua"

-- 子进程转发:spawn 现状入口,退出码透传(入口自带 os.exit,语义即本包语义)。
local function _forward(args)
  local parts = { lua54.lua54_bin(), ENTRY }
  for _, value in ipairs(args or {}) do
    parts[#parts + 1] = shell.shell_quote(value)
  end
  local ok, how, code = os.execute(table.concat(parts, " "))
  if how == "exit" then
    return code or (ok and 0 or 1)
  end
  return 1
end

function M.usage()
  return table.concat({
    "用法: lua tools/cli.lua acceptance-mutate [args...]",
    "",
    "验收突变软车道（与 mutate / dry 同级）：对验收数据面跑",
    "变异,选项经 args 直通(如 --level soft / --feature <feature>)。",
    "详细语义见 tools/packages/acceptance_mutate/mutate_lane.lua。",
    "",
    "原生 Windows 支持:真实消费 worker job 并报告 total/killed/survived/errors。",
    "退出码:0 成功 / 1 变异失败 / 2 用法错误 / 3 工具自举不可用。",
    "--skip-if-unavailable 保留兼容并消费;当前平台受支持时照常执行,网络不可用仍退 3。",
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
  return _forward(args)
end

return M

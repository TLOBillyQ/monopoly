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

local platform_boundary = require("foundation.platform_boundary")

local ENTRY = "tools/packages/acceptance_mutate/mutate_lane.lua"

local function _shell_quote(value)
  local text = tostring(value or "")
  return "'" .. text:gsub("'", "'\\''") .. "'"
end

-- 子进程转发:spawn 现状入口,退出码透传(入口自带 os.exit,语义即本包语义)。
local function _forward(args)
  local parts = { "lua", ENTRY }
  for _, value in ipairs(args or {}) do
    parts[#parts + 1] = _shell_quote(value)
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
    "平台保证边界(#96 / ADR 0066):本能力当前按 POSIX 专用能力声明,",
    "原生 Windows 不在保证面内 —— 请求时打印 status=unavailable 并退 3,",
    "不安装工具、不 spawn、不给变异结论(退出码约定:0 成功 / 1 业务失败 / 2 用法错误 / 3 不可用)。",
    "确认边界后要显式跳过,加 --skip-if-unavailable:打印 status=skipped 并退 0;",
    "它记录的是「不在这条平台上跑」,不代表变异通过。",
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
  local verdict = platform_boundary.evaluate("acceptance-mutate", args)
  if verdict.status ~= nil then
    return platform_boundary.emit(verdict)
  end
  return _forward(verdict.args)
end

return M

-- packages/arch_view/cli.lua —— arch-view 子命令(wayfinder #304 骨架 / #320)
--
-- 统一接口形态(#300 决议):本文件 return 纯接口模块:
--   M.main(args, env) -> 退出码(0 成功 / 1 业务失败 / 2 用法错误)
--   M.usage()         -> 完整 usage 文本(包内单一真源,顶层 <cmd> --help 转发)
--
-- 实现(#311/#320/#322):薄壳已随包迁落位,进程内调用 packages.arch_view.runner
-- (不再子进程转发 tools/wrappers/arch_view.lua);进程内适配收敛在
-- foundation.tool_cli 单点。入口无参数默认执行 check，
-- args 原样透传。
local M = {}

local tool_cli = require("foundation.tool_cli")

local RUN_OPTS = {
  runner_module = "packages.arch_view.runner",
  runner_script = "tools/packages/arch_view/runner.lua",
}

function M.usage()
  return table.concat({
    "用法: lua tools/cli.lua arch-view [check] [args...]",
    "",
    "静态架构扫描（arch_view）：默认 check；viewer / scan 等",
    "子命令经 args 直通。详细语义见 arch-view skill 与 packages/arch_view/runner.lua。",
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
  return tool_cli.run(RUN_OPTS, args, env)
end

return M

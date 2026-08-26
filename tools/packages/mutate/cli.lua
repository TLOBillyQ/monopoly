-- packages/mutate/cli.lua —— mutate 子命令(wayfinder #304 骨架 / #320 包退场)
--
-- 统一接口形态(#300 决议):本文件 return 纯接口模块:
--   M.main(args, env) -> 退出码(0 成功 / 1 业务失败 / 2 用法错误)
--   M.usage()         -> 完整 usage 文本(包内单一真源,顶层 <cmd> --help 转发)
--
-- 实现(#311/#320/#322):薄壳已随包迁落位,进程内调用 packages.mutate.runner
-- (不再子进程转发 tools/wrappers/mutate.lua);进程内适配收敛在
-- foundation.tool_cli 单点。runner 负责 bootstrap + Lua 5.4 门禁 + 直调上游。
local M = {}

local tool_cli = require("foundation.tool_cli")

local RUN_OPTS = {
  runner_module = "packages.mutate.runner",
  runner_script = "tools/packages/mutate/runner.lua",
}

function M.usage()
  return table.concat({
    "用法: lua tools/cli.lua mutate <文件> [--update-manifest|--since-last-run|--mutate-all]",
    "",
    "单文件变异测试(软车道):验证测试是否够锋利、能杀掉简单 bug。引擎为",
    "mutate4lua v4（manifest 内嵌源文件 footer）；--since-last-run /",
    "--mutate-all 语义见 mutate skill 与 packages/mutate/runner.lua。",
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

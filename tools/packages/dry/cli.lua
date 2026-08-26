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
local M = {}

local tool_cli = require("foundation.tool_cli")

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

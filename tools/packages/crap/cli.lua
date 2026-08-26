-- packages/crap/cli.lua —— crap 子命令(wayfinder #304 骨架 / #320 包退场)
--
-- 统一接口形态(#300 决议):本文件 return 纯接口模块:
--   M.main(args, env) -> 退出码(0 成功 / 1 业务失败 / 2 用法错误)
--   M.usage()         -> 完整 usage 文本(包内单一真源,顶层 <cmd> --help 转发)
--
-- 实现(#311/#320/#322):薄壳已随包迁落位,进程内调用 packages.crap.runner
-- (不再子进程转发 tools/wrappers/crap.lua);进程内适配(require runner →
-- 归一化退出码 → 子进程兜底)收敛在 foundation.tool_cli 单点;env merge 落点
-- 在 runner 侧(#323),cli 只透传。
local M = {}

local tool_cli = require("foundation.tool_cli")
local lua54_lib = require("packages.luaunit_runner.lua54")

local RUN_OPTS = {
  runner_module = "packages.crap.runner",
  runner_script = "tools/packages/crap/runner.lua",
}

-- 纯判定(#453):PATH 上的 lua 可能是 5.5(macOS homebrew 默认),crap4lua 的
-- luacov 适配进程内 require cluacov C hook(5.4 ABI)会 Segfault(exit 139)。
-- 非 5.4 解释器一律改走钉定 lua5.4 子进程跑 runner 脚本(与 mutate
-- lua54_guard #203 同款判定,复用 tool_cli 子进程兜底而非自造 re-exec)。
-- 工具链车道(spec-lane / verify)都以 lua5.4 启动本进程,此分支只在
-- `lua tools/cli.lua crap ...` 由 PATH 上非 5.4 的 lua 直调时命中。
function M.needs_lua54_reexec(version)
  return version ~= "Lua 5.4"
end

function M.usage()
  return table.concat({
    "用法: lua tools/cli.lua crap [args...]",
    "",
    "CRAP 风险热点 + 覆盖率聚合(软车道,crap4lua):无参数默认 report;",
    "选项经 args 直通(analyze / gate 等子命令见 crap skill)。",
    "详细语义见 crap skill 与 packages/crap/runner.lua。",
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
  if M.needs_lua54_reexec(_VERSION) then
    local bin = lua54_lib.detect_lua54()
    if bin == nil then
      io.stderr:write("crap 车道中止:找不到 Lua 5.4 解释器(可用 LUA54_BIN 指定)。\n")
      io.stderr:write("crap lane aborted: no Lua 5.4 interpreter found (set LUA54_BIN to override).\n")
      return 1
    end
    return tool_cli.forward_subprocess(RUN_OPTS.runner_script, args, bin)
  end
  return tool_cli.run(RUN_OPTS, args, env)
end

return M

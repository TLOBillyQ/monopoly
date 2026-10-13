local _self = debug.getinfo(1, "S").source or "@tools/packages/dry/runner.lua"
local _sb = dofile(_self:gsub("\\", "/"):gsub("^@", ""):match("^(.*)/[^/]+$")
  .. "/../../foundation/script_bootstrap.lua")
local bootstrap_env, bootstrap = _sb.install("tools/packages/dry", _self)

local is_module = ... == "packages.dry.runner"

-- 平台保证边界(#96):脚本形态与 packages.dry.cli 走同一份声明,且判定必须
-- 发生在 ensure_tool 之前 —— 否则会先装一遍 POSIX 专用工具,再让上游的
-- `find` + `2>/dev/null` 静默零候选退 0,把边界故障报成「没有重复」。
-- 模块形态不必在此判定:唯一装载方 packages.dry.cli 已经先判过了。
local platform_boundary = require("foundation.platform_boundary")
local verdict = nil
if not is_module then
  verdict = platform_boundary.evaluate("dry", arg or {})
  if verdict.status ~= nil then
    os.exit(platform_boundary.emit(verdict))
  end
end

assert(bootstrap.ensure_tool("dry4lua", bootstrap_env))

local cli = require("dry4lua.cli")

-- 模块形态(#322):供 packages.dry.cli 经 foundation.tool_cli 进程内直调,
-- bootstrap + ensure_tool 只在本文件顶部做一次(原 cli 侧 _bootstrap_dry_tool
-- 重做一遍的双重 bootstrap 形态已消亡)。dry4lua.cli.run(args) 返回数字退出码,
-- 无 env 契约,env 形参接收后忽略。
if is_module then
  return { run = function(args) return cli.run(args or {}) end }
end

os.exit(cli.run(verdict.args))

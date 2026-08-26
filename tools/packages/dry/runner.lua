local _self = debug.getinfo(1, "S").source or "@tools/packages/dry/runner.lua"
local _sb = dofile(_self:gsub("\\", "/"):gsub("^@", ""):match("^(.*)/[^/]+$")
  .. "/../../foundation/script_bootstrap.lua")
local bootstrap_env, bootstrap = _sb.install("tools/packages/dry", _self)
assert(bootstrap.ensure_tool("dry4lua", bootstrap_env))

local cli = require("dry4lua.cli")

-- 模块形态(#322):供 packages.dry.cli 经 foundation.tool_cli 进程内直调,
-- bootstrap + ensure_tool 只在本文件顶部做一次(原 cli 侧 _bootstrap_dry_tool
-- 重做一遍的双重 bootstrap 形态已消亡)。dry4lua.cli.run(args) 返回数字退出码,
-- 无 env 契约,env 形参接收后忽略。
if ... == "packages.dry.runner" then
  return { run = function(args) return cli.run(args or {}) end }
end

os.exit(cli.run(arg or {}))

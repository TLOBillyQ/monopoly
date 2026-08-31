local _self = debug.getinfo(1, "S").source or "@tools/packages/mutate/runner.lua"
local _sb = dofile(_self:gsub("\\", "/"):gsub("^@", ""):match("^(.*)/[^/]+$")
  .. "/../../foundation/script_bootstrap.lua")
local bootstrap_env, bootstrap = _sb.install("tools/packages/mutate", _self)
local REPO_ROOT = bootstrap_env.repo_root
local mutate_tool = assert(bootstrap.ensure_tool("mutate4lua", bootstrap_env))
-- cluacov:luacov 的 C hook 加速器。归因矩阵构建在全套 spec 上挂 line hook,
-- 纯 Lua 路径是 mutate wall 热点;ensure 把 .so 落进 tree,lua54_guard 再把
-- LUA_CPATH 注给内建 runner 子进程。装不上时硬失败——与 ensure_luacov_tree
-- 同口径,避免「以为启用了其实静默回退」。
local cluacov_ok, cluacov_err = bootstrap.ensure_cluacov_tree(REPO_ROOT)
if cluacov_ok ~= true then
  io.stderr:write("mutate: cannot ensure cluacov: " .. tostring(cluacov_err) .. "\n")
  os.exit(1)
end
require("packages.mutate.mutate4lua_paths").activate(mutate_tool.root)
local tool_cli = require("foundation.tool_cli")

-- 工具经 tools/tools.lock 跟随上游主干，.toolcache/luarocks tree 是唯一装载面。
-- tools/tools.lock 跟随的上游自 v0.1.0 起内建 luaunit runner，宿主 driver 选项已整组删除；
-- spec 补 return 后由内建 runner 原生直跑。
local _env = {
  cwd = REPO_ROOT, command_name = "tools/packages/mutate/runner.lua",
  tool_root = mutate_tool.root,
}

-- Lua 5.4 门禁(issue #203 / #325):引擎以字面量 "lua" 起内建 runner 子进程,
-- PATH 上 lua 为 5.5 时整条车道假红。两种形态必须走同一门禁——脚本形态
-- re-exec 到钉定解释器并注入 shim PATH；require 形态经 tool_cli 进程内委托，
-- cli.lua → tool_cli in-process 直调)同样判定,re-exec 已由子进程完整跑完
-- mutate 车道,退出码透传即可(#325:require 形态曾绕过门禁,5.5 进程内直跑
-- 引擎,shim PATH 注入从不生效)。
-- guard_impl 可注入(契约 suite 直调 _run_guarded 时传假 guard),生产路径为 nil。
local function _run_guarded(guard_impl, args, env)
  local guard = guard_impl or require("packages.mutate.lua54_guard")
  local result, detail = guard.ensure({ repo_root = REPO_ROOT, args = args or {} })
  if result == nil then
    local sink = (env or {}).stderr or io.stderr
    sink:write(tostring(detail), "\n")
    return 1
  end
  if result == "reexec" then
    return detail
  end
  return require("mutate4lua.cli").run(args, tool_cli.merge_env(_env, env))
end

if ... == "packages.mutate.runner" then
  return {
    env = _env,
    run = function(args, env)
      return _run_guarded(nil, args, env)
    end,
    _run_guarded = _run_guarded,
  }
end

os.exit(_run_guarded(nil, arg or {}, _env))

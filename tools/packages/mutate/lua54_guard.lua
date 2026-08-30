-- mutate 车道 Lua 5.4 门禁(issue #203)。
--
-- 存在理由:mutate4lua v0.1.0 引擎以字面量 "lua" 启动内建 runner 子进程
-- (engine.lua:_build_runner_command),子进程经 PATH 解析。PATH 上 lua = 5.5 的
-- 机器上整条车道假红(稀疏表 # 边界语义不同,land_pricing_spec 之类回归失败),
-- 且与代码改动无关。
--
-- 口径与 packages/luaunit_runner/lua54.lua 完全同源:解释器解析一律走
-- lua54.detect_lua54()(LUA54_BIN 覆写 + 候选表),此处不造第二套规则。引擎不可改
-- (tools.lock 跟随的 .toolcache 参考实现),所以本模块在调引擎前保证:
--   1. 能解析到 Lua 5.4,否则在跑任何测试前大声失败;
--   2. 当前进程不是 5.4、或 PATH 上 lua 不是 5.4 时,re-exec 到钉定解释器,
--      并把 shim 目录(内含指向 5.4 的 lua)prepend 进子进程 PATH。
local fs_lib = require("foundation.fs")
local path_lib = require("foundation.path")
local proc_lib = require("foundation.proc")
local shell_lib = require("foundation.shell")

local M = {}

local _MARKER = "MUTATE_LUA54_REEXEC"

-- 纯判定:是否需要 re-exec。version 为当前进程 _VERSION,path_lua_is_54 为 PATH 上
-- lua 的探测结果,marker_set 表示本进程已是 re-exec 产物(防循环)。
function M.needs_reexec(version, path_lua_is_54, marker_set)
  if marker_set == true then return false end
  if version ~= "Lua 5.4" then return true end
  return path_lua_is_54 ~= true
end

local function _detect_lua54()
  local ok, bin = pcall(require, "packages.luaunit_runner.lua54")
  if not ok or type(bin) ~= "table" or type(bin.detect_lua54) ~= "function" then
    return nil
  end
  return bin.detect_lua54()
end

local function _path_lua_is_54()
  local result = proc_lib.run_command({ "lua", "-v" })
  return result.ok == true and tostring(result.output or ""):find("Lua 5%.4") ~= nil
end

-- shim 住 tmp/ 下的专属目录,不落 tmp/ 根:被 prepend 进子进程 PATH 的正是这个目录,
-- 落在根上等于把整个临时目录塞进 PATH,任何与系统命令重名的文件都会抢先解析到。
-- 纯演算,与写盘分开,便于单测(issue #211)。
function M.shim_dir(repo_root)
  return path_lib.join_path(repo_root, "tmp", "lua54-shim")
end

-- luarocks tree 的 LUA_PATH / LUA_CPATH 前缀:内建 runner 子进程以字面量 "lua"
-- 启动,package.path/cpath 不含 tree(v0.1.0 上游假设 lib/、src/),luaunit/luacov
-- 在 share/,cluacov 的 .so 在 lib/——两路都必须经环境注入子进程(#283 + cluacov)。
function M.tree_lua_path(repo_root)
  return path_lib.join_path(repo_root, ".toolcache/luarocks/share/lua/5.4/?.lua") .. ";;"
end

function M.tree_lua_cpath(repo_root)
  return path_lib.join_path(repo_root, ".toolcache/luarocks/lib/lua/5.4/?.so") .. ";;"
end

-- shim 目录:内含一个名为 lua 的 wrapper,exec 到钉定解释器,并 export
-- LUA_PATH + LUA_CPATH(tree 前缀)——子进程无论从哪条路径启动都拿到
-- luaunit/luacov/cluacov。每次重建,避免陈旧指向。
local function _write_shim(repo_root, lua54)
  local shim_dir = M.shim_dir(repo_root)
  local ok, err = fs_lib.ensure_dir(shim_dir)
  if not ok then return nil, err end
  local shim_path = path_lib.join_path(shim_dir, "lua")
  local script = "#!/bin/sh\nexport LUA_PATH=" .. shell_lib.shell_quote(M.tree_lua_path(repo_root))
    .. ':"${LUA_PATH:-}"\nexport LUA_CPATH=' .. shell_lib.shell_quote(M.tree_lua_cpath(repo_root))
    .. ':"${LUA_CPATH:-}"\nexec ' .. shell_lib.shell_quote(lua54) .. ' "$@"\n'
  ok, err = fs_lib.write_file(shim_path, script)
  if not ok then return nil, err end
  local chmod = proc_lib.run_command({ "chmod", "+x", shim_path })
  if chmod.ok ~= true then return nil, "chmod failed: " .. tostring(chmod.output or "") end
  return shim_dir
end

-- env 形式 re-exec:shim 目录 prepend PATH,LUA_PATH/LUA_CPATH 钉 tree 前缀
-- (子进程 runner 需要 luaunit/luacov/cluacov),LUA54_BIN 钉给下游
-- packages.luaunit_runner.lua54,marker 防循环。输出实时落终端(os.execute 不重定向)。
local function _reexec(repo_root, lua54, script_path, args)
  local shim_dir, err = _write_shim(repo_root, lua54)
  if shim_dir == nil then return nil, err end
  local parts = {
    "env",
    "PATH=" .. shell_lib.shell_quote(shim_dir .. ":" .. tostring(os.getenv("PATH") or "")),
    "LUA_PATH=" .. shell_lib.shell_quote(M.tree_lua_path(repo_root) .. tostring(os.getenv("LUA_PATH") or "")),
    "LUA_CPATH=" .. shell_lib.shell_quote(M.tree_lua_cpath(repo_root) .. tostring(os.getenv("LUA_CPATH") or "")),
    "LUA54_BIN=" .. shell_lib.shell_quote(lua54),
    _MARKER .. "=1",
    shell_lib.shell_quote(lua54),
    shell_lib.shell_quote(script_path),
  }
  for _, value in ipairs(args or {}) do
    parts[#parts + 1] = shell_lib.shell_quote(value)
  end
  local ok, _, code = os.execute(table.concat(parts, " "))
  return (ok == true or code == 0) and 0 or (code or 1)
end

-- CLI 入口门禁。返回 "proceed" 或 ("reexec", exit_code) 或 (nil, 诊断)。
-- detect / path_check / getenv 可注入,便于 spec。
function M.ensure(opts)
  opts = opts or {}
  local getenv = opts.getenv or os.getenv
  local detect = opts.detect or _detect_lua54
  local path_check = opts.path_check or _path_lua_is_54
  local lua_path_check = opts.lua_path_check or function(repo_root)
    local current = os.getenv("LUA_PATH") or ""
    return current:find(M.tree_lua_path(repo_root), 1, true) ~= nil
  end
  local lua_cpath_check = opts.lua_cpath_check or function(repo_root)
    local current = os.getenv("LUA_CPATH") or ""
    return current:find(M.tree_lua_cpath(repo_root), 1, true) ~= nil
  end
  local version = opts.version or _VERSION

  if getenv(_MARKER) == "1" then
    return "proceed"
  end

  local lua54 = detect()
  if lua54 == nil then
    return nil, "mutate 车道中止:找不到 Lua 5.4 解释器(可用 LUA54_BIN 指定)。\n"
      .. "mutate lane aborted: no Lua 5.4 interpreter found (set LUA54_BIN to override)."
  end

  -- re-exec 条件:解释器链不对(本进程非 5.4 / PATH lua 非 5.4)、或 LUA_PATH /
  -- LUA_CPATH 未带 tree 前缀——内建 runner 子进程缺 luaunit/luacov 会整条车道
  -- 假红(#283);缺 cluacov 的 .so 路径则归因矩阵静默退回纯 Lua hook。
  if not M.needs_reexec(version, path_check(), false)
      and lua_path_check(opts.repo_root)
      and lua_cpath_check(opts.repo_root) then
    return "proceed"
  end

  local script_path = path_lib.join_path(opts.repo_root, "tools/packages/mutate/runner.lua")
  local code, err = _reexec(opts.repo_root, lua54, script_path, opts.args or {})
  if code == nil then
    return nil, "mutate 车道中止:re-exec 到 Lua 5.4 失败 / re-exec to Lua 5.4 failed: " .. tostring(err)
  end
  return "reexec", code
end

return M

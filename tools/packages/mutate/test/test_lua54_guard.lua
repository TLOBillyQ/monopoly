---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/packages/mutate/test/test_lua54_guard.lua") end
require("test.bootstrap").install_package_paths()

local lu = require("luaunit")
local guard = require("packages.mutate.lua54_guard")

-- 原生 LuaUnit 迁移:三个 describe 均无钩子,按 describe 边界拍平成三个
-- TestLua54Guard* 类,用例数与改写前一一对应(4 + 2 + 4 = 10 例)。

TestLua54GuardNeedsReexec = {}

function TestLua54GuardNeedsReexec:test_never_reexecs_when_the_marker_is_set_loop_guard()
  lu.assertFalse(guard.needs_reexec("Lua 5.5", false, true))
  lu.assertFalse(guard.needs_reexec("Lua 5.4", true, true))
end

function TestLua54GuardNeedsReexec:test_reexecs_when_the_current_interpreter_is_not_54()
  lu.assertTrue(guard.needs_reexec("Lua 5.5", true, false))
end

function TestLua54GuardNeedsReexec:test_reexecs_when_path_lua_is_not_54_even_under_a_54_host()
  lu.assertTrue(guard.needs_reexec("Lua 5.4", false, false))
end

function TestLua54GuardNeedsReexec:test_proceeds_when_both_host_and_path_lua_are_54()
  lu.assertFalse(guard.needs_reexec("Lua 5.4", true, false))
end

-- issue #211:shim 必须住独立目录,因为被 prepend 进子进程 PATH 的正是这个目录。
-- 落在通用 tmp/ 根意味着 tmp/ 下任何一个与系统命令重名的可执行文件都会在 mutate
-- 子进程里抢先被解析到——PATH 污染面从「一个 shim」放大成「整个临时目录」。
--
-- 这条要求必须可断言,而写 shim 与 re-exec 都是环境不适宜的(建目录、chmod、
-- os.execute 真跑整条车道),所以目录演算要从副作用里分出来做纯函数暴露。
-- 名字 shim_dir 是本规约的取名;coder 若要换名,回来讲一声,规约跟着改。

TestLua54GuardShimDir = {}

function TestLua54GuardShimDir:test_resolves_a_dedicated_shim_directory_under_tmp_not_the_tmp_root()
  lu.assertIs(guard.shim_dir("/tmp/repo"), "/tmp/repo/tmp/lua54-shim")
end

function TestLua54GuardShimDir:test_keeps_the_shim_directory_nested_when_the_repo_root_has_a_trailing_slash()
  lu.assertIs(guard.shim_dir("/tmp/repo/"), "/tmp/repo/tmp/lua54-shim")
end

local function _env(overrides)
  local base = {
    repo_root = "/tmp/repo",
    args = {},
    getenv = function() return nil end,
    detect = function() return "/opt/lua54/bin/lua5.4" end,
    path_check = function() return true end,
    -- #283:proceed 还需要 LUA_PATH 带 tree 前缀(内建 runner 子进程要
    -- luaunit/luacov);cluacov 还要 LUA_CPATH。注入时默认视为已带。
    lua_path_check = function() return true end,
    lua_cpath_check = function() return true end,
    version = "Lua 5.4",
  }
  for key, value in pairs(overrides or {}) do base[key] = value end
  return base
end

TestLua54GuardEnsure = {}

function TestLua54GuardEnsure:test_fails_fast_with_a_diagnostic_when_no_lua_54_can_be_resolved()
  local result, err = guard.ensure(_env({ detect = function() return nil end }))
  lu.assertNil(result)
  lu.assertEvalToTrue(tostring(err):find("Lua 5.4"))
end

function TestLua54GuardEnsure:test_proceeds_without_reexec_when_marker_env_is_already_set()
  local result = guard.ensure(_env({
    getenv = function(name) return name == "MUTATE_LUA54_REEXEC" and "1" or nil end,
    detect = function() return nil end,
    version = "Lua 5.5",
    path_check = function() return false end,
  }))
  lu.assertIs(result, "proceed")
end

function TestLua54GuardEnsure:test_proceeds_when_host_and_path_lua_are_both_54()
  lu.assertIs(guard.ensure(_env()), "proceed")
end

function TestLua54GuardEnsure:test_default_tree_checks_use_the_injected_environment_reader()
  local root = "/repo"
  local values = {
    LUA_PATH = "prefix;" .. guard.tree_lua_path(root) .. "suffix",
    LUA_CPATH = "prefix;" .. guard.tree_lua_cpath(root) .. "suffix",
  }
  local result = guard.ensure({
    repo_root = root,
    args = {},
    getenv = function(name) return values[name] end,
    detect = function() return "/opt/lua54/bin/lua5.4" end,
    path_check = function() return true end,
    version = "Lua 5.4",
  })
  lu.assertIs(result, "proceed")
end

-- re-exec 路径会真跑 shell;此处只钉判定走向,不钉副作用。
function TestLua54GuardEnsure:test_chooses_reexec_when_path_lua_is_not_54()
  -- _reexec 需要可写 repo_root;用不存在目录逼出失败,证明确实走向 re-exec 分支。
  local result = guard.ensure(_env({
    path_check = function() return false end,
    repo_root = "/nonexistent-repo-root",
  }))
  -- 无法写 shim 时 ensure 报 nil+诊断;能走通则返回 "reexec"。两种都证明
  -- 没有误判成 proceed。
  lu.assertTrue(result == "reexec" or result == nil)
end

-- #283:mutate4lua v0.1.0 内建 runner 以字面量 "lua" 起子进程
-- (engine.lua:_build_runner_command),子进程经 PATH 解析,package.path 不含
-- luarocks tree——shim 必须同时解决解释器版本与 LUA_PATH 两件事。端到端验证
-- 写 shim(与 _write_shim 同构)+ spawn `lua -v`,环境不适宜但正是契约本体。

TestLua54GuardShimSpawn = {}

function TestLua54GuardShimSpawn:test_shim_redirects_child_lua_to_lua54()
  local env_lib = require("foundation.env")
  local fs_lib = require("foundation.fs")
  local path_lib = require("foundation.path")
  local proc_lib = require("foundation.proc")
  local shell_lib = require("foundation.shell")
  local bin = require("packages.luaunit_runner.lua54")
  local lua54 = bin.detect_lua54()
  lu.assertNotNil(lua54, "lua5.4 interpreter must be resolvable for the shim test")

  local root = env_lib.make_temp_path("lua54_shim_spawn", "")
  local shim_dir = guard.shim_dir(root)
  lu.assertTrue(fs_lib.ensure_dir(shim_dir))
  local shim_path = path_lib.join_path(shim_dir, "lua")
  local tree_prefix = path_lib.join_path(root, ".toolcache/luarocks/share/lua/5.4/?.lua") .. ";;"
  local tree_cprefix = path_lib.join_path(root, ".toolcache/luarocks/lib/lua/5.4/?.so") .. ";;"
  lu.assertTrue(fs_lib.write_file(shim_path,
    "#!/bin/sh\nexport LUA_PATH=" .. shell_lib.shell_quote(tree_prefix)
      .. ':"${LUA_PATH:-}"\nexport LUA_CPATH=' .. shell_lib.shell_quote(tree_cprefix)
      .. ':"${LUA_CPATH:-}"\nexec ' .. shell_lib.shell_quote(lua54) .. ' "$@"\n'))
  lu.assertTrue(proc_lib.run_command({ "chmod", "+x", shim_path }).ok == true)

  local result = proc_lib.run_command({
    "env", "PATH=" .. shim_dir .. ":" .. tostring(os.getenv("PATH") or ""),
    "lua", "-v",
  })
  fs_lib.remove_path(root)

  lu.assertTrue(result.ok == true, "shimmed lua should run: " .. tostring(result.output))
  lu.assertEvalToTrue(tostring(result.output):find("Lua 5%.4") ~= nil,
    "child 'lua' must resolve to the pinned 5.4 interpreter, got: " .. tostring(result.output))
end

-- re-exec 条件包含 LUA_PATH(#283):解释器链全对但 LUA_PATH 没带 tree 前缀时,
-- 子进程 runner 仍然 require 不到 luaunit/luacov——必须走 re-exec 注入。
function TestLua54GuardEnsure:test_reexecs_when_lua_path_misses_the_tree_prefix()
  local result = guard.ensure(_env({
    lua_path_check = function() return false end,
    repo_root = "/nonexistent-repo-root",
  }))
  lu.assertTrue(result == "reexec" or result == nil,
    "missing tree LUA_PATH must not proceed; got " .. tostring(result))
end

-- cluacov:解释器链与 LUA_PATH 全对但 LUA_CPATH 缺 tree 前缀时,归因矩阵
-- 子进程 require 不到 cluacov.hook.so,静默退回纯 Lua——必须 re-exec 注入。
function TestLua54GuardEnsure:test_reexecs_when_lua_cpath_misses_the_tree_prefix()
  local result = guard.ensure(_env({
    lua_cpath_check = function() return false end,
    repo_root = "/nonexistent-repo-root",
  }))
  lu.assertTrue(result == "reexec" or result == nil,
    "missing tree LUA_CPATH must not proceed; got " .. tostring(result))
end

function TestLua54GuardShimDir:test_tree_lua_cpath_points_at_lib_so_pattern()
  lu.assertIs(guard.tree_lua_cpath("/tmp/repo"),
    "/tmp/repo/.toolcache/luarocks/lib/lua/5.4/?.so;;")
end

function TestLua54GuardShimDir:test_tree_lua_path_points_at_share_lua_pattern()
  lu.assertIs(guard.tree_lua_path("/tmp/repo"),
    "/tmp/repo/.toolcache/luarocks/share/lua/5.4/?.lua;;")
end


return TestLua54GuardNeedsReexec

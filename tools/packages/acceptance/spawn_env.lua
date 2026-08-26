-- acceptance4lua 生成入口的 spawn 环境(去 monopoly 耦合后的新契约)。
--
-- 新版 acceptance4lua.runner 把生成的 entrypoint 当独立 lua 脚本跑:
-- `LUA_PATH=<lua_path> <lua_bin> spec.lua`,替代旧 busted --helper 机制。
-- runner 的默认 lua_bin/lua_path 不含宿主项目的模块路径,
-- 本仓通过 luarocks tree 消费,必须显式给:
--   lua_bin  —— 钉定的 Lua 5.4(与 packages.luaunit_runner.lua54 同口径,PATH
--               上的 lua 是 5.5);
--   lua_path —— tree 的 share/lua/5.4 路径 + 仓库 tools/ 与根目录模块布局
--               (acceptance.steps、acceptance.runtime、src.* 都从这里解析)。
local path_lib = require("foundation.path")
local lua54 = require("packages.luaunit_runner.lua54")

local spawn_env = {}

-- env 是 shared/bootstrap 的解析结果;acceptance_tool 是 ensure_tool 的返回值(root 指向 tree)。
-- 返回可直接并入 runner.run_generated opts 的 { lua_bin = ..., lua_path = ... }。
-- ACCEPTANCE_LUA_BIN / ACCEPTANCE_LUA_PATH 环境变量优先,
-- 也是车道测试模拟"runner adapter 坏掉"的入口。
function spawn_env.runner_opts(env, acceptance_tool)
  local repo_root = env.repo_root
  local share_root = path_lib.join_path(acceptance_tool.root, "share/lua/5.4")
  local lua_path = table.concat({
    path_lib.join_path(share_root, "?.lua"),
    path_lib.join_path(share_root, "?/init.lua"),
    path_lib.join_path(repo_root, "tools/?.lua"),
    path_lib.join_path(repo_root, "tools/?/init.lua"),
    path_lib.join_path(repo_root, "?.lua"),
    path_lib.join_path(repo_root, "?/init.lua"),
  }, ";") .. ";;"
  return {
    lua_bin = os.getenv("ACCEPTANCE_LUA_BIN") or lua54.lua54_bin(),
    lua_path = os.getenv("ACCEPTANCE_LUA_PATH") or lua_path,
  }
end

return spawn_env

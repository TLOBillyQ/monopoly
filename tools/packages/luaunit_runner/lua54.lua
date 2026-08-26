--- tools/packages/luaunit_runner 的解释器与 runner.lua 路径解析器。
--- 旧 bin.lua（活的 lua5.4 探测 + LuaUnit
--- 启动器)并入 luaunit_runner 包,改名 lua54.lua 住 tools/packages/luaunit_runner/。
--- 质量车道(spec_lane / behavior_parallel / coverage)调用 argv_prefix() 取
--- 得「跑一个 profile / 一批 spec」的命令前缀 argv 列表:
---   { <lua5.4 解释器>, <runner.lua 绝对路径> } —— LuaUnit 运行器是默认后端。
--- 解析出的是 lua5.4 解释器 + Lua 脚本两个 token,不依赖 shell wrapper 或可执行位。

local fs_lib = require("foundation.fs")
local path_lib = require("foundation.path")
local proc_lib = require("foundation.proc")

local M = {}

-- lua5.4 解释器的候选表(homebrew / 常见前缀 + PATH)。
--
-- 这份表连同下面的探测逻辑,原先在 verify_full 里还有一份逐字副本,靠"同口径"的注释
-- 手工维持同步——注释挡不住漂移。现在 detect_lua54() 是唯一实现,verify_full 复用它。
local _LUA54_BIN_CANDIDATES = {
  "/opt/homebrew/bin/lua5.4",
  "/usr/local/bin/lua5.4",
  "/opt/homebrew/opt/lua@5.4/bin/lua5.4",
  "/usr/local/opt/lua@5.4/bin/lua5.4",
  "lua5.4",
  "lua54",
  "lua",
}

local function _env_value(name)
  local value = os.getenv(name)
  if value == nil or value == "" then
    return nil
  end
  return value
end

local function _path_or_command_available(value)
  local text = tostring(value or "")
  if text == "" then
    return false
  end
  if text:find("[/\\]") ~= nil or text:match("^%a:") ~= nil then
    return fs_lib.path_exists(text)
  end
  return proc_lib.command_exists(text)
end

local function _lua_reports_54(candidate)
  local result = proc_lib.run_command({ candidate, "-v" })
  return result.ok == true and tostring(result.output or ""):find("Lua 5%.4") ~= nil
end

--- 探测 lua5.4 解释器。LUA54_BIN 覆写优先;否则按候选表探测。探测要 spawn
--- `<candidate> -v`,进程内记忆化避免同批多车道重复探测。
---
--- 探不到时返回 nil —— 调用方据此区分"没装 lua5.4"与"用了兜底"。verify_full 要的正是
--- 这个语义(它据此判定 coverage 车道能否开),M.lua54_bin() 则在其上兜底 "lua"。
local _lua54_cache = nil
local _lua54_resolved = false
function M.detect_lua54()
  if _lua54_resolved then
    return _lua54_cache
  end
  _lua54_resolved = true

  local override = _env_value("LUA54_BIN")
  if override ~= nil then
    _lua54_cache = override
    return _lua54_cache
  end
  for _, candidate in ipairs(_LUA54_BIN_CANDIDATES) do
    if _path_or_command_available(candidate) and _lua_reports_54(candidate) then
      _lua54_cache = candidate
      return _lua54_cache
    end
  end
  _lua54_cache = nil
  return nil
end

--- 命令前缀要的是一个总能用的解释器,探不到就退回 PATH 上的 "lua"。
function M.lua54_bin()
  return M.detect_lua54() or "lua"
end

local function _script_dir()
  local source = tostring(debug.getinfo(1, "S").source or ""):gsub("^@", "")
  return path_lib.normalize_path(source):match("^(.*)/[^/]+$") or "tools/packages/luaunit_runner"
end

--- runner.lua 的绝对路径。默认后端 = LuaUnit 运行器(luarocks 引入的
--- luaunit 3.5；旧自研兼容层 runner/core/assert 已删除）。
--- 本模块与 runner.lua 同住 packages/luaunit_runner/,路径直接同目录推导。
function M.runner_path()
  return path_lib.normalize_path(path_lib.join_path(_script_dir(), "runner.lua"))
end

--- 返回执行 argv 前缀列表。
--- --busted-bin / BUSTED_BIN 逃生舱已删除，PATH 无 busted：
--- 恒返回默认后端 { lua5.4, runner.lua }。
function M.argv_prefix()
  return { M.lua54_bin(), M.runner_path() }
end

return M

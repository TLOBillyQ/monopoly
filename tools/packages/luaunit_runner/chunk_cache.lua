--- Lua searcher 的 chunk 缓存(#428)。
---
--- 背景:runner 的文件级隔离(file_isolation)按 busted insulate 语义,每个
--- spec 文件加载完把 package.loaded 恢复到加载前快照——下一个文件的 require
--- 会把同一棵模块树整树重新加载(实测 behavior 车道单 worker:500 个唯一模块
--- 被重复加载数万次,模块加载期独占约 70% 车道 CPU)。重复执行模块顶层代码是
--- 隔离语义本身(每文件要新鲜模块实例),不能省;但「打开文件 + 词法语法解析」
--- 与实例新鲜度无关,按路径缓存 loadfile 产出的函数原型,同一路径重复
--- require 时直接重执行缓存 chunk 即可省掉重复的磁盘 IO 与解析。
---
--- 语义不变式:同一 chunk 多次调用 ≡ 多次 loadfile 后立即调用——模块顶层代码
--- 照常逐次执行、每次返回全新模块表;唯一可观测差异是进程内不再感知模块文件
--- 的内容变化(车道进程一次性跑完即退,无此场景)。
local M = {}

local _cache = {}

--- 对齐 5.4 loadlib.c searcher_Lua 的错误面:找不到模块时返回错误串(单值,
--- 供 require 聚合成 "module not found" 报告);加载失败(语法错误等)直接抛错。
local function _searcher_lua_cached(name)
  local path, search_err = package.searchpath(name, package.path)
  if path == nil then
    return search_err
  end
  local chunk = _cache[path]
  if chunk == nil then
    local load_err
    chunk, load_err = loadfile(path)
    if chunk == nil then
      error(("error loading module '%s' from file '%s':\n\t%s"):format(name, path, load_err), 0)
    end
    _cache[path] = chunk
  end
  return chunk, path
end

--- 替换 package.searchers 的 Lua searcher(槽位 2:preload 之后、C searcher
--- 之前)。幂等。
function M.install()
  if package.searchers[2] == _searcher_lua_cached then
    return
  end
  package.searchers[2] = _searcher_lua_cached
end

--- 测试/诊断面:当前缓存的 chunk 数。
function M.stats()
  local size = 0
  for _ in pairs(_cache) do
    size = size + 1
  end
  return { size = size }
end

--- 测试面:清空缓存。
function M.reset()
  for k in pairs(_cache) do
    _cache[k] = nil
  end
end

return M

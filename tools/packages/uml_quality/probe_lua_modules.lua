-- packages/uml_quality/probe_lua_modules.lua —— uml 入口的 Lua 装载探针(#93)。
--
-- 由 cli.lua 在钉死的 LUA_PATH/LUA_CPATH 下以子进程运行,不装 test.bootstrap:
-- 探的正是 crapper/mutator 子进程看到的装载面。参数是必需模块名;输出逐行
-- 制表符分隔,由 runtime.probe_verdicts 判定:
--   resolve <name> <path>   package.searchpath 的解析结果(空 = 找不到)
--   load    <name> <path>   require 时实际装载的每个文件(含传递依赖与 C 模块)
--   error   <name> <msg>    require 失败
--   loader  <path>          luarocks.loader 的解析结果(必须为空)
for index = 2, #package.searchers do
  local searcher = package.searchers[index]
  package.searchers[index] = function(name)
    local loader, path = searcher(name)
    if type(loader) == "function" and type(path) == "string" then
      io.write("load\t", name, "\t", path, "\n")
    end
    return loader, path
  end
end

for _, name in ipairs(arg) do
  local path = package.searchpath(name, package.path) or package.searchpath(name, package.cpath)
  io.write("resolve\t", name, "\t", path or "", "\n")
  local ok, err = pcall(require, name)
  if not ok then
    io.write("error\t", name, "\t", (tostring(err):gsub("[\r\n\t]+", " ")), "\n")
  end
end

io.write("loader\t", package.searchpath("luarocks.loader", package.path) or "", "\n")

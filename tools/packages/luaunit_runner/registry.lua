--- 测试登记表(LuaUnit 迁移基础设施)。
--- 全部 spec 文件加载完后,统一把收集到的测试类/函数组装成 LuaUnit 的
--- listOfNameAndInst 一次跑完;期间 _G 已按文件隔离恢复,实例引用全部 stash 在
--- 本模块,不依赖全局存活。
---
--- 登记条目:原生 LuaUnit spec——文件加载后 _G 新增的 Test* 表 / test* 函数
--- (kind = "native")。遗留 busted DSL 的 shim 收集支路(kind = "legacy")
--- 已随遗留 busted DSL 桥退场，register_class 的兼容形参 kind/methods_meta 一并移除。
--- 目录即包(tools/ 重设计决策):本包住 tools/packages/luaunit_runner/,模块前缀
--- packages.luaunit_runner(顶层 cli.lua 装载面 tools/?.lua 命中)。
--- 另维护 testKey(= "ClassName.methodName",即 LuaUnit node.testName)→ element
--- 元数据映射,outputter 据此还原旧 core 的 element 形状
--- (name/descriptor/full_name/trace.source="@"..文件/trace.currentline)。

local M = {}

local _instances = {} -- listOfNameAndInst:{ {className, instance}, ... },登记序
local _by_test = {} -- [testKey] = { file, name, full_name, linedefined, kind }
local _used_names = {} -- className 去重
local _class_env = {} -- className → 该文件加载完成后的 _G 快照(执行期装回;#428 起仅 _G,不含 package.loaded)

local function _is_test_method_name(key)
  return type(key) == "string" and key:sub(1, 4):lower() == "test"
end

--- 类名去重:两个文件同名 Test* 类时追加 _2/_3 后缀,避免 LuaUnit 把同名类
--- 的用例合并交错(lastClassName 分组语义)。
function M.unique_class_name(base)
  if _used_names[base] == nil then
    _used_names[base] = true
    return base
  end
  local n = 2
  while _used_names[base .. "_" .. n] ~= nil do
    n = n + 1
  end
  local name = base .. "_" .. n
  _used_names[name] = true
  return name
end

--- 登记一个测试类。按原生约定逐方法取 linedefined,full_name 用
--- "ClassName.methodName"。env_snap 为该文件加载完成后的 _G 快照
--- (file_isolation.snapshot_globals()),outputter 在该类的 startClass/endClass
--- 装回/恢复 —— 加载期经 spec_env 落进 _G 的全局(fixture 安装的 fake 等)
--- 要让该文件的用例可见。
function M.register_class(class_name, instance, file, env_snap)
  _instances[#_instances + 1] = { class_name, instance }
  _class_env[class_name] = env_snap
  for key, value in pairs(instance) do
    if _is_test_method_name(key) and type(value) == "function" then
      local info = debug.getinfo(value, "S")
      local test_key = class_name .. "." .. key
      _by_test[test_key] = {
        file = file,
        name = key,
        full_name = test_key,
        linedefined = info and info.linedefined or 0,
        kind = "native",
      }
    end
  end
end

--- 登记一个裸测试函数(_G 新增的 test* 函数,非类方法)。
function M.register_function(fn_name, fn, file)
  _instances[#_instances + 1] = { fn_name, fn }
  local info = debug.getinfo(fn, "S")
  _by_test[fn_name] = {
    file = file,
    name = fn_name,
    full_name = fn_name,
    linedefined = info and info.linedefined or 0,
    kind = "native",
  }
end

function M.instances()
  return _instances
end

--- 该类的执行期 _G 快照(无则 nil,裸函数不分环境)。
function M.env_for(class_name)
  return _class_env[class_name]
end

--- 由 LuaUnit node.testName 还原事件 element(形状对齐旧 core._run_test)。
--- 查不到(异常路径)时给兜底 element,保证事件流不中断。
function M.element_for(test_name)
  local meta = _by_test[test_name]
  if meta == nil then
    return {
      name = test_name,
      descriptor = "it",
      full_name = test_name,
      trace = { source = "@?", currentline = 0 },
    }, nil
  end
  return {
    name = meta.name,
    descriptor = "it",
    full_name = meta.full_name,
    trace = { source = "@" .. meta.file, currentline = meta.linedefined },
  }, meta
end

return M

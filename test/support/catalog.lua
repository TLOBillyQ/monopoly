local bootstrap = require("test.bootstrap")
local path_lib = require("foundation.path")
local proc_lib = require("foundation.proc")

local M = {}

local DSL_GLOBALS = {
  "describe",
  "it",
  "before_each",
  "after_each",
  "setup",
  "teardown",
  "pending",
}

-- spec 已全为原生 LuaUnit，断言走 lu.assertXxx，不再需要注入
-- 兼容层 assert(旧自研兼容层的 assert 已删除);spec chunk 环境只剩读写透传
-- _G 的壳。注意不要做 _G.assert 全局替换 —— require 进来的 src 模块继续用
-- 内建 assert 抛纯字符串(原型实测:粗暴替换 _G.assert 会让
-- `string.find(err, ...)` 类 spec 假红)。
-- DSL 捕获全局(describe/it/...)由 _install_capture_globals 装进 _G,
-- 经 __index 可见(捕获路径为遗留机制,当前无消费者,保留)。
local _spec_env = setmetatable({}, {
  __index = _G,
  __newindex = function(_, key, value)
    rawset(_G, key, value)
  end,
})

local contract_modules = {
  -- kept as tooling-support stubs: required by tooling lane suites for tooling_tests field
  "test.support.tooling_suites.architecture.script_tools_contract",
}

local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@test/support/catalog.lua"
  local normalized = _normalize_path(source):gsub("^@", "")
  return normalized:match("^(.*)/[^/]+$") or "test/support"
end

local function _repo_root()
  return path_lib.resolve_path(_module_dir(), "../..")
end

local function _to_repo_relative(path)
  local normalized = _normalize_path(path)
  local root = _normalize_path(_repo_root()):gsub("/+$", "")
  local prefix = root .. "/"
  if normalized:sub(1, #prefix) == prefix then
    return normalized:sub(#prefix + 1)
  end
  return normalized
end

local function _discover_behavior_specs()
  local spec_root = path_lib.join_path(_repo_root(), "test/behavior")
  local files, err = proc_lib.collect_lua_files(spec_root)
  if files == nil then
    error(err)
  end

  local specs = {}
  for _, path in ipairs(files) do
    local normalized = _to_repo_relative(path)
    local base = normalized:match("([^/]+)$") or normalized
    if base:match("^test_.*%.lua$") ~= nil then
      specs[#specs + 1] = normalized
    end
  end
  table.sort(specs)
  return specs
end

local function _copy_array(values)
  local copied = {}
  for _, value in ipairs(values or {}) do
    copied[#copied + 1] = value
  end
  return copied
end

local function _run_case(before_hooks, case_fn, after_hooks)
  local original_pending = _G.pending
  _G.pending = function()
    return nil
  end

  local ok, err = xpcall(function()
    for _, hook in ipairs(before_hooks or {}) do
      hook()
    end
    case_fn()
  end, debug.traceback)

  local after_ok, after_err = xpcall(function()
    for index = #after_hooks or 0, 1, -1 do
      after_hooks[index]()
    end
  end, debug.traceback)

  _G.pending = original_pending

  if not ok then
    error(err, 0)
  end
  if not after_ok then
    error(after_err, 0)
  end
end

local function _install_capture_globals(spec_file, suites, stack)
  local root_suite = {
    name = spec_file,
    layer = "behavior",
    kind = "suite",
    module_name = spec_file,
    tests = {},
  }
  suites[#suites + 1] = root_suite

  _G.describe = function(name, body)
    local parent = stack[#stack]
    local suite = {
      name = tostring(name or spec_file),
      layer = "behavior",
      kind = "suite",
      module_name = spec_file,
      tests = {},
    }
    local context = {
      suite = suite,
      before_each = {},
      after_each = {},
    }
    if parent ~= nil then
      context.inherited_before_each = _copy_array(parent.inherited_before_each)
      for _, hook in ipairs(parent.before_each) do
        context.inherited_before_each[#context.inherited_before_each + 1] = hook
      end
      context.inherited_after_each = _copy_array(parent.inherited_after_each)
      for _, hook in ipairs(parent.after_each) do
        context.inherited_after_each[#context.inherited_after_each + 1] = hook
      end
    else
      context.inherited_before_each = {}
      context.inherited_after_each = {}
    end

    suites[#suites + 1] = suite
    stack[#stack + 1] = context
    body()
    stack[#stack] = nil
  end

  _G.it = function(name, case_fn)
    local context = stack[#stack]
    local suite = context and context.suite or root_suite
    local before_hooks = context and _copy_array(context.inherited_before_each) or {}
    local after_hooks = context and _copy_array(context.inherited_after_each) or {}
    if context ~= nil then
      for _, hook in ipairs(context.before_each) do
        before_hooks[#before_hooks + 1] = hook
      end
      for _, hook in ipairs(context.after_each) do
        after_hooks[#after_hooks + 1] = hook
      end
    end

    suite.tests[#suite.tests + 1] = {
      name = tostring(name or ("case_" .. tostring(#suite.tests + 1))),
      run = function()
        return _run_case(before_hooks, case_fn, after_hooks)
      end,
      tags = {},
    }
  end

  _G.before_each = function(hook)
    local context = stack[#stack]
    if context ~= nil then
      context.before_each[#context.before_each + 1] = hook
    end
  end

  _G.after_each = function(hook)
    local context = stack[#stack]
    if context ~= nil then
      context.after_each[#context.after_each + 1] = hook
    end
  end

  _G.setup = _G.before_each
  _G.teardown = _G.after_each
  _G.pending = function()
    return nil
  end
end

-- 原生 LuaUnit spec(推翻自研 busted 兼容运行器决策的迁移后的新形态)没有 describe/it 可捕获:
-- 加载后 _G 新增 Test* 类表。这里把新增类收进与捕获路径同构的 suite
-- (tests = { name, run }),run 按 LuaUnit 语义跑 setUp → method → tearDown
-- (tearDown 无论成败都跑),让 mutate / crap 车道的进程内执行路径不变。
-- file_globals 是同文件加载出的全部 Test* 类表:子类 setUp/tearDown 常以
-- 全局名引用父类(如 TestENodeListen 里调 TestENode.setUp),收集后清场会
-- 把这些名字抹掉,run 时必须临时装回,跑完再恢复现场。
local function _collect_native_class_suite(spec_file, class_name, class, file_globals)
  local methods = {}
  for key, value in pairs(class) do
    if type(key) == "string" and key:match("^test") ~= nil and type(value) == "function" then
      methods[#methods + 1] = { name = key, fn = value }
    end
  end
  table.sort(methods, function(a, b)
    return a.name < b.name
  end)

  local suite = {
    name = class_name,
    layer = "behavior",
    kind = "suite",
    module_name = spec_file,
    tests = {},
  }
  for _, method in ipairs(methods) do
    local method_fn = method.fn
    suite.tests[#suite.tests + 1] = {
      name = method.name,
      run = function()
        local saved = {}
        for gname, gtable in pairs(file_globals) do
          saved[gname] = _G[gname]
          _G[gname] = gtable
        end
        local run_ok, run_err = xpcall(function()
          local instance = setmetatable({}, { __index = class })
          if type(class.setUp) == "function" then
            class.setUp(instance)
          end
          local ok, err = xpcall(function()
            method_fn(instance)
          end, debug.traceback)
          if type(class.tearDown) == "function" then
            local td_ok, td_err = xpcall(function()
              class.tearDown(instance)
            end, debug.traceback)
            if ok and not td_ok then
              ok, err = td_ok, td_err
            end
          end
          if not ok then
            error(err, 0)
          end
        end, debug.traceback)
        for gname in pairs(file_globals) do
          _G[gname] = saved[gname]
        end
        if not run_ok then
          error(run_err, 0)
        end
      end,
      tags = {},
    }
  end
  return suite
end

-- 原生 spec 顶部 `require("luaunit")`:luarocks 本地 tree 不在工具链进程的
-- package.path 上(runner.lua 是自己追加的),这里同口径补齐(tree gitignored,
-- 由车道按需 bootstrap;不存在时 require 报错与 runner 行为一致)。
local function _ensure_luaunit_resolvable()
  if pcall(require, "luaunit") then
    return
  end
  local extra = path_lib.join_path(_repo_root(), ".toolcache/luarocks/share/lua/5.4/?.lua")
  if not package.path:find(extra, 1, true) then
    package.path = package.path .. ";" .. extra
  end
end

local function _load_behavior_spec(spec_file)
  _ensure_luaunit_resolvable()
  local suites = {}
  local stack = {}
  local original_globals = {}
  for _, key in ipairs(DSL_GLOBALS) do
    original_globals[key] = _G[key]
  end
  local preexisting = {}
  for key in pairs(_G) do
    preexisting[key] = true
  end

  local ok, err = xpcall(function()
    _install_capture_globals(spec_file, suites, stack)
    -- spec chunk 在专属环境加载:assert = 兼容层,不污染 _G.assert。
    local chunk, load_err = loadfile(path_lib.join_path(_repo_root(), spec_file), "bt", _spec_env)
    if chunk == nil then
      error(load_err)
    end
    chunk()
  end, debug.traceback)

  -- 原生形态收集 + 清场:Test* 类表是加载副作用,收完即从 _G 撤掉,
  -- 避免跨文件泄漏(捕获路径只动 DSL_GLOBALS,本来就恢复)。
  if ok then
    local added = {}
    for key, value in pairs(_G) do
      if not preexisting[key]
        and type(key) == "string"
        and key:match("^Test") ~= nil
        and type(value) == "table"
      then
        added[#added + 1] = key
      end
    end
    table.sort(added)
    local file_globals = {}
    for _, key in ipairs(added) do
      file_globals[key] = _G[key]
    end
    for _, key in ipairs(added) do
      local suite = _collect_native_class_suite(spec_file, key, _G[key], file_globals)
      if #suite.tests > 0 then
        suites[#suites + 1] = suite
      end
      _G[key] = nil
    end
  end

  for _, key in ipairs(DSL_GLOBALS) do
    _G[key] = original_globals[key]
  end

  if not ok then
    error(err, 0)
  end

  local loaded = {}
  for _, suite in ipairs(suites) do
    if #(suite.tests or {}) > 0 then
      loaded[#loaded + 1] = suite
    end
  end
  return loaded
end

local function _load_behavior_specs(spec_files)
  local suites = {}
  for _, spec_file in ipairs(spec_files or {}) do
    local spec_suites = _load_behavior_spec(spec_file)
    for _, suite in ipairs(spec_suites) do
      suites[#suites + 1] = suite
    end
  end
  return suites
end

local function _clone_case(test)
  if type(test) == "function" then
    return {
      name = nil,
      run = test,
      tags = {},
    }
  end
  local clone = {}
  for key, value in pairs(test or {}) do
    clone[key] = value
  end
  clone.tags = clone.tags or {}
  return clone
end

local function _clone_suite(module_name, suite, layer, kind)
  local clone = {
    name = suite.name,
    layer = suite.layer or layer,
    kind = suite.kind or kind,
    tests = {},
    module_name = module_name,
  }
  local source_tests = suite.tests or suite
  for _, test in ipairs(source_tests or {}) do
    local case = _clone_case(test)
    clone.tests[#clone.tests + 1] = case
  end
  return clone
end

local function _load_modules(module_names, layer, kind)
  local suites = {}
  for _, module_name in ipairs(module_names or {}) do
    local suite = require(module_name)
    suites[#suites + 1] = _clone_suite(module_name, suite, layer, kind)
  end
  return suites
end

M.behavior_suites = _discover_behavior_specs()
M.contract_suites = contract_modules

local function _select_by_keys(entries, only)
  if only == nil then
    return entries
  end
  local selected = {}
  for _, entry in ipairs(entries or {}) do
    if only[entry] then
      selected[#selected + 1] = entry
    end
  end
  return selected
end

function M.load_behavior_suites(opts)
  bootstrap.install_package_paths()
  local only = opts and opts.only or nil
  return _load_behavior_specs(_select_by_keys(M.behavior_suites, only))
end

function M.load_contract_suites(opts)
  bootstrap.install_package_paths()
  local only = opts and opts.only or nil
  return _load_modules(_select_by_keys(M.contract_suites, only), "contract", "contract")
end

return M

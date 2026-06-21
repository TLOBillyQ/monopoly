local bootstrap = require("spec.bootstrap")
local common = require("shared.lib.common")

local M = {}

local BUSTED_GLOBALS = {
  "describe",
  "it",
  "before_each",
  "after_each",
  "setup",
  "teardown",
  "pending",
}

-- luassert is callable via __call, so `assert(cond, msg)` keeps working while
-- specs that use `assert.is_true` / `assert.is_function` also resolve outside busted.
-- Fallback: bare `lua5.4 tools/...` subprocesses don't inherit the luarocks
-- package.path that the busted shebang prepends, so probe `luarocks path` once
-- if the initial require fails.
local _luassert_ok, _luassert = pcall(require, "luassert")
if not _luassert_ok then
  local result = common.run_command({ "luarocks", "path", "--lr-path" })
  local extra = result.ok and tostring(result.output or ""):match("^%s*(.-)%s*$") or nil
  if extra ~= nil and extra ~= "" and package.path:find(extra, 1, true) == nil then
    package.path = extra .. ";" .. package.path
  end
  _luassert = require("luassert")
end
_G.assert = _luassert

local contract_modules = {
  -- kept as tooling-support stubs: required by tooling lane suites for tooling_tests field
  "spec.support.tooling_suites.architecture.script_tools_contract",
}

local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@tools/quality/shared/test_catalog.lua"
  local normalized = _normalize_path(source):gsub("^@", "")
  return normalized:match("^(.*)/[^/]+$") or "tools/quality/shared"
end

local function _repo_root()
  return common.resolve_path(_module_dir(), "../../..")
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
  local spec_root = common.join_path(_repo_root(), "spec/behavior")
  local files, err = common.collect_lua_files(spec_root)
  if files == nil then
    error(err)
  end

  local specs = {}
  for _, path in ipairs(files) do
    local normalized = _to_repo_relative(path)
    if normalized:match("_spec%.lua$") ~= nil then
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
  _G.assert = _luassert
end

local function _load_behavior_spec(spec_file)
  local suites = {}
  local stack = {}
  local original_globals = {}
  for _, key in ipairs(BUSTED_GLOBALS) do
    original_globals[key] = _G[key]
  end

  local ok, err = xpcall(function()
    _install_capture_globals(spec_file, suites, stack)
    local chunk, load_err = loadfile(common.join_path(_repo_root(), spec_file))
    if chunk == nil then
      error(load_err)
    end
    chunk()
  end, debug.traceback)

  for _, key in ipairs(BUSTED_GLOBALS) do
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

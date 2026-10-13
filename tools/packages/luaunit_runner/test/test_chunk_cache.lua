---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/packages/luaunit_runner/test/test_chunk_cache.lua") end
require("test.bootstrap").install_package_paths()

local check = require("luassert")
local fs_lib = require("foundation.fs")
local chunk_cache = require("packages.luaunit_runner.chunk_cache")

local _TMP_ROOT = "./tmp/chunk_cache_spec"
local _MODULE_NAME = "chunk_cache_probe_mod"
local _MODULE_PATH = _TMP_ROOT .. "/" .. _MODULE_NAME .. ".lua"

local function _write_module(content)
  assert(fs_lib.write_file(_MODULE_PATH, content))
end

local function _evict()
  package.loaded[_MODULE_NAME] = nil
end

describe("chunk cache", function()
local saved_package_path

before_each(function()
  fs_lib.remove_path(_TMP_ROOT)
  chunk_cache.reset()
  _evict()
  -- package.path 是进程全局,模块态全进程共享(#428)后更要显式装回,
  -- 否则本文件的临时路径会泄漏给同 worker 后续 spec。
  saved_package_path = package.path
  package.path = package.path .. ";" .. _TMP_ROOT .. "/?.lua"
end)

after_each(function()
  package.path = saved_package_path
  fs_lib.remove_path(_TMP_ROOT)
  chunk_cache.reset()
  _evict()
end)

-- 车道 runner 启动时已全局 install,这里只钉幂等性:重复 install 不换 searcher。
it("install is idempotent", function()
  chunk_cache.install()
  local installed = package.searchers[2]
  chunk_cache.install()
  check.equal(package.searchers[2], installed)
end)

it("repeated require returns fresh module tables", function()
  chunk_cache.install()
  _write_module("local M = { counter = 0 }\nM.counter = M.counter + 1\nreturn M\n")

  local first = require(_MODULE_NAME)
  _evict()
  local second = require(_MODULE_NAME)

  check.equal(first == second, false)
  -- 顶层代码逐次重执行:每个新实例的模块态都从初始值重算(隔离语义不变)。
  check.equal(first.counter, 1)
  check.equal(second.counter, 1)
end)

it("second load serves cached chunk", function()
  chunk_cache.install()
  _write_module("return { version = 1 }\n")

  local first = require(_MODULE_NAME)
  check.equal(first.version, 1)
  check.equal(chunk_cache.stats().size >= 1, true)

  -- 文件内容已变,但同路径重复 require 走缓存原型(进程内不感知磁盘变化)。
  _evict()
  _write_module("return { version = 2 }\n")
  local second = require(_MODULE_NAME)
  check.equal(second.version, 1)
end)

it("missing module returns search error string", function()
  chunk_cache.install()
  local ok, err = pcall(require, "chunk_cache_mod_that_does_not_exist")
  check.equal(ok, false)
  check.matches("module 'chunk_cache_mod_that_does_not_exist' not found", tostring(err), 1, true)
end)

it("syntax error raises load error", function()
  chunk_cache.install()
  _write_module("this is not valid lua\n")
  local ok, err = pcall(require, _MODULE_NAME)
  check.equal(ok, false)
  check.matches("error loading module", tostring(err), 1, true)
end)

end)

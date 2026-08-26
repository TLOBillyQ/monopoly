---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/packages/luaunit_runner/test/test_chunk_cache.lua") end
require("test.bootstrap").install_package_paths()

local lu = require("luaunit")
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

TestChunkCache = {}

function TestChunkCache:setUp()
  fs_lib.remove_path(_TMP_ROOT)
  chunk_cache.reset()
  _evict()
  -- package.path 是进程全局,模块态全进程共享(#428)后更要显式装回,
  -- 否则本文件的临时路径会泄漏给同 worker 后续 spec。
  self._saved_package_path = package.path
  package.path = package.path .. ";" .. _TMP_ROOT .. "/?.lua"
end

function TestChunkCache:tearDown()
  package.path = self._saved_package_path
  fs_lib.remove_path(_TMP_ROOT)
  chunk_cache.reset()
  _evict()
end

-- 车道 runner 启动时已全局 install,这里只钉幂等性:重复 install 不换 searcher。
function TestChunkCache:test_install_is_idempotent()
  chunk_cache.install()
  local installed = package.searchers[2]
  chunk_cache.install()
  lu.assertIs(package.searchers[2], installed)
end

function TestChunkCache:test_repeated_require_returns_fresh_module_tables()
  chunk_cache.install()
  _write_module("local M = { counter = 0 }\nM.counter = M.counter + 1\nreturn M\n")

  local first = require(_MODULE_NAME)
  _evict()
  local second = require(_MODULE_NAME)

  lu.assertIs(first == second, false)
  -- 顶层代码逐次重执行:每个新实例的模块态都从初始值重算(隔离语义不变)。
  lu.assertIs(first.counter, 1)
  lu.assertIs(second.counter, 1)
end

function TestChunkCache:test_second_load_serves_cached_chunk()
  chunk_cache.install()
  _write_module("return { version = 1 }\n")

  local first = require(_MODULE_NAME)
  lu.assertIs(first.version, 1)
  lu.assertIs(chunk_cache.stats().size >= 1, true)

  -- 文件内容已变,但同路径重复 require 走缓存原型(进程内不感知磁盘变化)。
  _evict()
  _write_module("return { version = 2 }\n")
  local second = require(_MODULE_NAME)
  lu.assertIs(second.version, 1)
end

function TestChunkCache:test_missing_module_returns_search_error_string()
  chunk_cache.install()
  local ok, err = pcall(require, "chunk_cache_mod_that_does_not_exist")
  lu.assertIs(ok, false)
  lu.assertStrContains(tostring(err), "module 'chunk_cache_mod_that_does_not_exist' not found")
end

function TestChunkCache:test_syntax_error_raises_load_error()
  chunk_cache.install()
  _write_module("this is not valid lua\n")
  local ok, err = pcall(require, _MODULE_NAME)
  lu.assertIs(ok, false)
  lu.assertStrContains(tostring(err), "error loading module")
end

return TestChunkCache

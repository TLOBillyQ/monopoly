require("test.bootstrap").install_package_paths()
local loader = require("packages.test_runner.cache_loader")
local root = require("test.support.luassert_loader").repo_root()
local mode = arg[1]
if mode == "uninstalled" then
  assert(loader.verified_module("luassert") == nil)
elseif mode == "adopted" or mode == "adopt_unpinned" then
  -- uml crap 的钉死环境:只剩仓根与项目缓存两类搜索模板,busted 先于项目代码装载。
  local share = root .. "/.toolcache/luarocks/share/lua/5.4"
  package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. share .. "/?.lua;" .. share .. "/?/init.lua"
  package.cpath = root .. "/.toolcache/luarocks/lib/lua/5.4/?.dll"
  if mode == "adopt_unpinned" then package.path = package.path .. ";C:/elsewhere/?.lua" end
  require("busted.core")()
  require("busted")
  local object = require("luassert")
  loader.adopt_preloaded(root)
  assert(loader.verified_module("luassert") == object)
  require("test.support.scenario_suites.shared.helpers")
elseif mode == "injected" then
  package.loaded.luassert = {}
  require("test.support.scenario_suites.shared.helpers")
else
  loader.install(root)
  require("busted.core")()
  require("busted")
  local object = require("luassert")
  require("luassert.spy")
  if mode == "replaced" then
    package.loaded["luassert.spy"] = {}
    require("test.support.scenario_suites.shared.helpers")
  else
    assert(loader.verified_module("luassert") == object)
    assert(loader.verified_module("unknown") == nil)
    require("test.support.scenario_suites.shared.helpers")
  end
end

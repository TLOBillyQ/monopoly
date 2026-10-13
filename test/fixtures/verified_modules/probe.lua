require("test.bootstrap").install_package_paths()
local loader = require("packages.test_runner.cache_loader")
local root = require("test.support.luassert_loader").repo_root()
local mode = arg[1]
if mode == "uninstalled" then
  assert(loader.verified_module("luassert") == nil)
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

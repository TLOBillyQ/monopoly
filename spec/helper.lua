--- Busted helper auto-loaded via .busted; sets package.path, installs Eggy fakes,
--- hooks per-test refresh. See tests/bootstrap.lua and spec/env_runtime.lua.

require("tests.bootstrap")

local env_runtime = require("spec.env_runtime")
env_runtime.refresh()

local ok, busted = pcall(require, "busted")
if ok and type(busted.subscribe) == "function" then
  busted.subscribe({ "test", "start" }, function()
    math.randomseed(1)
    env_runtime.refresh()
  end)
end

return env_runtime

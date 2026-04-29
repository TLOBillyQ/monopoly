--- Busted helper auto-loaded via .busted; sets package.path, installs Eggy fakes,
--- hooks per-test refresh. See spec/bootstrap.lua and spec/env_runtime.lua.

-- Activate luacov only when needed and only if not already initialized
-- by busted's -c flag. Double-init breaks luacov's on-exit finalizer
-- (the second init runs the prior finalizer early, disables the hook,
-- and saves empty stats). Guarded so normal busted runs are untouched
-- and never co-resident with crap4lua in the same process.
if os.getenv("LUACOV") == "1" or rawget(_G, "_LUACOV_RUNNING") == true then
  local ok, runner = pcall(require, "luacov.runner")
  if ok and not runner.initialized then
    runner.init()
  end
end

require("spec.bootstrap")

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

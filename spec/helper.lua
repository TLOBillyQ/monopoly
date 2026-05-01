--- Busted helper auto-loaded via .busted; sets package.path and installs Eggy fakes.
--- Specs that need per-test runtime refresh opt in explicitly.

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

return env_runtime

local bootstrap = require("tests.bootstrap")
local behavior = require("tests.behavior")
local contract = require("tests.contract")
local guard = require("tests.guard")

bootstrap.install_package_paths()

local _timing_enabled = os.getenv("MONO_TEST_TIMING") == "1"
local wall_clock = _timing_enabled and require("tests.support.wall_clock") or nil

local function _run_lane(name, fn, timings)
  if not _timing_enabled then
    fn()
    return
  end

  local _, timing = wall_clock.measure(fn)
  timings[#timings + 1] = {
    name = name,
    elapsed_ms = timing.elapsed_ms,
    source = timing.source,
  }
end

local timings = {}
local total_timer = _timing_enabled and wall_clock.start() or nil

_run_lane("behavior", behavior.run, timings)
_run_lane("contract", contract.run, timings)
_run_lane("guard", guard.run, timings)

if _timing_enabled then
  local total_timing = wall_clock.finish(total_timer)
  print("")
  print(string.format("[regression] wall total=%dms source=%s", total_timing.elapsed_ms, total_timing.source))
  print("[regression] lane timings:")
  for _, entry in ipairs(timings) do
    print(string.format("  %6dms  %s", entry.elapsed_ms, tostring(entry.name)))
  end
end

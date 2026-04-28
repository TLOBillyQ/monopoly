local bootstrap = require("tests.bootstrap")
local behavior = require("tests.behavior")
local guard = require("tests.guard")
local common = require("tools.shared.lib.common")
local timing_summary = require("tests.support.timing_summary")

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

local function _run_contract_lane()
  local ok, err = common.run_command({
    os.getenv("HOME") .. "/.luarocks/bin/busted",
    "--helper=spec/helper.lua",
    "--run=contract",
  })
  if not ok then
    error("contract lane failed: " .. tostring(err))
  end
end

local timings = {}
local total_timer = _timing_enabled and wall_clock.start() or nil

_run_lane("behavior", behavior.run, timings)
_run_lane("contract", _run_contract_lane, timings)
_run_lane("guard", guard.run, timings)

if _timing_enabled then
  local total_timing = wall_clock.finish(total_timer)
  timing_summary.print_script_summary("regression", total_timing.elapsed_ms, timings, { source = total_timing.source })
end

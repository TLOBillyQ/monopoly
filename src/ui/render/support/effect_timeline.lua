local runtime_ports = require("src.foundation.ports.runtime_ports")

local effect_timeline = {}

local function _resolve_scheduler(opts)
  local scheduler = opts and opts.schedule or nil
  if type(scheduler) == "function" then
    return scheduler
  end
  return runtime_ports.schedule
end

function effect_timeline.run_step(delay, callback, opts)
  if type(callback) ~= "function" then
    return false
  end

  local scheduler = _resolve_scheduler(opts)
  scheduler(delay or 0, callback)
  return true
end

function effect_timeline.play(spec)
  if type(spec) ~= "table" then
    return false
  end

  if type(spec.show) == "function" then
    spec.show()
  end

  for _, step in ipairs(spec.steps or {}) do
    effect_timeline.run_step(step.delay, step.run, spec)
  end

  if type(spec.cleanup) == "function" or type(spec.follow_up) == "function" then
    effect_timeline.run_step(spec.cleanup_delay or 0, function()
      if type(spec.cleanup) == "function" then
        spec.cleanup()
      end
      if type(spec.follow_up) == "function" then
        spec.follow_up()
      end
    end, spec)
  end

  return true
end

function effect_timeline.finish(cleanup, follow_up)
  if type(cleanup) == "function" then
    cleanup()
  end
  if type(follow_up) == "function" then
    follow_up()
  end
  return true
end

return effect_timeline

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

return effect_timeline

--[[ mutate4lua-manifest
version=2
projectHash=7e02606d34a25d14
scope.0.id=chunk:src/ui/render/support/effect_timeline.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=51
scope.0.semanticHash=c7bb251983f7b0b5
scope.1.id=function:_resolve_scheduler:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=11
scope.1.semanticHash=e121db33f2059bd9
scope.2.id=function:effect_timeline.run_step:13
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=21
scope.2.semanticHash=6629b7b03c7c9967
scope.3.id=function:anonymous@37:37
scope.3.kind=function
scope.3.startLine=37
scope.3.endLine=44
scope.3.semanticHash=aa94086d79439831
]]

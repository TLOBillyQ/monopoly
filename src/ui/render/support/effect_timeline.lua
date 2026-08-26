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

local function _run_teardown(spec)
  if type(spec.cleanup) == "function" then
    spec.cleanup()
  end
  if type(spec.follow_up) == "function" then
    spec.follow_up()
  end
end

local function _schedule_teardown(spec)
  if type(spec.cleanup) ~= "function" and type(spec.follow_up) ~= "function" then
    return
  end
  effect_timeline.run_step(spec.cleanup_delay or 0, function()
    _run_teardown(spec)
  end, spec)
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

  _schedule_teardown(spec)

  return true
end

return effect_timeline

--[[ mutate4lua-manifest
version=4
projectHash=6ca8cff9e66a3909
scope.0.id=chunk:src/ui/render/support/effect_timeline.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=60
scope.0.semanticHash=da2dce4cb47f1d3e
scope.1.id=function:_resolve_scheduler
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=11
scope.1.semanticHash=f0f4cddb5f1bd067
scope.2.id=function:effect_timeline.run_step
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=21
scope.2.semanticHash=e1ade4b36afad8c3
scope.3.id=function:_run_teardown
scope.3.kind=function
scope.3.startLine=23
scope.3.endLine=30
scope.3.semanticHash=48519020bdffd45b
scope.4.id=function:_schedule_teardown
scope.4.kind=function
scope.4.startLine=32
scope.4.endLine=39
scope.4.semanticHash=f4aecab270c7583a
scope.5.id=function:<anonymous>
scope.5.kind=function
scope.5.startLine=36
scope.5.endLine=38
scope.5.semanticHash=600a75ce96a391b3
scope.6.id=function:effect_timeline.play
scope.6.kind=function
scope.6.startLine=41
scope.6.endLine=57
scope.6.semanticHash=4ee3e6b43f1a5e1e
]]

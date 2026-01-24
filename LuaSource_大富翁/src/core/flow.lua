local Flow = {}
Flow.__index = Flow


function Flow.new(opts)
  local self = {
    states = opts.states or {},
    current = opts.start or nil,
    args = opts.args or {},
    running = false,
  }
  return setmetatable(self, Flow)
end

function Flow:step()
  if not self.current then
    return nil
  end
  local fn = self.states[self.current]
  assert(fn, "flow state not found: " .. tostring(self.current))
  local next_state, next_args = fn(self.args)
  self.current = next_state
  self.args = next_args or {}
  return self.current
end

return Flow
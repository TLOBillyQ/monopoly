local session_clock = {}
session_clock.__index = session_clock

function session_clock.new(opts)
  opts = opts or {}
  local instance = {
    now_seconds = opts.start_seconds or 0,
  }
  setmetatable(instance, session_clock)
  return instance
end

function session_clock:step(dt)
  local delta = dt or 0
  if delta < 0 then
    delta = 0
  end
  self.now_seconds = self.now_seconds + delta
  return self.now_seconds
end

function session_clock:now()
  return self.now_seconds
end

return session_clock

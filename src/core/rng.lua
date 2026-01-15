local RNG = {}
RNG.__index = RNG


local MOD = 0x100000000
local MULT = 1664525
local INC = 1013904223

function RNG.new(seed, state)
  local self = {
    seed = seed or os.time(),
    state = state or (seed or os.time()),
  }
  return setmetatable(self, RNG)
end

function RNG:next_raw()
  self.state = (MULT * self.state + INC) % MOD
  if self._store and self._store.set then
    self._store:set({ "rng" }, self:snapshot())
  end
  return self.state
end

function RNG:next_float()
  return self:next_raw() / MOD
end

function RNG:next_int(min, max)
  min = min or 0
  max = max or 1
  local span = max - min + 1
  local v = self:next_raw() % span
  return min + v
end

function RNG:snapshot()
  return { seed = self.seed, state = self.state }
end

return RNG

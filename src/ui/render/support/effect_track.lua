local runtime_ports = require("src.foundation.ports.runtime_ports")

local effect_track = {}

local active_tokens = {}
local next_token_id = 1
local coalesce_policies = {
  cash_receive = "sum",
}
local timeout_seconds = 10.0

local function _now()
  return runtime_ports.wall_now_seconds()
end

local function _active_count()
  local count = 0
  for _ in pairs(active_tokens) do
    count = count + 1
  end
  return count
end

function effect_track.spawn(id, kind, duration, on_complete)
  local token_id = next_token_id
  next_token_id = next_token_id + 1
  local token = {
    id = id,
    token_id = token_id,
    kind = kind,
    duration = duration or 0,
    on_complete = on_complete,
    spawned_at = _now(),
    completed = false,
  }
  active_tokens[token_id] = token

  local effective_timeout = (duration or 0) + timeout_seconds
  runtime_ports.schedule(effective_timeout, function()
    if not token.completed then
      effect_track.complete(token)
    end
  end)

  return token
end

function effect_track.complete(token)
  if token == nil or token.completed then
    return false
  end
  token.completed = true
  active_tokens[token.token_id] = nil
  if type(token.on_complete) == "function" then
    token.on_complete(token)
  end
  return true
end

function effect_track.cancel(token)
  if token == nil or token.completed then
    return false
  end
  token.completed = true
  active_tokens[token.token_id] = nil
  return true
end

function effect_track.is_idle()
  return _active_count() == 0
end

function effect_track.await_all(callback)
  if effect_track.is_idle() then
    if type(callback) == "function" then
      callback()
    end
    return true
  end

  local function _poll()
    if effect_track.is_idle() then
      if type(callback) == "function" then
        callback()
      end
      return
    end
    runtime_ports.schedule(0.05, _poll)
  end
  runtime_ports.schedule(0.05, _poll)
  return false
end

function effect_track.pressure()
  local count = _active_count()
  if count <= 1 then
    return 0
  end
  if count <= 3 then
    return 0.3
  end
  if count <= 6 then
    return 0.6
  end
  return 0.9
end

local pressure_scale = {
  { threshold = 0,   scale = 1.0 },
  { threshold = 0.3, scale = 0.5 },
  { threshold = 0.6, scale = 0.25 },
  { threshold = 0.9, scale = 0.15 },
}

function effect_track.scaled_duration(base)
  local p = effect_track.pressure()
  local scale = 1.0
  for i = #pressure_scale, 1, -1 do
    if p >= pressure_scale[i].threshold then
      scale = pressure_scale[i].scale
      break
    end
  end
  return base * scale
end

function effect_track.coalesce_policy(kind)
  return coalesce_policies[kind]
end

function effect_track.coalesce_queue(queue)
  if type(queue) ~= "table" or #queue <= 1 then
    return queue
  end

  local p = effect_track.pressure()
  if p < 0.6 then
    return queue
  end

  local result = {}
  local i = 1
  while i <= #queue do
    local anim = queue[i]
    local policy = coalesce_policies[anim.kind]
    if policy == "sum" then
      local merged = {}
      for k, v in pairs(anim) do
        merged[k] = v
      end
      local j = i + 1
      while j <= #queue and queue[j].kind == anim.kind do
        local next_anim = queue[j]
        if policy == "sum" and merged.amount and next_anim.amount then
          merged.amount = merged.amount + next_anim.amount
        end
        j = j + 1
      end
      merged.coalesced_count = j - i
      result[#result + 1] = merged
      i = j
    else
      result[#result + 1] = anim
      i = i + 1
    end
  end
  return result
end

function effect_track.reset()
  active_tokens = {}
  next_token_id = 1
end

function effect_track.active_count()
  return _active_count()
end

return effect_track

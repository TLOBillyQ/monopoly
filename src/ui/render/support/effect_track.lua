local runtime_ports = require("src.foundation.ports.runtime_ports")

local effect_track = {}

local active_tokens = {}
local next_token_id = 1
local coalesce_policies = {
  cash_receive = "sum",
}
local timeout_seconds = 10.0

local function _active_count()
  local count = 0
  for _ in pairs(active_tokens) do
    count = count + 1
  end
  return count
end

local function _complete(token)
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

function effect_track.spawn(id, kind, duration, on_complete)
  local token_id = next_token_id
  next_token_id = next_token_id + 1
  local token = {
    id = id,
    token_id = token_id,
    kind = kind,
    duration = duration or 0,
    on_complete = on_complete,
    spawned_at = runtime_ports.wall_now_seconds(),
    completed = false,
  }
  active_tokens[token_id] = token

  local effective_timeout = (duration or 0) + timeout_seconds
  runtime_ports.schedule(effective_timeout, function()
    if not token.completed then
      _complete(token)
    end
  end)

  return token
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

local function _pressure()
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
  local p = _pressure()
  local scale = 1.0
  for i = #pressure_scale, 1, -1 do
    if p >= pressure_scale[i].threshold then
      scale = pressure_scale[i].scale
      break
    end
  end
  return base * scale
end

function effect_track.coalesce_queue(queue)
  if type(queue) ~= "table" or #queue <= 1 then
    return queue
  end

  local p = _pressure()
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

return effect_track

--[[ mutate4lua-manifest
version=2
projectHash=13453902162570c8
scope.0.id=chunk:src/ui/render/support/effect_track.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=168
scope.0.semanticHash=6374347aa3110596
scope.1.id=function:_complete:20
scope.1.kind=function
scope.1.startLine=20
scope.1.endLine=30
scope.1.semanticHash=39458c09af9eafdf
scope.2.id=function:anonymous@47:47
scope.2.kind=function
scope.2.startLine=47
scope.2.endLine=51
scope.2.semanticHash=d0fe0515ed287469
scope.3.id=function:effect_track.spawn:32
scope.3.kind=function
scope.3.startLine=32
scope.3.endLine=54
scope.3.semanticHash=e4a98d6a05649fde
scope.4.id=function:effect_track.cancel:56
scope.4.kind=function
scope.4.startLine=56
scope.4.endLine=63
scope.4.semanticHash=985bbf87e202387c
scope.5.id=function:effect_track.is_idle:65
scope.5.kind=function
scope.5.startLine=65
scope.5.endLine=67
scope.5.semanticHash=dab8e23aaa82547d
scope.6.id=function:_poll:77
scope.6.kind=function
scope.6.startLine=77
scope.6.endLine=85
scope.6.semanticHash=37c2ca07255f1c32
scope.7.id=function:effect_track.await_all:69
scope.7.kind=function
scope.7.startLine=69
scope.7.endLine=88
scope.7.semanticHash=a2de64746f5da157
scope.8.id=function:_pressure:90
scope.8.kind=function
scope.8.startLine=90
scope.8.endLine=102
scope.8.semanticHash=c06c680261c94035
scope.9.id=function:effect_track.reset:162
scope.9.kind=function
scope.9.startLine=162
scope.9.endLine=165
scope.9.semanticHash=68090efcc3e618f8
]]

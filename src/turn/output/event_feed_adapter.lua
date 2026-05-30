local event_log = require("src.state.event_log")
local timing = require("src.config.gameplay.timing")
local logger = require("src.foundation.log")
local tip_policy = require("src.config.tip_policy")
local tip_queue = require("src.foundation.tips")

local Adapter = {}
Adapter.__index = Adapter

function Adapter.new(game)
  local self = setmetatable({}, Adapter)
  self.game = game
  game.state = game.state or {}
  game.state.event_log = game.state.event_log or event_log.new()
  return self
end

local function _resolve_policy(kind)
  if kind == nil then
    return nil
  end
  return tip_policy[kind]
end

local function _should_log(policy)
  if policy and policy.log == false then
    return false
  end
  return true
end

local function _should_tip(event, policy)
  if policy and policy.tip ~= nil then
    return policy.tip == true
  end
  return event.tip ~= false
end

function Adapter:publish(game, event)
  local policy = _resolve_policy(event.kind)

  if _should_log(policy) then
    event_log.append(game.state.event_log, event)
  end

  if not _should_tip(event, policy) then
    return true
  end

  local intent = {
    text = event.text,
    duration = event.tip_duration or timing.event_tip_default_seconds or 1.0,
    dedupe_key = event.tip_dedupe_key,
    blocks_inter_turn = event.blocks_inter_turn == true,
    source = event.source or ("event_feed:" .. tostring(event.kind)),
  }

  local port = game.tip_output_port
  if port and type(port.enqueue) == "function" then
    port.enqueue(game, intent)
  else
    logger.warn("[event_feed_adapter]", "tip_output_port missing, falling back to tip_queue | event:", tostring(event.kind))
    tip_queue.enqueue(intent)
  end
  return true
end

return Adapter

--[[ mutate4lua-manifest
version=2
projectHash=bd4e3bde5082e2c8
scope.0.id=chunk:src/turn/output/event_feed_adapter.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=69
scope.0.semanticHash=5bc494d708f6fb08
scope.1.id=function:Adapter.new:10
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=16
scope.1.semanticHash=face883999e16498
scope.2.id=function:_resolve_policy:18
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=23
scope.2.semanticHash=5462076533815146
scope.3.id=function:_should_log:25
scope.3.kind=function
scope.3.startLine=25
scope.3.endLine=30
scope.3.semanticHash=8b4e69cdd9059678
scope.4.id=function:_should_tip:32
scope.4.kind=function
scope.4.startLine=32
scope.4.endLine=37
scope.4.semanticHash=13dfcb5d28758b44
scope.5.id=function:Adapter:publish:39
scope.5.kind=function
scope.5.startLine=39
scope.5.endLine=66
scope.5.semanticHash=797ecaae8cf3c148
]]

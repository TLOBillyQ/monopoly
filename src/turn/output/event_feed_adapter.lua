local event_log = require("src.state.event_log")
local timing = require("src.config.gameplay.timing")
local logger = require("src.foundation.log")
local tip_policy = require("src.config.tip_policy")
local tip_queue = require("src.foundation.tips")

local Adapter = {}
Adapter.__index = Adapter

function Adapter.new(game, sync_event_log)
  local self = setmetatable({}, Adapter)
  self.game = game
  self.sync_event_log = sync_event_log
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

local function _build_tip_intent(event)
  return {
    text = event.text,
    duration = event.tip_duration or timing.event_tip_default_seconds or 1.0,
    dedupe_key = event.tip_dedupe_key,
    blocks_inter_turn = event.blocks_inter_turn == true,
    source = event.source or ("event_feed:" .. tostring(event.kind)),
  }
end

local function _enqueue_tip(game, event, intent)
  local port = game.tip_output_port
  if port and type(port.enqueue) == "function" then
    port.enqueue(game, intent)
    return
  end
  logger.warn("[event_feed_adapter]", "tip_output_port missing, falling back to tip_queue | event:", tostring(event.kind))
  tip_queue.enqueue(intent)
end

function Adapter:publish(game, event)
  local policy = _resolve_policy(event.kind)

  if _should_log(policy) then
    event_log.append(game.state.event_log, event)
    if type(self.sync_event_log) == "function" then
      self.sync_event_log()
    end
  end

  if not _should_tip(event, policy) then
    return true
  end

  _enqueue_tip(game, event, _build_tip_intent(event))
  return true
end

return Adapter

--[[ mutate4lua-manifest
version=4
projectHash=8f69ca930f46c28c
scope.0.id=chunk:src/turn/output/event_feed_adapter.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=79
scope.0.semanticHash=ea827fc27b02d719
scope.1.id=function:Adapter.new
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=17
scope.1.semanticHash=96987d0f60140636
scope.2.id=function:_resolve_policy
scope.2.kind=function
scope.2.startLine=19
scope.2.endLine=24
scope.2.semanticHash=8f913165a6b6e1c7
scope.3.id=function:_should_log
scope.3.kind=function
scope.3.startLine=26
scope.3.endLine=31
scope.3.semanticHash=9686dcafb6bfca65
scope.4.id=function:_should_tip
scope.4.kind=function
scope.4.startLine=33
scope.4.endLine=38
scope.4.semanticHash=d84877885efc637f
scope.5.id=function:_build_tip_intent
scope.5.kind=function
scope.5.startLine=40
scope.5.endLine=48
scope.5.semanticHash=57d505225e25bdc2
scope.6.id=function:_enqueue_tip
scope.6.kind=function
scope.6.startLine=50
scope.6.endLine=58
scope.6.semanticHash=8cc10fa3e6280ab9
scope.7.id=function:Adapter:publish
scope.7.kind=function
scope.7.startLine=60
scope.7.endLine=76
scope.7.semanticHash=b3e3606f45057ecc
]]

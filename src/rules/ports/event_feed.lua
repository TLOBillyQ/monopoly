local event_feed = {}

--- @param game table
--- @param event { kind: string, text: string, tip: boolean?, tip_duration: number?, tip_dedupe_key: string?, blocks_inter_turn: boolean?, source: string? }
--- @return boolean
local function _has_event_inputs(game, event)
  return game ~= nil and event ~= nil
end

local function _valid_event(event)
  return type(event.kind) == "string" and type(event.text) == "string"
end

local function _publish_port(game)
  local port = game.event_feed_port
  if port and type(port.publish) == "function" then
    return port
  end
  return nil
end

local function _bool_or_false(value)
  return value and true or false
end

function event_feed.publish(game, event)
  if not _has_event_inputs(game, event) then
    return false
  end
  if not _valid_event(event) then
    return false
  end
  local port = _publish_port(game)
  if port == nil then
    return false
  end
  return _bool_or_false(port:publish(game, event))
end

return event_feed

--[[ mutate4lua-manifest
version=4
projectHash=d0a8e60de7c926e6
scope.0.id=chunk:src/rules/ports/event_feed.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=41
scope.0.semanticHash=3396b4a3d25a17bd
scope.1.id=function:_has_event_inputs
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=8
scope.1.semanticHash=a17812a9544dad33
scope.2.id=function:_valid_event
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=12
scope.2.semanticHash=51fe5cf5ea831c5e
scope.3.id=function:_publish_port
scope.3.kind=function
scope.3.startLine=14
scope.3.endLine=20
scope.3.semanticHash=f272543e202f5632
scope.4.id=function:_bool_or_false
scope.4.kind=function
scope.4.startLine=22
scope.4.endLine=24
scope.4.semanticHash=9db1a72ec97cc3d1
scope.5.id=function:event_feed.publish
scope.5.kind=function
scope.5.startLine=26
scope.5.endLine=38
scope.5.semanticHash=b42f18342eccf8c7
]]

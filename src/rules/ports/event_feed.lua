local event_feed = {}

--- @param game table
--- @param event { kind: string, text: string, tip: boolean?, tip_duration: number?, tip_dedupe_key: string?, blocks_inter_turn: boolean?, source: string? }
--- @return boolean
function event_feed.publish(game, event)
  if not game or not event then
    return false
  end
  if type(event.kind) ~= "string" or type(event.text) ~= "string" then
    return false
  end
  local port = game.event_feed_port
  if not port or type(port.publish) ~= "function" then
    return false
  end
  return port:publish(game, event) and true or false
end

return event_feed

--[[ mutate4lua-manifest
version=2
projectHash=5b5b365f969c75d3
scope.0.id=chunk:src/rules/ports/event_feed.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=21
scope.0.semanticHash=77f8b5f1a2ebcded
scope.1.id=function:event_feed.publish:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=18
scope.1.semanticHash=bf072086970a96ed
]]

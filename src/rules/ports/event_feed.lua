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

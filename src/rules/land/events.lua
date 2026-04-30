local monopoly_event = require("src.foundation.events")

local land_events = {}
local emit = monopoly_event.emit

function land_events.apply(game, result)
  if not result or not result.event then
    return
  end
  local payload = result.payload or {}
  if result.ok == false and result.event == "rent_skipped_mountain" then
    local skip_event = monopoly_event.land.rent_skipped_mountain
    assert(skip_event ~= nil, "missing land event: rent_skipped_mountain")
    emit(skip_event, payload)
    return
  end
  local event_key = monopoly_event.land[result.event]
  assert(event_key ~= nil, "missing land event: " .. tostring(result.event))
  emit(event_key, payload)

  if result.bankrupt_reason then
    local bankruptcy_port = require("src.rules.ports.bankruptcy")
    bankruptcy_port.eliminate(game, payload.player, { reason = result.bankrupt_reason })
  end
end

return land_events


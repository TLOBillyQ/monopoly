local game_event = require("game.event")

local event = {}
local emit = game_event.emit

function event.apply(game, result)
  if not result or not result.event then
    return
  end
  local payload = result.payload or {}
  if result.ok == false and result.event == "rent_skipped_mountain" then
    local skip_event = game_event.land.rent_skipped_mountain
    assert(skip_event ~= nil, "missing land event: rent_skipped_mountain")
    emit(skip_event, payload)
    return
  end
  local event_key = game_event.land[result.event]
  assert(event_key ~= nil, "missing land event: " .. tostring(result.event))
  emit(event_key, payload)

  if result.bankrupt_reason then
    local bankrupt = require("game.rule.bankrupt")
    bankrupt.eliminate(game, payload.player, { reason = result.bankrupt_reason })
  end
end

return event

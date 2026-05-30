local monopoly_event = require("src.foundation.events")
local event_feed = require("src.rules.ports.event_feed")
local event_kinds = require("src.config.gameplay.event_kinds")
local bankruptcy_port = require("src.rules.ports.bankruptcy")

local land_events = {}
local emit = monopoly_event.emit

local _ef_kind_map = {
  rent_skipped_mountain = event_kinds.rent_immune,
  strong_card_used = event_kinds.item_used,
  free_rent_used = event_kinds.item_used,
  rent_paid = event_kinds.rent_paid,
  rent_bankrupt = event_kinds.bankruptcy,
  tax_free = event_kinds.tax_immune,
  tax_paid = event_kinds.tax_paid,
}

local function _publish_to_feed(game, result, payload)
  local ef_kind = _ef_kind_map[result.event]
  if not ef_kind or type(payload.text) ~= "string" then
    return
  end
  event_feed.publish(game, {
    kind = ef_kind,
    text = payload.text,
  })
  if result.event == "rent_paid" and type(payload.multiplier_text) == "string" then
    event_feed.publish(game, {
      kind = event_kinds.rent_multiplier_breakdown,
      text = payload.multiplier_text,
    })
  end
end

function land_events.apply(game, result)
  if not result or not result.event then
    return
  end
  local payload = result.payload or {}
  if result.ok == false and result.event == "rent_skipped_mountain" then
    local skip_event = monopoly_event.land.rent_skipped_mountain
    assert(skip_event ~= nil, "missing land event: rent_skipped_mountain")
    emit(skip_event, payload)
    _publish_to_feed(game, result, payload)
    return
  end
  local event_key = monopoly_event.land[result.event]
  assert(event_key ~= nil, "missing land event: " .. tostring(result.event))
  emit(event_key, payload)
  _publish_to_feed(game, result, payload)

  if result.bankrupt_reason then
    bankruptcy_port.eliminate(game, payload.player, { reason = result.bankrupt_reason })
  end
end

return land_events

--[[ mutate4lua-manifest
version=2
projectHash=8566ed14908c6e24
scope.0.id=chunk:src/rules/land/events.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=60
scope.0.semanticHash=128c1eeb9ec43f6b
scope.1.id=function:_publish_to_feed:19
scope.1.kind=function
scope.1.startLine=19
scope.1.endLine=34
scope.1.semanticHash=cbe674567c627376
scope.2.id=function:land_events.apply:36
scope.2.kind=function
scope.2.startLine=36
scope.2.endLine=56
scope.2.semanticHash=ca5435df81064282
]]

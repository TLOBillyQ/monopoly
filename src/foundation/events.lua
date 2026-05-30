local runtime_ports = require("src.foundation.ports.runtime_ports")

local monopoly_events = {
  movement = {
    moved = "mv.moved",
    passed_start = "mv.passed_start",
    roadblock_hit = "mv.roadblock_hit",
    market_interrupt = "mv.market_interrupt",
  },
  land = {
    rent_skipped_mountain = "land.rent_skipped_mountain",
    strong_card_used = "land.strong_card_used",
    free_rent_used = "land.free_rent_used",
    rent_paid = "land.rent_paid",
    rent_bankrupt = "land.rent_bankrupt",
    tax_free = "land.tax_free",
    tax_paid = "land.tax_paid",
    mine_hit = "land.mine_hit",
    tile_upgraded = "land.tile_upgraded",
  },
  market = {
    bought_item = "mk.bought_item",
    auto_skip = "mk.auto_skip",
    buy_failed = "mk.buy_failed",
    inventory_full = "mk.inventory_full",
  },
  chance = {
    applied = "ch.applied",
  },
  feedback = {
    turn_started = "fb.turn_started",
    status_applied = "fb.status_applied",
    deity_applied = "fb.deity_applied",
    angel_immune_blocked = "fb.angel_immune_blocked",
    bankruptcy = "fb.bankruptcy",
  },
  game = {
    finished = "gm.finished",
  },
  intent = {
    need_choice = "it.need_choice",
    push_popup = "it.push_popup",
  },
}

local function _emit_event(kind, payload)
  runtime_ports.emit_event(kind, payload or {}, {
    feature_key = "event." .. tostring(kind),
  })
end

function monopoly_events.emit_intent(kind, payload)
  assert(kind ~= nil, "missing intent kind")
  local event_name = assert(monopoly_events.intent[kind], "missing intent event: " .. tostring(kind))
  _emit_event(event_name, payload)
  return event_name
end

function monopoly_events.emit(kind, payload)
  _emit_event(kind, payload)
end

return monopoly_events

--[[ mutate4lua-manifest
version=2
projectHash=3d0abed277a2a256
scope.0.id=chunk:src/foundation/events.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=64
scope.0.semanticHash=78d60c346c74048a
scope.1.id=function:_emit_event:46
scope.1.kind=function
scope.1.startLine=46
scope.1.endLine=50
scope.1.semanticHash=027a0ad956ce370f
scope.2.id=function:monopoly_events.emit_intent:52
scope.2.kind=function
scope.2.startLine=52
scope.2.endLine=57
scope.2.semanticHash=252fd1a1ce870930
scope.3.id=function:monopoly_events.emit:59
scope.3.kind=function
scope.3.startLine=59
scope.3.endLine=61
scope.3.semanticHash=7d54b5eef0b4cc7f
]]

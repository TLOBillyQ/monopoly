local runtime_ports = require("src.core.ports.runtime_ports")

local monopoly_events = {
  movement = {
    moved = "mv.moved",
    passed_start = "mv.passed_start",
    roadblock_hit = "mv.roadblock_hit",
    market_interrupt = "mv.market_interrupt",
    steal_interrupt = "mv.steal_interrupt",
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
    bought_vehicle = "mk.bought_vehicle",
    auto_skip = "mk.auto_skip",
    buy_failed = "mk.buy_failed",
  },
  chance = {
    applied = "ch.applied",
  },
  feedback = {
    turn_started = "fb.turn_started",
    status_applied = "fb.status_applied",
    deity_applied = "fb.deity_applied",
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

function monopoly_events.resolve_intent(kind)
  assert(kind ~= nil, "missing intent kind")
  local intent = assert(monopoly_events.intent, "missing monopoly_events.intent")
  local event_name = intent[kind]
  assert(event_name ~= nil, "missing intent event: " .. tostring(kind))
  return event_name
end

function monopoly_events.emit_intent(kind, payload)
  local event_name = monopoly_events.resolve_intent(kind)
  _emit_event(event_name, payload)
  return event_name
end

function monopoly_events.emit(kind, payload)
  _emit_event(kind, payload)
end

return monopoly_events

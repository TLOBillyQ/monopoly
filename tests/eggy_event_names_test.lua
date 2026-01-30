local MONOPOLY_EVENT = require("Globals.MonopolyEvents")

local function assert_event(path, value)
  assert(type(value) == "string" and value ~= "", "missing event: " .. path)
end

assert_event("movement.moved", MONOPOLY_EVENT.movement.moved)
assert_event("movement.passed_start", MONOPOLY_EVENT.movement.passed_start)
assert_event("movement.roadblock_hit", MONOPOLY_EVENT.movement.roadblock_hit)
assert_event("movement.market_interrupt", MONOPOLY_EVENT.movement.market_interrupt)
assert_event("movement.steal_interrupt", MONOPOLY_EVENT.movement.steal_interrupt)

assert_event("land.rent_skipped_mountain", MONOPOLY_EVENT.land.rent_skipped_mountain)
assert_event("land.strong_card_used", MONOPOLY_EVENT.land.strong_card_used)
assert_event("land.free_rent_used", MONOPOLY_EVENT.land.free_rent_used)
assert_event("land.rent_paid", MONOPOLY_EVENT.land.rent_paid)
assert_event("land.rent_bankrupt", MONOPOLY_EVENT.land.rent_bankrupt)
assert_event("land.tax_free", MONOPOLY_EVENT.land.tax_free)
assert_event("land.tax_paid", MONOPOLY_EVENT.land.tax_paid)

assert_event("market.bought_item", MONOPOLY_EVENT.market.bought_item)
assert_event("market.bought_vehicle", MONOPOLY_EVENT.market.bought_vehicle)
assert_event("market.auto_skip", MONOPOLY_EVENT.market.auto_skip)
assert_event("market.buy_failed", MONOPOLY_EVENT.market.buy_failed)

assert_event("chance.applied", MONOPOLY_EVENT.chance.applied)

print("ok - eggy event names")

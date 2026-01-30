local MONOPOLY_EVENT = {
  movement = {
    moved = "monopoly.movement.moved",
    passed_start = "monopoly.movement.passed_start",
    roadblock_hit = "monopoly.movement.roadblock_hit",
    market_interrupt = "monopoly.movement.market_interrupt",
    steal_interrupt = "monopoly.movement.steal_interrupt",
  },
  land = {
    rent_skipped_mountain = "monopoly.land.rent_skipped_mountain",
    strong_card_used = "monopoly.land.strong_card_used",
    free_rent_used = "monopoly.land.free_rent_used",
    rent_paid = "monopoly.land.rent_paid",
    rent_bankrupt = "monopoly.land.rent_bankrupt",
    tax_free = "monopoly.land.tax_free",
    tax_paid = "monopoly.land.tax_paid",
  },
  market = {
    bought_item = "monopoly.market.bought_item",
    bought_vehicle = "monopoly.market.bought_vehicle",
    auto_skip = "monopoly.market.auto_skip",
    buy_failed = "monopoly.market.buy_failed",
  },
  chance = {
    applied = "monopoly.chance.applied",
  },
}

return MONOPOLY_EVENT

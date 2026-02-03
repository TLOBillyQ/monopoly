local monopoly_event = {
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
  intent = {
    need_choice = "it.need_choice",
    push_popup = "it.push_popup",
  },
}

return monopoly_event

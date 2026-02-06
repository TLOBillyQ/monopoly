local events = {}

events.types = {
  state_patch = "state_patch",

  clock_tick = "clock_tick",
  phase_changed = "phase_changed",

  turn_began = "turn_began",
  player_moved = "player_moved",
  move_anim_queued = "move_anim_queued",
  move_anim_confirmed = "move_anim_confirmed",

  choice_opened = "choice_opened",
  choice_resolved = "choice_resolved",

  land_bought = "land_bought",
  land_upgraded = "land_upgraded",
  rent_paid = "rent_paid",
  tax_paid = "tax_paid",
  chance_applied = "chance_applied",

  action_anim_queued = "action_anim_queued",
  action_anim_confirmed = "action_anim_confirmed",
  turn_finished = "turn_finished",

  player_cash_changed = "player_cash_changed",
  player_balance_changed = "player_balance_changed",
  player_status_set = "player_status_set",
  player_seat_set = "player_seat_set",
  player_property_set = "player_property_set",
  player_eliminated = "player_eliminated",

  item_granted = "item_granted",
  item_consumed = "item_consumed",
  item_discarded = "item_discarded",

  tile_owner_set = "tile_owner_set",
  tile_level_set = "tile_level_set",
  overlay_roadblock_set = "overlay_roadblock_set",
  overlay_mine_set = "overlay_mine_set",
  market_limit_set = "market_limit_set",

  player_offline = "player_offline",
  player_online = "player_online",
  player_auto_set = "player_auto_set",
  reconnect_grace_set = "reconnect_grace_set",
  match_frozen = "match_frozen",
  match_unfrozen = "match_unfrozen",
  match_finished = "match_finished",
}

function events.new(event_type, payload)
  return {
    type = event_type,
    payload = payload or {},
  }
end

function events.patch(path, value)
  return events.new(events.types.state_patch, {
    path = path,
    value = value,
  })
end

return events

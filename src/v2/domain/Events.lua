local events = {}

events.types = {
  clock_tick = "clock_tick",
  turn_began = "turn_began",
  player_moved = "player_moved",
  move_anim_queued = "move_anim_queued",
  move_anim_confirmed = "move_anim_confirmed",
  choice_opened = "choice_opened",
  choice_resolved = "choice_resolved",
  tile_bought = "tile_bought",
  tile_upgraded = "tile_upgraded",
  rent_paid = "rent_paid",
  action_anim_queued = "action_anim_queued",
  action_anim_confirmed = "action_anim_confirmed",
  turn_finished = "turn_finished",
  player_offline = "player_offline",
  player_online = "player_online",
  player_auto_set = "player_auto_set",
  reconnect_grace_set = "reconnect_grace_set",
  match_frozen = "match_frozen",
  match_unfrozen = "match_unfrozen",
}

function events.new(event_type, payload)
  return {
    type = event_type,
    payload = payload or {},
  }
end

return events

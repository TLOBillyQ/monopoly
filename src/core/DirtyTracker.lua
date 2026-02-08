local dirty_tracker = {}

function dirty_tracker.new()
  return {
    any = false,
    players = false,
    board_tiles = false,
    turn = false,
    market = false,
    turn_countdown = false,
    inventory_ids = {},
  }
end

function dirty_tracker.mark(d, domain)
  d.any = true
  d[domain] = true
end

function dirty_tracker.mark_countdown(d)
  d.any = true
  d.turn_countdown = true
end

function dirty_tracker.mark_inventory(d, pid)
  d.any = true
  d.players = true
  d.inventory_ids[pid] = true
end

function dirty_tracker.consume(d)
  local snapshot = {
    any = d.any,
    players = d.players,
    board_tiles = d.board_tiles,
    turn = d.turn,
    market = d.market,
    turn_countdown = d.turn_countdown,
    inventory_ids = d.inventory_ids,
  }
  d.any = false
  d.players = false
  d.board_tiles = false
  d.turn = false
  d.market = false
  d.turn_countdown = false
  d.inventory_ids = {}
  return snapshot
end

return dirty_tracker

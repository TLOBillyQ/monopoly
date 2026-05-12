local dirty_tracker = {}
local _dirty_keys = {
  "any",
  "players",
  "board_tiles",
  "turn",
  "market",
  "turn_countdown",
}

local valid_domains = {
  any = true,
  players = true,
  board_tiles = true,
  turn = true,
  market = true,
  turn_countdown = true,
}

function dirty_tracker.new()
  return dirty_tracker.reset({})
end

function dirty_tracker.ensure_inventory_ids(d)
  if type(d) ~= "table" then
    return nil
  end
  if type(d.inventory_ids) ~= "table" then
    d.inventory_ids = {}
  end
  return d.inventory_ids
end

function dirty_tracker.mark(d, domain)
  assert(valid_domains[domain], "unknown dirty domain: " .. tostring(domain))
  d.any = true
  d[domain] = true
end

function dirty_tracker.mark_inventory(d, pid)
  d.any = true
  d.players = true
  dirty_tracker.ensure_inventory_ids(d)[pid] = true
end

function dirty_tracker.merge_into(target, dirty)
  if type(target) ~= "table" or type(dirty) ~= "table" then
    return target
  end
  for _, key in ipairs(_dirty_keys) do
    if dirty[key] then
      target[key] = true
    end
  end
  if type(dirty.inventory_ids) == "table" then
    local inventory_ids = dirty_tracker.ensure_inventory_ids(target)
    for player_id in pairs(dirty.inventory_ids) do
      inventory_ids[player_id] = true
    end
  end
  return target
end

function dirty_tracker.reset(d)
  d.any = false
  d.players = false
  d.board_tiles = false
  d.turn = false
  d.market = false
  d.turn_countdown = false
  d.inventory_ids = {}
  return d
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
  dirty_tracker.reset(d)
  return snapshot
end

return dirty_tracker

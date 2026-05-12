local dirty_tracker = {}
local _dirty_keys = {
  "any",
  "players",
  "board_tiles",
  "turn",
  "market",
  "turn_countdown",
}

local valid_domains = {}
for _, key in ipairs(_dirty_keys) do
  valid_domains[key] = true
end

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
  for _, key in ipairs(_dirty_keys) do
    d[key] = false
  end
  d.inventory_ids = {}
  return d
end

function dirty_tracker.consume(d)
  local snapshot = {}
  for _, key in ipairs(_dirty_keys) do
    snapshot[key] = d[key]
  end
  snapshot.inventory_ids = d.inventory_ids
  dirty_tracker.reset(d)
  return snapshot
end

return dirty_tracker

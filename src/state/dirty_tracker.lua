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

function dirty_tracker.mark_turn(game)
  if game and game.dirty then
    dirty_tracker.mark(game.dirty, "turn")
  end
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

local _consume_snapshot = {}

function dirty_tracker.consume(d)
  local prev_inv = _consume_snapshot.inventory_ids
  for k in pairs(_consume_snapshot) do
    _consume_snapshot[k] = nil
  end
  for _, key in ipairs(_dirty_keys) do
    _consume_snapshot[key] = d[key]
    d[key] = false
  end
  _consume_snapshot.inventory_ids = d.inventory_ids
  if type(prev_inv) == "table" then
    for k in pairs(prev_inv) do
      prev_inv[k] = nil
    end
    d.inventory_ids = prev_inv
  else
    d.inventory_ids = {}
  end
  return _consume_snapshot
end

return dirty_tracker

--[[ mutate4lua-manifest
version=2
projectHash=17555f2e9adc8ec6
scope.0.id=chunk:src/state/dirty_tracker.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=98
scope.0.semanticHash=96307adf60a9ab20
scope.1.id=function:dirty_tracker.new:16
scope.1.kind=function
scope.1.startLine=16
scope.1.endLine=18
scope.1.semanticHash=39802000be43138f
scope.2.id=function:dirty_tracker.ensure_inventory_ids:20
scope.2.kind=function
scope.2.startLine=20
scope.2.endLine=28
scope.2.semanticHash=d5f0e69012987f0f
scope.3.id=function:dirty_tracker.mark:30
scope.3.kind=function
scope.3.startLine=30
scope.3.endLine=34
scope.3.semanticHash=bb272fc0bd9c7dcf
scope.4.id=function:dirty_tracker.mark_turn:36
scope.4.kind=function
scope.4.startLine=36
scope.4.endLine=40
scope.4.semanticHash=cf4d806a3fc78769
scope.5.id=function:dirty_tracker.mark_inventory:42
scope.5.kind=function
scope.5.startLine=42
scope.5.endLine=46
scope.5.semanticHash=6cec3511da83e5cf
]]

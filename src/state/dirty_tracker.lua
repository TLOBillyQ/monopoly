local dirty_tracker = {}
local _dirty_keys = {
  "any",
  "players",
  "board_tiles",
  "turn",
  "market",
  "turn_countdown",
  "inventory",
}

local valid_domains = {}
for _, key in ipairs(_dirty_keys) do
  valid_domains[key] = true
end

function dirty_tracker.new()
  return dirty_tracker.reset({})
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

function dirty_tracker.mark_inventory(d)
  d.any = true
  d.players = true
  d.inventory = true
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
  return target
end

function dirty_tracker.reset(d)
  for _, key in ipairs(_dirty_keys) do
    d[key] = false
  end
  return d
end

local _consume_snapshot = {}

function dirty_tracker.consume(d)
  for k in pairs(_consume_snapshot) do
    _consume_snapshot[k] = nil
  end
  for _, key in ipairs(_dirty_keys) do
    _consume_snapshot[key] = d[key]
    d[key] = false
  end
  return _consume_snapshot
end

return dirty_tracker

--[[ mutate4lua-manifest
version=4
projectHash=2164223e493ed490
scope.0.id=chunk:src/state/dirty_tracker.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=72
scope.0.semanticHash=4b062dc4ebccdb24
scope.1.id=function:dirty_tracker.new
scope.1.kind=function
scope.1.startLine=17
scope.1.endLine=19
scope.1.semanticHash=f12f0d8aec4eacc6
scope.2.id=function:dirty_tracker.mark
scope.2.kind=function
scope.2.startLine=21
scope.2.endLine=25
scope.2.semanticHash=d62b797dddd2710a
scope.3.id=function:dirty_tracker.mark_turn
scope.3.kind=function
scope.3.startLine=27
scope.3.endLine=31
scope.3.semanticHash=925d3510b6596c37
scope.4.id=function:dirty_tracker.mark_inventory
scope.4.kind=function
scope.4.startLine=33
scope.4.endLine=37
scope.4.semanticHash=33b64260960bd92f
scope.5.id=function:dirty_tracker.merge_into
scope.5.kind=function
scope.5.startLine=39
scope.5.endLine=49
scope.5.semanticHash=29b67daf921db3eb
scope.6.id=function:dirty_tracker.reset
scope.6.kind=function
scope.6.startLine=51
scope.6.endLine=56
scope.6.semanticHash=63a7ad5c4a1fcc2d
scope.7.id=function:dirty_tracker.consume
scope.7.kind=function
scope.7.startLine=60
scope.7.endLine=69
scope.7.semanticHash=e3e5b69b4291c45a
]]

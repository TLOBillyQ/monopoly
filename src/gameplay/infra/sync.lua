-- Minimal sync layer scaffold: rebuilds occupants/overlays from store if needed.
local Sync = {}

local function deep_copy(tbl)
  if type(tbl) ~= "table" then
    return tbl
  end
  local res = {}
  for k, v in pairs(tbl) do
    res[k] = deep_copy(v)
  end
  return res
end

local function restore_players(game)
  local snapshot = game.store and game.store:get({ "players" })
  if not snapshot then
    return
  end
  for _, p in ipairs(game.players) do
    local data = snapshot[p.id]
    if data then
      p.cash = data.cash
      p.position = data.position
      p.seat_id = data.seat_id
      p.eliminated = data.eliminated or false

      -- properties
      p.properties = p.properties or {}
      for k in pairs(p.properties) do
        p.properties[k] = nil
      end
      if type(data.properties) == "table" then
        for tile_id, owned in pairs(data.properties) do
          if owned then
            p.properties[tile_id] = true
          end
        end
      end

      -- status
      p.status = p.status or {}
      if type(data.status) == "table" then
        for k, v in pairs(data.status) do
          p.status[k] = deep_copy(v)
        end
      end

      -- inventory
      if p.inventory and type(data.inventory) == "table" then
        local inv = p.inventory
        inv._suspend_on_change = true
        inv.items = deep_copy(data.inventory.items or {})
        inv.max_slots = data.inventory.max_slots or inv.max_slots
        inv._suspend_on_change = false
      end
    end
  end
end

local function restore_turn(game)
  local turn = game.store and game.store:get({ "turn" })
  if not turn then
    return
  end
  game.turn_count = turn.turn_count or game.turn_count or 0
end

local function restore_overlays(game)
  local overlays = game.store and game.store:get({ "board", "overlays" })
  if overlays then
    game.overlays = overlays
  end
end

local function restore_rng(game)
  local snap = game.store and game.store:get({ "rng" })
  if snap and game.rng and game.rng.restore then
    game.rng:restore(snap)
  end
end

function Sync.sync_all(game)
  restore_players(game)
  restore_overlays(game)
  restore_turn(game)
  restore_rng(game)
  if game.rebuild_occupants then
    game:rebuild_occupants()
  end
end

return Sync

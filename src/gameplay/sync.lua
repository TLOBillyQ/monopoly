-- Minimal sync layer scaffold: rebuilds occupants/overlays from store if needed.
local Sync = {}

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
      p.properties = data.properties or {}
      p.status = data.status or p.status
    end
  end
end

local function restore_tiles(game)
  local tiles = game.store and game.store:get({ "board", "tiles" })
  if not tiles then
    return
  end
  for _, tile in ipairs(game.board.path) do
    local data = tiles[tile.id]
    if data then
      tile.owner_id = data.owner_id
      tile.level = data.level or tile.level
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
  restore_tiles(game)
  restore_overlays(game)
  restore_turn(game)
  restore_rng(game)
  if game.rebuild_occupants then
    game:rebuild_occupants()
  end
end

return Sync

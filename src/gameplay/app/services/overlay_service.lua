local OverlayService = {}

local function ensure_overlays(game)
  if not game then
    return { roadblocks = {}, mines = {} }
  end
  local store = game.store
  local overlays = store and store:get({ "board", "overlays" }) or nil
  if type(overlays) ~= "table" then
    overlays = { roadblocks = {}, mines = {} }
    if store then
      store:set({ "board", "overlays" }, overlays)
    end
  end
  overlays.roadblocks = overlays.roadblocks or {}
  overlays.mines = overlays.mines or {}
  return overlays
end

local function store_set(game, path, value)
  if game and game._store_set then
    game:_store_set(path, value)
  elseif game and game.store then
    game.store:set(path, value)
  end
end

function OverlayService.has_roadblock(game, idx)
  local overlays = ensure_overlays(game)
  return overlays and overlays.roadblocks[idx] and true or false
end

function OverlayService.has_mine(game, idx)
  local overlays = ensure_overlays(game)
  return overlays and overlays.mines[idx] and true or false
end

function OverlayService.place_roadblock(game, idx)
  if not idx then
    return
  end
  local overlays = ensure_overlays(game)
  overlays.roadblocks[idx] = true
  store_set(game, { "board", "overlays", "roadblocks", idx }, true)
end

function OverlayService.place_mine(game, idx)
  if not idx then
    return
  end
  local overlays = ensure_overlays(game)
  overlays.mines[idx] = true
  store_set(game, { "board", "overlays", "mines", idx }, true)
end

function OverlayService.clear_roadblock(game, idx)
  if not idx then
    return
  end
  local overlays = ensure_overlays(game)
  if overlays.roadblocks[idx] then
    overlays.roadblocks[idx] = nil
    store_set(game, { "board", "overlays", "roadblocks", idx }, nil)
  end
end

function OverlayService.clear_mine(game, idx)
  if not idx then
    return
  end
  local overlays = ensure_overlays(game)
  if overlays.mines[idx] then
    overlays.mines[idx] = nil
    store_set(game, { "board", "overlays", "mines", idx }, nil)
  end
end

function OverlayService.clear_all(game, idx)
  OverlayService.clear_roadblock(game, idx)
  OverlayService.clear_mine(game, idx)
end

return OverlayService

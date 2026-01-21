local Tile = {}

function Tile.build_tile_label(view, idx)
  local tile = view.board.tiles[idx]
  local label = tile.name
  local state = view.state
  local tile_state = state.board.tiles[tile.id]
  local owner_id = tile_state.owner_id
  local level = tile_state.level
  if tile.type == "land" and owner_id then
    label = label .. " Lv" .. tostring(level)
  end
  local overlays = view.board.overlays
  if overlays.roadblocks and overlays.roadblocks[idx] then
    label = label .. " 路障"
  elseif overlays.mines and overlays.mines[idx] then
    label = label .. " 地雷"
  end
  return label
end

function Tile.build_tile_detail_view(view, idx)
  if not (view and idx) then
    return nil
  end
  local tile = view.board and view.board.tiles and view.board.tiles[idx]
  if not tile then
    return nil
  end

  local detail = {
    name = tile.name .. " (" .. tile.type .. ")",
    type = tile.type,
  }

  if tile.type == "land" then
    local state = view.state
    local tile_state = state.board.tiles[tile.id]
    local owner_id = tile_state.owner_id
    local level = tile_state.level
    local owner = owner_id and state.players[owner_id] or nil
    detail.price = "价格: " .. tostring(tile.price or "-")
    detail.level = "等级: " .. tostring(level)
    if owner then
      detail.owner_label = "归属: " .. owner.name
      detail.owner_name = owner.name
      detail.has_owner = true
    else
      detail.owner_label = "归属: -"
      detail.has_owner = false
    end
  end

  local overlays = view.board.overlays
  local roadblock = overlays.roadblocks and overlays.roadblocks[idx]
  local mine = overlays.mines and overlays.mines[idx]
  detail.roadblock = roadblock and "路障: 有" or "路障: 无"
  detail.mine = mine and "地雷: 有" or "地雷: 无"
  detail.has_roadblock = not not roadblock
  detail.has_mine = not not mine

  return detail
end

return Tile

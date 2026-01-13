local UIState = require("src.adapters.love2d.ui_state")

local BoardRenderer = {}

local function get_store_state(view)
  local st = view and view.state or nil
  local board = st and st.board or nil
  return {
    tiles = (board and board.tiles) or {},
    overlays = (board and board.overlays) or { roadblocks = {}, mines = {} },
    players = st and st.players or {},
  }
end

local function build_occupants_from_store(store_players)
  local occ = {}
  if not store_players then
    return occ
  end
  for pid = 1, #store_players do
    local p = store_players[pid]
    if p and not p.eliminated and p.position then
      occ[p.position] = occ[p.position] or {}
      table.insert(occ[p.position], pid)
    end
  end
  return occ
end

local function lighten(color, amount)
  return { math.min(color[1] + amount, 1), math.min(color[2] + amount, 1), math.min(color[3] + amount, 1) }
end

local function draw_overlays(ui, overlays, rect_x, rect_y, rect_w, rect_h, idx)
  if overlays.roadblocks[idx] then
    local cx = rect_x + rect_w * 0.5
    local cy = rect_y + rect_h * 0.26
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.circle("fill", cx + 2, cy + 2, rect_w * 0.36)
    love.graphics.setColor(ui.palette.overlay.roadblock.bg)
    love.graphics.circle("fill", cx, cy, rect_w * 0.36)
    love.graphics.setColor(ui.palette.overlay.roadblock.fg)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", cx, cy, rect_w * 0.36)
    love.graphics.line(cx - rect_w * 0.2, cy - rect_w * 0.22, cx + rect_w * 0.2, cy + rect_w * 0.22)
    love.graphics.line(cx - rect_w * 0.2, cy + rect_w * 0.22, cx + rect_w * 0.2, cy - rect_w * 0.22)
    love.graphics.setLineWidth(1)
  elseif overlays.mines[idx] then
    local cx = rect_x + rect_w * 0.5
    local cy = rect_y + rect_h * 0.78
    love.graphics.setColor(ui.palette.overlay.mine.bg)
    love.graphics.circle("fill", cx, cy, 10)
    love.graphics.setColor(ui.palette.overlay.mine.ring)
    love.graphics.circle("line", cx, cy, 10)
    love.graphics.setColor(ui.palette.overlay.mine.fg)
    love.graphics.setLineWidth(2)
    love.graphics.line(cx - 6, cy - 6, cx + 6, cy + 6)
    love.graphics.line(cx - 6, cy + 6, cx + 6, cy - 6)
    love.graphics.setLineWidth(1)
  end
end

local function draw_tile(ui, idx, pos, half_cell, pad, last_visited, tile, tile_state)
  if not tile then
    return
  end
  local color = UIState.tile_color(ui, tile.type)
  if last_visited then
    color = lighten(color, 0.2)
  end

  local rect_x = pos.x - half_cell + pad
  local rect_y = pos.y - half_cell + pad
  local rect_w = ui.board.cell_size - pad * 2
  local rect_h = ui.board.cell_size - pad * 2
  if ui.hover_tile == idx or ui.selected_tile == idx then
    rect_x = rect_x - 2
    rect_y = rect_y - 2
    rect_w = rect_w + 4
    rect_h = rect_h + 4
  end

  love.graphics.setColor(color)
  love.graphics.rectangle("fill", rect_x, rect_y, rect_w, rect_h, 8, 8)
  love.graphics.setColor(0.12, 0.12, 0.12, 0.65)
  love.graphics.rectangle("line", rect_x, rect_y, rect_w, rect_h, 8, 8)

  love.graphics.setFont(ui.fonts.small)
  local name_y = rect_y + rect_h * 0.42
  love.graphics.setColor(0, 0, 0, 0.7)
  love.graphics.printf(tile.name or "-", rect_x, name_y + 1, rect_w, "center")
  love.graphics.setColor(0, 0, 0, 0.95)
  love.graphics.printf(tile.name or "-", rect_x, name_y, rect_w, "center")

  local owner_id = tile_state and tile_state.owner_id or nil
  local level = tile_state and tile_state.level or 0
  if tile.type == "land" and owner_id then
    local owner_color = ui.palette.player[owner_id] or { 0.9, 0.9, 0.9 }
    love.graphics.setColor(owner_color)
    love.graphics.rectangle("line", rect_x - 2, rect_y - 2, rect_w + 4, rect_h + 4, 9, 9)
    if level > 0 then
      love.graphics.setFont(ui.fonts.tiny)
      love.graphics.setColor(0, 0, 0, 0.88)
      love.graphics.printf("Lv" .. level, rect_x, rect_y + rect_h - 16, rect_w, "center")
    end
  end
end

local function draw_players(ui, occupants, cell_size)
  for idx, pos in ipairs(ui.board.positions) do
    local list = occupants[idx]
    if list then
      local count = #list
      for i, pid in ipairs(list) do
        local per_row = math.ceil(math.sqrt(count))
        local spacing = cell_size * 0.28
        local start = -(per_row - 1) * spacing * 0.5
        local row = math.floor((i - 1) / per_row)
        local col = (i - 1) % per_row
        local ox = pos.x + start + col * spacing
        local oy = pos.y + start + row * spacing
        local p_color = ui.palette.player[pid] or { 0.9, 0.9, 0.9 }
        love.graphics.setColor(p_color)
        love.graphics.circle("fill", ox, oy, 6)
        love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
        love.graphics.circle("line", ox, oy, 6)
      end
    end
  end
end

local function collect_last_visited(view)
  local last_visited = {}
  if view and view.last_turn and view.last_turn.move_result and view.last_turn.move_result.visited then
    for _, idx in ipairs(view.last_turn.move_result.visited) do
      last_visited[idx] = true
    end
  end
  return last_visited
end

local function tile_rect_for_overlay(ui, idx, pos, half_cell, pad)
  local rect_x = pos.x - half_cell + pad
  local rect_y = pos.y - half_cell + pad
  local rect_w = ui.board.cell_size - pad * 2
  local rect_h = ui.board.cell_size - pad * 2
  if ui.hover_tile == idx or ui.selected_tile == idx then
    rect_x = rect_x - 2
    rect_y = rect_y - 2
    rect_w = rect_w + 4
    rect_h = rect_h + 4
  end
  return rect_x, rect_y, rect_w, rect_h
end

function BoardRenderer.draw(ui, view)
  if not view or not view.board or not view.board.tiles then
    return
  end

  local st = get_store_state(view)

  local cell_size = ui.board.cell_size
  local half_cell = cell_size * 0.5
  local pad = math.min(cell_size * 0.05, 3)
  local last_visited = collect_last_visited(view)

  for idx, pos in ipairs(ui.board.positions) do
    local tile = view.board.tiles[idx]
    local tile_state = (st and st.tiles and tile and st.tiles[tile.id]) or nil
    draw_tile(ui, idx, pos, half_cell, pad, last_visited[idx], tile, tile_state)
  end

  local occupants = build_occupants_from_store(st and st.players)
  draw_players(ui, occupants, cell_size)

  for idx, pos in ipairs(ui.board.positions) do
    local rect_x, rect_y, rect_w, rect_h = tile_rect_for_overlay(ui, idx, pos, half_cell, pad)
    draw_overlays(ui, (st and st.overlays) or { roadblocks = {}, mines = {} }, rect_x, rect_y, rect_w, rect_h, idx)
  end
end

return BoardRenderer

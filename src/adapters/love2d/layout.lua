local tiles_cfg = require("src.config.tiles")

local coords_by_id = {}
for _, cfg in ipairs(tiles_cfg) do
  if cfg.id and cfg.row and cfg.col then
    coords_by_id[cfg.id] = { cfg.row, cfg.col }
  end
end

local Layout = {}

local function board_tile_id_at(source, i)
  if not source then
    return nil
  end
  if source.board and source.board.tiles then
    local t = source.board.tiles[i]
    return t and t.id
  end
  if source.board and source.board.get_tile then
    local t = source.board:get_tile(i)
    return t and t.id
  end
  return nil
end

local function board_len(source)
  if not source then
    return 0
  end
  if source.board and source.board.tiles then
    return #source.board.tiles
  end
  if source.board and source.board.length then
    return source.board:length()
  end
  return 0
end

function Layout.apply(ui, game_or_view)
  local w, h = love.graphics.getDimensions()
  ui.side_width = math.max(280, math.floor(w * 0.24))

  local board_w = w - ui.side_width - ui.margin * 3
  local board_h = h - ui.margin * 2
  local vpad = ui.board.padding.vertical
  local hpad = ui.board.padding.horizontal
  local effective_board_h = board_h - vpad * 2
  local effective_board_w = board_w - hpad * 2
  local board_size = math.min(effective_board_w, effective_board_h)
  ui.board.size = board_size
  ui.board.cell_size = board_size / 9
  ui.tile_radius = math.min(ui.board.cell_size * 0.32, 18)
  ui.board.origin.x = ui.margin + hpad + (effective_board_w - board_size) * 0.5
  ui.board.origin.y = ui.margin + vpad + (effective_board_h - board_size) * 0.5
  ui.board.center.x = ui.board.origin.x + board_size * 0.5
  ui.board.center.y = ui.board.origin.y + board_size * 0.5
  ui.board.positions = {}

  if game_or_view then
    local count = board_len(game_or_view)
    for i = 1, count do
      local tile_id = board_tile_id_at(game_or_view, i)
      local coord = tile_id and coords_by_id[tile_id]
      if not coord then
        break
      end
      local row, col = coord[1], coord[2]
      ui.board.positions[i] = {
        x = ui.board.origin.x + (col - 0.5) * ui.board.cell_size,
        y = ui.board.origin.y + (row - 0.5) * ui.board.cell_size,
        row = row,
        col = col,
      }
    end
  end

  local panel_x = ui.margin * 2 + board_w
  local panel_y = ui.margin
  local btn_w = ui.side_width - ui.margin * 2
  local btn_h = 36
  ui.panel = { x = panel_x, y = panel_y, w = ui.side_width, h = h - ui.margin * 2 }
  ui.buttons = {
    {
      id = "next",
      label = "下一回合 (Space)",
      x = panel_x + ui.margin,
      y = panel_y + 68,
      w = btn_w,
      h = btn_h,
    },
    {
      id = "auto",
      label = "自动运行 (A)",
      x = panel_x + ui.margin,
      y = panel_y + 110,
      w = btn_w,
      h = btn_h,
    },
    {
      id = "restart",
      label = "重新开始 (R)",
      x = panel_x + ui.margin,
      y = panel_y + 152,
      w = btn_w,
      h = btn_h,
    },
  }
end

return Layout

package.path = "src/?.lua;src/?/init.lua;?.lua;" .. package.path

local App = require("src.app")
local logger = require("src.services.logger")
local items_cfg = require("src.config.items")
local roles_cfg = require("src.config.roles")
local LoveLayer = require("src.ui.love_layer")

local ui = {
  margin = 18,
  side_width = 320,
  tile_radius = 18,
  auto_play = false,
  auto_interval = 0.9,
  last_auto_time = 0,
  hover_tile = nil,
  selected_tile = nil,
  buttons = {},
  palette = {
    bg = { 0.07, 0.09, 0.1 },
    panel = { 0.12, 0.14, 0.16 },
    panel_border = { 0.24, 0.27, 0.3 },
    text = { 0.95, 0.95, 0.92 },
    muted = { 0.7, 0.72, 0.7 },
    tile = {
      land = { 0.77, 0.7, 0.56 },
      start = { 0.3, 0.75, 0.48 },
      chance = { 0.3, 0.5, 0.75 },
      item = { 0.85, 0.6, 0.32 },
      market = { 0.6, 0.42, 0.22 },
      tax = { 0.8, 0.36, 0.36 },
      hospital = { 0.35, 0.7, 0.8 },
      mountain = { 0.55, 0.55, 0.6 },
      default = { 0.7, 0.7, 0.7 },
    },
    player = {
      { 0.92, 0.35, 0.36 },
      { 0.3, 0.7, 0.92 },
      { 0.92, 0.78, 0.3 },
      { 0.6, 0.45, 0.9 },
      { 0.4, 0.85, 0.5 },
    },
    log = {
      info = { 0.72, 0.8, 0.88 },
      warn = { 0.9, 0.6, 0.3 },
      event = { 0.88, 0.85, 0.7 },
    },
  },
  fonts = {},
  board = {
    positions = {},
    center = { x = 0, y = 0 },
    origin = { x = 0, y = 0 },
    size = 0,
    cell_size = 0,
  },
}

-- 9x9 grid coordinates for each path tile (row, col)
local grid_coords = {
  { 9, 9 }, { 9, 8 }, { 9, 7 }, { 9, 6 }, { 9, 5 }, { 9, 4 }, { 9, 3 }, { 9, 2 }, { 9, 1 },
  { 8, 1 }, { 8, 5 }, { 8, 9 }, { 7, 9 }, { 7, 5 }, { 7, 1 }, { 6, 1 }, { 6, 5 }, { 6, 9 },
  { 5, 9 }, { 5, 8 }, { 5, 7 }, { 5, 6 }, { 5, 5 }, { 5, 4 }, { 5, 3 }, { 5, 2 }, { 5, 1 },
  { 4, 1 }, { 4, 5 }, { 4, 9 }, { 3, 9 }, { 3, 5 }, { 3, 1 }, { 2, 1 }, { 2, 5 }, { 2, 9 },
  { 1, 9 }, { 1, 8 }, { 1, 7 }, { 1, 6 }, { 1, 5 }, { 1, 4 }, { 1, 3 }, { 1, 2 }, { 1, 1 },
}

local game = nil
local item_name_by_id = {}

local function set_game(g)
  game = g
end

local function get_game()
  return game
end

local function build_item_index()
  for _, cfg in ipairs(items_cfg) do
    item_name_by_id[cfg.id] = cfg.name or tostring(cfg.id)
  end
end

local function new_game()
  logger.clear()
  local g = App.new({
    players = { "玩家1", "AI2", "AI3", "AI4" },
    ai = { [2] = true, [3] = true, [4] = true },
    auto_all = true,
  })
  ui.selected_tile = nil
  ui.hover_tile = nil
  ui.last_auto_time = 0
  g.logger.info("启动蛋仔大富翁，玩家数:", #g.players)
  return g
end

local function layout()
  local w, h = love.graphics.getDimensions()
  ui.side_width = math.max(280, math.floor(w * 0.28))
  local board_w = w - ui.side_width - ui.margin * 3
  local board_h = h - ui.margin * 2
  local board_size = math.min(board_w, board_h)
  ui.board.size = board_size
  ui.board.cell_size = board_size / 9
  ui.tile_radius = math.min(ui.board.cell_size * 0.32, 18)
  ui.board.origin.x = ui.margin + (board_w - board_size) * 0.5
  ui.board.origin.y = ui.margin + (board_h - board_size) * 0.5
  ui.board.center.x = ui.board.origin.x + board_size * 0.5
  ui.board.center.y = ui.board.origin.y + board_size * 0.5
  ui.board.positions = {}
  if not game then
    return
  end
  local count = game.board:length()
  for i = 1, count do
    local coord = grid_coords[i]
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
  local panel_x = ui.margin * 2 + board_w
  local panel_y = ui.margin
  local btn_w = ui.side_width - ui.margin * 2
  local btn_h = 36
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

local function is_inside(x, y, rect)
  return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

local function step_turn()
  if not game or game.finished then
    return
  end
  game.turn_manager:run_turn()
  game:check_victory()
end

local function tile_color(tile_type)
  return ui.palette.tile[tile_type] or ui.palette.tile.default
end

local function draw_panel_background(x, y, w, h)
  love.graphics.setColor(ui.palette.panel)
  love.graphics.rectangle("fill", x, y, w, h, 10, 10)
  love.graphics.setColor(ui.palette.panel_border)
  love.graphics.rectangle("line", x, y, w, h, 10, 10)
end

local function draw_button(btn, active)
  local bg = active and { 0.3, 0.5, 0.35 } or { 0.2, 0.22, 0.24 }
  love.graphics.setColor(bg)
  love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 6, 6)
  love.graphics.setColor(ui.palette.panel_border)
  love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h, 6, 6)
  love.graphics.setColor(ui.palette.text)
  love.graphics.printf(btn.label, btn.x, btn.y + 8, btn.w, "center")
end

local function draw_wrapped(text, x, y, width, font)
  love.graphics.setFont(font)
  local _, lines = font:getWrap(text, width)
  love.graphics.printf(text, x, y, width, "left")
  return #lines
end

local function update_hover_tile(mx, my)
  ui.hover_tile = nil
  if not game then
    return
  end
  local half_cell = (ui.board.cell_size or ui.tile_radius * 2) * 0.5
  for idx, pos in ipairs(ui.board.positions) do
    local dx = mx - pos.x
    local dy = my - pos.y
    if math.abs(dx) <= half_cell and math.abs(dy) <= half_cell then
      ui.hover_tile = idx
      return
    end
  end
end

local function build_player_label(player)
  if player.eliminated then
    return player.name .. " (出局)"
  end
  local suffix = ""
  if player.status.stay_turns and player.status.stay_turns > 0 then
    suffix = " 停留" .. player.status.stay_turns
  end
  return player.name .. " $" .. player.cash .. suffix
end

LoveLayer
  .new({
    ui = ui,
    logger = logger,
    roles_cfg = roles_cfg,
    item_name_by_id = item_name_by_id,
    get_game = get_game,
    set_game = set_game,
    new_game = new_game,
    layout = layout,
    update_hover_tile = update_hover_tile,
    step_turn = step_turn,
    is_inside = is_inside,
    draw_button = draw_button,
    draw_panel_background = draw_panel_background,
    tile_color = tile_color,
    draw_wrapped = draw_wrapped,
    build_player_label = build_player_label,
    build_item_index = build_item_index,
  })
  :attach()

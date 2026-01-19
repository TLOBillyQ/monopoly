local UIState = {}

function UIState.create()
  return {
    margin = 14,
    side_width = 320,
    tile_radius = 18,
    auto_play = false,
    auto_interval = 0.1,
    last_auto_time = 0,
    hover_tile = nil,
    selected_tile = nil,
    buttons = {},
    panel = { x = 0, y = 0, w = 0, h = 0 },
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
      overlay = {
        roadblock = { bg = { 0.95, 0.78, 0.28 }, fg = { 0.22, 0.16, 0.08 } },
        mine = { bg = { 0.9, 0.25, 0.25 }, ring = { 1, 0.82, 0.82 }, fg = { 0.08, 0.08, 0.08 } },
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
      padding = {
        vertical = 60,
        horizontal = 0,
      },
    },
  }
end

function UIState.build_fonts(ui)
  ui.fonts.title = love.graphics.newFont("assets/fonts/NotoSansSC-Regular.ttf", 26)
  ui.fonts.body = love.graphics.newFont("assets/fonts/NotoSansSC-Regular.ttf", 18)
  ui.fonts.small = love.graphics.newFont("assets/fonts/NotoSansSC-Regular.ttf", 15)
  ui.fonts.tiny = love.graphics.newFont("assets/fonts/NotoSansSC-Regular.ttf", 12)
  love.graphics.setFont(ui.fonts.body)
end

function UIState.tile_color(ui, tile_type)
  return ui.palette.tile[tile_type] or ui.palette.tile.default
end

return UIState
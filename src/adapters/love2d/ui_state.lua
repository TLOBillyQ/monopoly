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
      bg = { 0.04, 0.04, 0.05 },
      panel = { 0.08, 0.09, 0.1 },
      panel_border = { 0.85, 0.85, 0.85 },
      text = { 1, 1, 1 },
      muted = { 0.78, 0.78, 0.78 },
      tile = {
        land = { 1, 1, 1 },
        start = { 0.1, 0.85, 0.2 },
        chance = { 0.2, 0.35, 1 },
        item = { 1, 0.55, 0.1 },
        market = { 0.95, 0.8, 0.1 },
        tax = { 1, 0.15, 0.15 },
        hospital = { 0.1, 0.85, 1 },
        mountain = { 0.5, 0.5, 0.5 },
        default = { 0.9, 0.9, 0.9 },
      },
      overlay = {
        roadblock = { bg = { 1, 0.95, 0.3 }, fg = { 0, 0, 0 } },
        mine = { bg = { 1, 0.1, 0.1 }, ring = { 1, 1, 1 }, fg = { 0, 0, 0 } },
      },
      player = {
        { 1, 0.15, 0.15 },
        { 0.1, 0.5, 1 },
        { 1, 0.9, 0.05 },
        { 0.1, 1, 0.5 },
        { 0.95, 0.1, 1 },
      },
      log = {
        info = { 0.8, 0.9, 1 },
        warn = { 1, 0.65, 0.2 },
        event = { 1, 0.95, 0.6 },
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

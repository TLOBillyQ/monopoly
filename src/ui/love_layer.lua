local App = require("src.app")
local logger = require("src.services.logger")
local items_cfg = require("src.config.items")
local roles_cfg = require("src.config.roles")

local LoveLayer = {}
LoveLayer.__index = LoveLayer

local grid_coords = {
  { 9, 9 }, { 9, 8 }, { 9, 7 }, { 9, 6 }, { 9, 5 }, { 9, 4 }, { 9, 3 }, { 9, 2 }, { 9, 1 },
  { 8, 1 }, { 8, 5 }, { 8, 9 }, { 7, 9 }, { 7, 5 }, { 7, 1 }, { 6, 1 }, { 6, 5 }, { 6, 9 },
  { 5, 9 }, { 5, 8 }, { 5, 7 }, { 5, 6 }, { 5, 5 }, { 5, 4 }, { 5, 3 }, { 5, 2 }, { 5, 1 },
  { 4, 1 }, { 4, 5 }, { 4, 9 }, { 3, 9 }, { 3, 5 }, { 3, 1 }, { 2, 1 }, { 2, 5 }, { 2, 9 },
  { 1, 9 }, { 1, 8 }, { 1, 7 }, { 1, 6 }, { 1, 5 }, { 1, 4 }, { 1, 3 }, { 1, 2 }, { 1, 1 },
}

local function create_ui()
  return {
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
end

local function build_fonts(ui)
  ui.fonts.title = love.graphics.newFont("assets/fonts/NotoSansSC-Regular.ttf", 22)
  ui.fonts.body = love.graphics.newFont("assets/fonts/NotoSansSC-Regular.ttf", 16)
  ui.fonts.small = love.graphics.newFont("assets/fonts/NotoSansSC-Regular.ttf", 13)
  ui.fonts.tiny = love.graphics.newFont("assets/fonts/NotoSansSC-Regular.ttf", 11)
  love.graphics.setFont(ui.fonts.body)
end

function LoveLayer.new()
  local self = {
    ui = create_ui(),
    game = nil,
    item_name_by_id = {},
  }
  return setmetatable(self, LoveLayer)
end

function LoveLayer:set_game(g)
  self.game = g
end

function LoveLayer:get_game()
  return self.game
end

function LoveLayer:build_item_index()
  self.item_name_by_id = {}
  for _, cfg in ipairs(items_cfg) do
    self.item_name_by_id[cfg.id] = cfg.name or tostring(cfg.id)
  end
end

function LoveLayer:new_game()
  logger.clear()
  local g = App.new({
    players = { "玩家1", "AI2", "AI3", "AI4" },
    ai = { [2] = true, [3] = true, [4] = true },
    auto_all = true,
  })
  self.ui.selected_tile = nil
  self.ui.hover_tile = nil
  self.ui.last_auto_time = 0
  g.logger.info("启动蛋仔大富翁，玩家数:", #g.players)
  return g
end

function LoveLayer:layout()
  local w, h = love.graphics.getDimensions()
  local ui = self.ui
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
  if not self.game then
    return
  end
  local count = self.game.board:length()
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

function LoveLayer:is_inside(x, y, rect)
  return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

function LoveLayer:step_turn()
  if not self.game or self.game.finished then
    return
  end
  self.game.turn_manager:run_turn()
  self.game:check_victory()
end

function LoveLayer:tile_color(tile_type)
  return self.ui.palette.tile[tile_type] or self.ui.palette.tile.default
end

function LoveLayer:draw_panel_background(x, y, w, h)
  love.graphics.setColor(self.ui.palette.panel)
  love.graphics.rectangle("fill", x, y, w, h, 10, 10)
  love.graphics.setColor(self.ui.palette.panel_border)
  love.graphics.rectangle("line", x, y, w, h, 10, 10)
end

function LoveLayer:draw_button(btn, active)
  local bg = active and { 0.3, 0.5, 0.35 } or { 0.2, 0.22, 0.24 }
  love.graphics.setColor(bg)
  love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 6, 6)
  love.graphics.setColor(self.ui.palette.panel_border)
  love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h, 6, 6)
  love.graphics.setColor(self.ui.palette.text)
  love.graphics.printf(btn.label, btn.x, btn.y + 8, btn.w, "center")
end

function LoveLayer:draw_wrapped(text, x, y, width, font)
  love.graphics.setFont(font)
  local _, lines = font:getWrap(text, width)
  love.graphics.printf(text, x, y, width, "left")
  return #lines
end

function LoveLayer:update_hover_tile(mx, my)
  self.ui.hover_tile = nil
  if not self.game then
    return
  end
  local half_cell = (self.ui.board.cell_size or self.ui.tile_radius * 2) * 0.5
  for idx, pos in ipairs(self.ui.board.positions) do
    local dx = mx - pos.x
    local dy = my - pos.y
    if math.abs(dx) <= half_cell and math.abs(dy) <= half_cell then
      self.ui.hover_tile = idx
      return
    end
  end
end

function LoveLayer:build_player_label(player)
  if player.eliminated then
    return player.name .. " (出局)"
  end
  local suffix = ""
  if player.status.stay_turns and player.status.stay_turns > 0 then
    suffix = " 停留" .. player.status.stay_turns
  end
  return player.name .. " $" .. player.cash .. suffix
end

function LoveLayer:load()
  love.window.setTitle("蛋仔大富翁 (Love2D)")
  build_fonts(self.ui)
  self:build_item_index()
  self:set_game(self:new_game())
  self:layout()
end

function LoveLayer:resize()
  self:layout()
end

function LoveLayer:update(dt)
  if not self.game then
    return
  end
  local mx, my = love.mouse.getPosition()
  self:update_hover_tile(mx, my)
  if self.ui.auto_play and not self.game.finished then
    self.ui.last_auto_time = self.ui.last_auto_time + dt
    if self.ui.last_auto_time >= self.ui.auto_interval then
      self.ui.last_auto_time = 0
      self:step_turn()
    end
  end
end

function LoveLayer:mousepressed(x, y, button)
  if button ~= 1 then
    return
  end
  for _, btn in ipairs(self.ui.buttons) do
    if self:is_inside(x, y, btn) then
      if btn.id == "next" then
        self:step_turn()
      elseif btn.id == "auto" then
        self.ui.auto_play = not self.ui.auto_play
        self.ui.last_auto_time = 0
      elseif btn.id == "restart" then
        self:set_game(self:new_game())
        self:layout()
      end
      return
    end
  end

  if self.ui.hover_tile then
    self.ui.selected_tile = self.ui.hover_tile
  end
end

function LoveLayer:keypressed(key)
  if key == "space" or key == "return" then
    self:step_turn()
  elseif key == "a" then
    self.ui.auto_play = not self.ui.auto_play
    self.ui.last_auto_time = 0
  elseif key == "r" then
    self:set_game(self:new_game())
    self:layout()
  elseif key == "escape" then
    love.event.quit()
  end
end

function LoveLayer:draw()
  local game = self.game
  local ui = self.ui

  local w, h = love.graphics.getDimensions()
  love.graphics.setColor(ui.palette.bg)
  love.graphics.rectangle("fill", 0, 0, w, h)

  love.graphics.setColor(0.2, 0.25, 0.3, 0.2)
  love.graphics.circle("fill", ui.board.center.x - 120, ui.board.center.y - 80, ui.board.size * 0.45)
  love.graphics.setColor(0.2, 0.3, 0.25, 0.15)
  love.graphics.circle("fill", ui.board.center.x + 140, ui.board.center.y + 90, ui.board.size * 0.4)

  local panel_x = ui.margin * 2 + (w - ui.side_width - ui.margin * 3)
  local panel_y = ui.margin
  local panel_w = ui.side_width
  local panel_h = h - ui.margin * 2
  self:draw_panel_background(panel_x, panel_y, panel_w, panel_h)

  if game then
    local cell_size = ui.board.cell_size
    local half_cell = cell_size * 0.5
    local pad = math.min(cell_size * 0.15, 6)
    local last_visited = {}
    if game.last_turn and game.last_turn.move_result and game.last_turn.move_result.visited then
      for _, idx in ipairs(game.last_turn.move_result.visited) do
        last_visited[idx] = true
      end
    end
    for idx, pos in ipairs(ui.board.positions) do
      local tile = game.board:get_tile(idx)
      local color = self:tile_color(tile.type)
      if last_visited[idx] then
        color = { math.min(color[1] + 0.2, 1), math.min(color[2] + 0.2, 1), math.min(color[3] + 0.2, 1) }
      end
      love.graphics.setColor(color)
      local rect_x = pos.x - half_cell + pad
      local rect_y = pos.y - half_cell + pad
      local rect_w = cell_size - pad * 2
      local rect_h = cell_size - pad * 2
      if ui.hover_tile == idx or ui.selected_tile == idx then
        rect_x = rect_x - 2
        rect_y = rect_y - 2
        rect_w = rect_w + 4
        rect_h = rect_h + 4
      end
      love.graphics.rectangle("fill", rect_x, rect_y, rect_w, rect_h, 8, 8)
      love.graphics.setColor(0.12, 0.12, 0.12, 0.65)
      love.graphics.rectangle("line", rect_x, rect_y, rect_w, rect_h, 8, 8)
      love.graphics.setFont(ui.fonts.tiny)
      love.graphics.setColor(0.05, 0.05, 0.05)
      love.graphics.printf(tostring(idx), rect_x, rect_y - 8, rect_w, "center")

      if tile.type == "land" and tile.owner_id then
        local owner_color = ui.palette.player[tile.owner_id] or { 0.9, 0.9, 0.9 }
        love.graphics.setColor(owner_color)
        love.graphics.rectangle("line", rect_x - 2, rect_y - 2, rect_w + 4, rect_h + 4, 9, 9)
        if tile.level > 0 then
          love.graphics.setFont(ui.fonts.tiny)
          love.graphics.printf("L" .. tile.level, rect_x, rect_y + rect_h * 0.4, rect_w, "center")
        end
      end

      if game.overlays.roadblocks[idx] then
        love.graphics.setColor(0.8, 0.6, 0.2)
        love.graphics.rectangle("fill", rect_x + rect_w - 12, rect_y + 4, 10, 6)
      elseif game.overlays.mines[idx] then
        love.graphics.setColor(0.9, 0.2, 0.2)
        love.graphics.circle("fill", rect_x + rect_w - 8, rect_y + rect_h - 8, 4)
      end
    end

    for idx, pos in ipairs(ui.board.positions) do
      local occupants = game.occupants[idx]
      if occupants then
        local count = #occupants
        for i, pid in ipairs(occupants) do
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

  love.graphics.setFont(ui.fonts.title)
  love.graphics.setColor(ui.palette.text)
  love.graphics.printf("蛋仔大富翁", panel_x + ui.margin, panel_y + 18, panel_w - ui.margin * 2, "left")

  love.graphics.setFont(ui.fonts.small)
  local turn_label = game and ("回合: " .. game.turn_count) or "回合: -"
  love.graphics.setColor(ui.palette.muted)
  love.graphics.printf(turn_label, panel_x + ui.margin, panel_y + 42, panel_w - ui.margin * 2, "left")

  for _, btn in ipairs(ui.buttons) do
    self:draw_button(btn, btn.id == "auto" and ui.auto_play)
  end

  local info_y = panel_y + 200
  love.graphics.setFont(ui.fonts.small)
  love.graphics.setColor(ui.palette.text)
  love.graphics.printf("当前玩家", panel_x + ui.margin, info_y, panel_w - ui.margin * 2, "left")
  info_y = info_y + 18

  if game then
    local current = game:current_player()
    love.graphics.setFont(ui.fonts.body)
    love.graphics.setColor(ui.palette.text)
    love.graphics.printf(current.name .. " 现金 " .. current.cash, panel_x + ui.margin, info_y, panel_w - ui.margin * 2, "left")
    info_y = info_y + 20

    local role = roles_cfg[((current.id - 1) % #roles_cfg) + 1]
    love.graphics.setFont(ui.fonts.tiny)
    love.graphics.setColor(ui.palette.muted)
    love.graphics.printf("角色: " .. (role and role.name or "-"), panel_x + ui.margin, info_y, panel_w - ui.margin * 2, "left")
    info_y = info_y + 16

    if current.status.deity then
      love.graphics.printf("附身: " .. current.status.deity.type .. " (" .. current.status.deity.remaining .. ")", panel_x + ui.margin, info_y, panel_w - ui.margin * 2, "left")
      info_y = info_y + 16
    end

    if game.last_turn and game.last_turn.player_id == current.id then
      if game.last_turn.rolls then
        love.graphics.setColor(ui.palette.text)
        love.graphics.printf("骰子: " .. table.concat(game.last_turn.rolls, ",") .. " => " .. game.last_turn.total, panel_x + ui.margin, info_y, panel_w - ui.margin * 2, "left")
        info_y = info_y + 18
      elseif game.last_turn.note then
        love.graphics.setColor(ui.palette.muted)
        love.graphics.printf(game.last_turn.note, panel_x + ui.margin, info_y, panel_w - ui.margin * 2, "left")
        info_y = info_y + 18
      end
    end
  end

  info_y = info_y + 10
  love.graphics.setFont(ui.fonts.small)
  love.graphics.setColor(ui.palette.text)
  love.graphics.printf("玩家状态", panel_x + ui.margin, info_y, panel_w - ui.margin * 2, "left")
  info_y = info_y + 16

  if game then
    love.graphics.setFont(ui.fonts.tiny)
    for _, player in ipairs(game.players) do
      local color = ui.palette.player[player.id] or ui.palette.text
      love.graphics.setColor(color)
      love.graphics.circle("fill", panel_x + ui.margin + 6, info_y + 6, 4)
      love.graphics.setColor(ui.palette.text)
      love.graphics.printf(self:build_player_label(player), panel_x + ui.margin + 16, info_y, panel_w - ui.margin * 2 - 16, "left")
      info_y = info_y + 16
    end
  end

  info_y = info_y + 10
  love.graphics.setFont(ui.fonts.small)
  love.graphics.setColor(ui.palette.text)
  love.graphics.printf("当前背包", panel_x + ui.margin, info_y, panel_w - ui.margin * 2, "left")
  info_y = info_y + 16

  if game then
    local current = game:current_player()
    love.graphics.setFont(ui.fonts.tiny)
    if current.inventory:count() == 0 then
      love.graphics.setColor(ui.palette.muted)
      love.graphics.printf("暂无道具", panel_x + ui.margin, info_y, panel_w - ui.margin * 2, "left")
      info_y = info_y + 16
    else
      for _, item in ipairs(current.inventory.items) do
        love.graphics.setColor(ui.palette.text)
        love.graphics.printf(self.item_name_by_id[item.id] or tostring(item.id), panel_x + ui.margin, info_y, panel_w - ui.margin * 2, "left")
        info_y = info_y + 14
      end
    end
  end

  info_y = info_y + 10
  love.graphics.setFont(ui.fonts.small)
  love.graphics.setColor(ui.palette.text)
  love.graphics.printf("格子详情", panel_x + ui.margin, info_y, panel_w - ui.margin * 2, "left")
  info_y = info_y + 16

  if game and (ui.selected_tile or ui.hover_tile) then
    local idx = ui.selected_tile or ui.hover_tile
    local tile = game.board:get_tile(idx)
    if tile then
      love.graphics.setFont(ui.fonts.tiny)
      love.graphics.setColor(ui.palette.text)
      love.graphics.printf(tile.name .. " (" .. tile.type .. ")", panel_x + ui.margin, info_y, panel_w - ui.margin * 2, "left")
      info_y = info_y + 14
      if tile.type == "land" then
        local owner = tile.owner_id and game.players[tile.owner_id]
        love.graphics.printf("价格: " .. tile.price, panel_x + ui.margin, info_y, panel_w - ui.margin * 2, "left")
        info_y = info_y + 14
        love.graphics.printf("等级: " .. tile.level, panel_x + ui.margin, info_y, panel_w - ui.margin * 2, "left")
        info_y = info_y + 14
        if owner then
          love.graphics.printf("归属: " .. owner.name, panel_x + ui.margin, info_y, panel_w - ui.margin * 2, "left")
          info_y = info_y + 14
        end
      end
    end
  end

  info_y = math.max(info_y + 6, panel_y + panel_h * 0.68)
  love.graphics.setFont(ui.fonts.small)
  love.graphics.setColor(ui.palette.text)
  love.graphics.printf("事件记录", panel_x + ui.margin, info_y, panel_w - ui.margin * 2, "left")
  info_y = info_y + 18

  if logger.entries then
    love.graphics.setFont(ui.fonts.tiny)
    local max_lines = math.floor((panel_y + panel_h - info_y - ui.margin) / (ui.fonts.tiny:getHeight() + 2))
    local start = math.max(1, #logger.entries - max_lines)
    for i = start, #logger.entries do
      local entry = logger.entries[i]
      love.graphics.setColor(ui.palette.log[entry.level] or ui.palette.text)
      local lines = self:draw_wrapped(entry.text, panel_x + ui.margin, info_y, panel_w - ui.margin * 2, ui.fonts.tiny)
      info_y = info_y + (ui.fonts.tiny:getHeight() + 2) * math.max(1, lines)
    end
  end

  if game and game.finished then
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setFont(ui.fonts.title)
    love.graphics.setColor(ui.palette.text)
    local winner = game.winner and game.winner.name or "无人"
    love.graphics.printf("游戏结束，胜者: " .. winner, 0, h * 0.45, w, "center")
  end
end

function LoveLayer:attach()
  function love.load()
    self:load()
  end

  function love.resize()
    self:resize()
  end

  function love.update(dt)
    self:update(dt)
  end

  function love.mousepressed(x, y, button)
    self:mousepressed(x, y, button)
  end

  function love.keypressed(key)
    self:keypressed(key)
  end

  function love.draw()
    self:draw()
  end
end

return LoveLayer

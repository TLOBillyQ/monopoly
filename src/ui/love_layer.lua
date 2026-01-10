local LoveLayer = {}
LoveLayer.__index = LoveLayer

local function build_fonts(ui)
  ui.fonts.title = love.graphics.newFont("assets/fonts/NotoSansSC-Regular.ttf", 22)
  ui.fonts.body = love.graphics.newFont("assets/fonts/NotoSansSC-Regular.ttf", 16)
  ui.fonts.small = love.graphics.newFont("assets/fonts/NotoSansSC-Regular.ttf", 13)
  ui.fonts.tiny = love.graphics.newFont("assets/fonts/NotoSansSC-Regular.ttf", 11)
  love.graphics.setFont(ui.fonts.body)
end

function LoveLayer.new(opts)
  local self = {
    ui = opts.ui,
    logger = opts.logger,
    roles_cfg = opts.roles_cfg,
    item_name_by_id = opts.item_name_by_id,
    get_game = opts.get_game,
    set_game = opts.set_game,
    new_game = opts.new_game,
    layout = opts.layout,
    update_hover_tile = opts.update_hover_tile,
    step_turn = opts.step_turn,
    is_inside = opts.is_inside,
    draw_button = opts.draw_button,
    draw_panel_background = opts.draw_panel_background,
    tile_color = opts.tile_color,
    draw_wrapped = opts.draw_wrapped,
    build_player_label = opts.build_player_label,
    build_item_index = opts.build_item_index,
  }
  return setmetatable(self, LoveLayer)
end

function LoveLayer:load()
  love.window.setTitle("蛋仔大富翁 (Love2D)")
  build_fonts(self.ui)
  self.build_item_index()
  local g = self.new_game()
  self.set_game(g)
  self.layout()
end

function LoveLayer:resize()
  self.layout()
end

function LoveLayer:update(dt)
  local game = self.get_game()
  if not game then
    return
  end
  local mx, my = love.mouse.getPosition()
  self.update_hover_tile(mx, my)
  if self.ui.auto_play and not game.finished then
    self.ui.last_auto_time = self.ui.last_auto_time + dt
    if self.ui.last_auto_time >= self.ui.auto_interval then
      self.ui.last_auto_time = 0
      self.step_turn()
    end
  end
end

function LoveLayer:mousepressed(x, y, button)
  if button ~= 1 then
    return
  end
  for _, btn in ipairs(self.ui.buttons) do
    if self.is_inside(x, y, btn) then
      if btn.id == "next" then
        self.step_turn()
      elseif btn.id == "auto" then
        self.ui.auto_play = not self.ui.auto_play
        self.ui.last_auto_time = 0
      elseif btn.id == "restart" then
        self.set_game(self.new_game())
        self.layout()
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
    self.step_turn()
  elseif key == "a" then
    self.ui.auto_play = not self.ui.auto_play
    self.ui.last_auto_time = 0
  elseif key == "r" then
    self.set_game(self.new_game())
    self.layout()
  elseif key == "escape" then
    love.event.quit()
  end
end

function LoveLayer:draw()
  local game = self.get_game()
  local ui = self.ui
  local roles_cfg = self.roles_cfg
  local logger = self.logger
  local item_name_by_id = self.item_name_by_id

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
  self.draw_panel_background(panel_x, panel_y, panel_w, panel_h)

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
      local color = self.tile_color(tile.type)
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
    self.draw_button(btn, btn.id == "auto" and ui.auto_play)
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
      love.graphics.printf(self.build_player_label(player), panel_x + ui.margin + 16, info_y, panel_w - ui.margin * 2 - 16, "left")
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
        love.graphics.printf(item_name_by_id[item.id] or tostring(item.id), panel_x + ui.margin, info_y, panel_w - ui.margin * 2, "left")
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
      local lines = self.draw_wrapped(entry.text, panel_x + ui.margin, info_y, panel_w - ui.margin * 2, ui.fonts.tiny)
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

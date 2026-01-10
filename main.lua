package.path = "src/?.lua;src/?/init.lua;?.lua;" .. package.path

local App = require("src.app")
local logger = require("src.services.logger")
local items_cfg = require("src.config.items")
local roles_cfg = require("src.config.roles")

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
    radius = 240,
  },
}

local game = nil
local item_name_by_id = {}

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
  ui.board.center.x = ui.margin + board_w * 0.5
  ui.board.center.y = ui.margin + board_h * 0.5
  ui.board.radius = math.min(board_w, board_h) * 0.42
  ui.board.positions = {}
  if not game then
    return
  end
  local count = game.board:length()
  for i = 1, count do
    local angle = (i - 1) / count * (math.pi * 2) - math.pi / 2
    ui.board.positions[i] = {
      x = ui.board.center.x + math.cos(angle) * ui.board.radius,
      y = ui.board.center.y + math.sin(angle) * ui.board.radius,
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
  for idx, pos in ipairs(ui.board.positions) do
    local dx = mx - pos.x
    local dy = my - pos.y
    if (dx * dx + dy * dy) <= (ui.tile_radius + 2) ^ 2 then
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

function love.load()
  love.window.setTitle("蛋仔大富翁 (Love2D)")
  ui.fonts.title = love.graphics.newFont("assets/fonts/NotoSansSC-Regular.ttf", 22)
  ui.fonts.body = love.graphics.newFont("assets/fonts/NotoSansSC-Regular.ttf", 16)
  ui.fonts.small = love.graphics.newFont("assets/fonts/NotoSansSC-Regular.ttf", 13)
  ui.fonts.tiny = love.graphics.newFont("assets/fonts/NotoSansSC-Regular.ttf", 11)
  love.graphics.setFont(ui.fonts.body)
  build_item_index()
  game = new_game()
  layout()
end

function love.resize()
  layout()
end

function love.update(dt)
  if not game then
    return
  end
  local mx, my = love.mouse.getPosition()
  update_hover_tile(mx, my)
  if ui.auto_play and not game.finished then
    ui.last_auto_time = ui.last_auto_time + dt
    if ui.last_auto_time >= ui.auto_interval then
      ui.last_auto_time = 0
      step_turn()
    end
  end
end

function love.mousepressed(x, y, button)
  if button ~= 1 then
    return
  end
  for _, btn in ipairs(ui.buttons) do
    if is_inside(x, y, btn) then
      if btn.id == "next" then
        step_turn()
      elseif btn.id == "auto" then
        ui.auto_play = not ui.auto_play
        ui.last_auto_time = 0
      elseif btn.id == "restart" then
        game = new_game()
        layout()
      end
      return
    end
  end

  if ui.hover_tile then
    ui.selected_tile = ui.hover_tile
  end
end

function love.keypressed(key)
  if key == "space" or key == "return" then
    step_turn()
  elseif key == "a" then
    ui.auto_play = not ui.auto_play
    ui.last_auto_time = 0
  elseif key == "r" then
    game = new_game()
    layout()
  elseif key == "escape" then
    love.event.quit()
  end
end

function love.draw()
  local w, h = love.graphics.getDimensions()
  love.graphics.setColor(ui.palette.bg)
  love.graphics.rectangle("fill", 0, 0, w, h)

  -- 背景氛围光斑
  love.graphics.setColor(0.2, 0.25, 0.3, 0.2)
  love.graphics.circle("fill", ui.board.center.x - 120, ui.board.center.y - 80, ui.board.radius * 0.9)
  love.graphics.setColor(0.2, 0.3, 0.25, 0.15)
  love.graphics.circle("fill", ui.board.center.x + 140, ui.board.center.y + 90, ui.board.radius * 0.8)

  local panel_x = ui.margin * 2 + (w - ui.side_width - ui.margin * 3)
  local panel_y = ui.margin
  local panel_w = ui.side_width
  local panel_h = h - ui.margin * 2
  draw_panel_background(panel_x, panel_y, panel_w, panel_h)

  -- 绘制棋盘
  if game then
    local last_visited = {}
    if game.last_turn and game.last_turn.move_result and game.last_turn.move_result.visited then
      for _, idx in ipairs(game.last_turn.move_result.visited) do
        last_visited[idx] = true
      end
    end
    for idx, pos in ipairs(ui.board.positions) do
      local tile = game.board:get_tile(idx)
      local color = tile_color(tile.type)
      if last_visited[idx] then
        color = { math.min(color[1] + 0.2, 1), math.min(color[2] + 0.2, 1), math.min(color[3] + 0.2, 1) }
      end
      love.graphics.setColor(color)
      local radius = ui.tile_radius
      if ui.hover_tile == idx or ui.selected_tile == idx then
        radius = radius + 3
      end
      love.graphics.circle("fill", pos.x, pos.y, radius)
      love.graphics.setColor(0.1, 0.1, 0.1, 0.6)
      love.graphics.circle("line", pos.x, pos.y, radius)
      love.graphics.setFont(ui.fonts.tiny)
      love.graphics.setColor(0.05, 0.05, 0.05)
      love.graphics.printf(tostring(idx), pos.x - radius, pos.y - 6, radius * 2, "center")

      if tile.type == "land" and tile.owner_id then
        local owner_color = ui.palette.player[tile.owner_id] or { 0.9, 0.9, 0.9 }
        love.graphics.setColor(owner_color)
        love.graphics.circle("line", pos.x, pos.y, radius + 2)
        if tile.level > 0 then
          love.graphics.setFont(ui.fonts.tiny)
          love.graphics.printf("L" .. tile.level, pos.x - radius, pos.y + 4, radius * 2, "center")
        end
      end

      if game.overlays.roadblocks[idx] then
        love.graphics.setColor(0.8, 0.6, 0.2)
        love.graphics.rectangle("fill", pos.x - 5, pos.y - 3, 10, 6)
      elseif game.overlays.mines[idx] then
        love.graphics.setColor(0.9, 0.2, 0.2)
        love.graphics.circle("fill", pos.x, pos.y, 4)
      end
    end

    -- 绘制玩家
    for idx, pos in ipairs(ui.board.positions) do
      local occupants = game.occupants[idx]
      if occupants then
        local count = #occupants
        for i, pid in ipairs(occupants) do
          local angle = (i - 1) / math.max(1, count) * math.pi * 2
          local offset = ui.tile_radius + 8
          local ox = pos.x + math.cos(angle) * offset
          local oy = pos.y + math.sin(angle) * offset
          local p_color = ui.palette.player[pid] or { 0.9, 0.9, 0.9 }
          love.graphics.setColor(p_color)
          love.graphics.circle("fill", ox, oy, 6)
          love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
          love.graphics.circle("line", ox, oy, 6)
        end
      end
    end
  end

  -- 侧边栏内容
  love.graphics.setFont(ui.fonts.title)
  love.graphics.setColor(ui.palette.text)
  love.graphics.printf("蛋仔大富翁", panel_x + ui.margin, panel_y + 18, panel_w - ui.margin * 2, "left")

  love.graphics.setFont(ui.fonts.small)
  local turn_label = game and ("回合: " .. game.turn_count) or "回合: -"
  love.graphics.setColor(ui.palette.muted)
  love.graphics.printf(turn_label, panel_x + ui.margin, panel_y + 42, panel_w - ui.margin * 2, "left")

  for _, btn in ipairs(ui.buttons) do
    draw_button(btn, btn.id == "auto" and ui.auto_play)
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
      love.graphics.printf(build_player_label(player), panel_x + ui.margin + 16, info_y, panel_w - ui.margin * 2 - 16, "left")
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
      local lines = draw_wrapped(entry.text, panel_x + ui.margin, info_y, panel_w - ui.margin * 2, ui.fonts.tiny)
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

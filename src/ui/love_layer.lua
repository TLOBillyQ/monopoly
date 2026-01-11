local logger = require("src.services.logger")
local items_cfg = require("src.config.items")
local UIState = require("src.ui.ui_state")
local Layout = require("src.ui.layout")
local BoardRenderer = require("src.ui.board_renderer")
local PanelRenderer = require("src.ui.panel_renderer")

local LoveLayer = {}
LoveLayer.__index = LoveLayer

local grid_coords = {
  { 9, 9 }, { 9, 8 }, { 9, 7 }, { 9, 6 }, { 9, 5 }, { 9, 4 }, { 9, 3 }, { 9, 2 }, { 9, 1 },
  { 8, 1 }, { 8, 5 }, { 8, 9 }, { 7, 9 }, { 7, 5 }, { 7, 1 }, { 6, 1 }, { 6, 5 }, { 6, 9 },
  { 5, 9 }, { 5, 8 }, { 5, 7 }, { 5, 6 }, { 5, 5 }, { 5, 4 }, { 5, 3 }, { 5, 2 }, { 5, 1 },
  { 4, 1 }, { 4, 5 }, { 4, 9 }, { 3, 9 }, { 3, 5 }, { 3, 1 }, { 2, 1 }, { 2, 5 }, { 2, 9 },
  { 1, 9 }, { 1, 8 }, { 1, 7 }, { 1, 6 }, { 1, 5 }, { 1, 4 }, { 1, 3 }, { 1, 2 }, { 1, 1 },
}

function LoveLayer.new(opts)
  opts = opts or {}
  local self = {
    ui = UIState.create(),
    game = nil,
    item_name_by_id = {},
    game_factory = opts.game_factory,
  }
  return setmetatable(self, LoveLayer)
end

function LoveLayer:set_game(g)
  self.game = g
end

function LoveLayer:get_game()
  return self.game
end

function LoveLayer:set_game_factory(factory)
  self.game_factory = factory
end

function LoveLayer:build_item_index()
  self.item_name_by_id = {}
  for _, cfg in ipairs(items_cfg) do
    self.item_name_by_id[cfg.id] = cfg.name or tostring(cfg.id)
  end
end

function LoveLayer:new_game()
  logger.clear()
  assert(self.game_factory, "game_factory not set")
  local g = self.game_factory()
  self.ui.selected_tile = nil
  self.ui.hover_tile = nil
  self.ui.last_auto_time = 0
  g.logger.info("启动蛋仔大富翁，玩家数:", #g.players)
  return g
end

function LoveLayer:layout()
  Layout.apply(self.ui, self.game, grid_coords)
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

function LoveLayer:load()
  love.window.setMode(1600, 960, { resizable = true, minwidth = 1200, minheight = 800 })
  love.window.setTitle("蛋仔大富翁 (Love2D)")
  UIState.build_fonts(self.ui)
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

  BoardRenderer.draw(ui, game)
  PanelRenderer.draw(ui, game, ui.buttons, self.item_name_by_id)

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

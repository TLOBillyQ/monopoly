local logger = require("src.gameplay.services.logger")
local items_cfg = require("src.config.items")
local UIState = require("src.visual.ui_state")
local Layout = require("src.visual.layout")
local BoardRenderer = require("src.visual.board_renderer")
local PanelRenderer = require("src.visual.panel_renderer")
local Modal = require("src.visual.modal")
local AutoRunner = require("src.visual.auto_runner")

local LoveLayer = {}
LoveLayer.__index = LoveLayer

function LoveLayer.new(opts)
  opts = opts or {}
  local ui = UIState.create()
  local self = {
    ui = ui,
    game = nil,
    item_name_by_id = {},
    game_factory = opts.game_factory,
    modal = Modal.new(),
    auto_runner = AutoRunner.new({ interval = ui.auto_interval }),
  }
  return setmetatable(self, LoveLayer)
end

function LoveLayer:set_game(g)
  self.game = g
  self.game.ui_hooks = self.game.ui_hooks or {}
  self.game.ui_hooks.push_popup = function(payload)
    self.modal:push(payload)
  end
  self.game.ui_hooks.request_choice = function(opts)
    if not opts or not opts.candidates or #opts.candidates == 0 then
      -- allow custom buttons path
      local buttons = opts and opts.buttons
      if buttons and #buttons > 0 then
        self.modal:push({
          title = opts.title or "请选择",
          body = table.concat(opts.body_lines or {}, "\n"),
          buttons = buttons,
          button_text = "取消",
        })
      end
      return
    end
    local buttons = {}
    local candidates = opts.candidates or {}
    for _, p in ipairs(candidates) do
      table.insert(buttons, {
        label = p.name,
        on_click = function()
          if opts.on_select then
            opts.on_select(p)
          end
        end,
      })
    end
    local body_lines = opts.body_lines or {}
    if #body_lines == 0 then
      for _, p in ipairs(candidates) do
        table.insert(body_lines, p.name .. " 现金:" .. p.cash .. (p.status.deity and (" 神:" .. p.status.deity.type) or ""))
      end
    end
    table.insert(buttons, {
      label = "取消",
      on_click = function()
        -- do nothing
      end,
    })
    self.modal:push({
      title = opts.title or "选择玩家",
      body = table.concat(body_lines, "\n"),
      buttons = buttons,
      button_text = "取消",
    })
  end
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
  self.auto_runner:reset_timer()
  g.logger.info("启动蛋仔大富翁，玩家数:", #g.players)
  return g
end

function LoveLayer:layout()
  Layout.apply(self.ui, self.game)
end

function LoveLayer:is_inside(x, y, rect)
  return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

function LoveLayer:step_turn()
  if self.modal.active then
    return
  end
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
  local auto_action = self.auto_runner:next_action(dt, {
    modal_active = self.modal.active ~= nil,
    modal_buttons = self.modal.active and self.modal.active.buttons,
    game_finished = self.game.finished,
  })
  if auto_action then
    self:dispatch_action(auto_action)
  end
  self.modal:update()
end

function LoveLayer:handle_ui_button(id)
  if id == "next" then
    self:step_turn()
  elseif id == "auto" then
    self.ui.auto_play = not self.ui.auto_play
    self.auto_runner:set_enabled(self.ui.auto_play)
    self.auto_runner:reset_timer()
  elseif id == "restart" then
    local was_auto = self.ui.auto_play
    self:set_game(self:new_game())
    self:layout()
    self.auto_runner:set_enabled(was_auto)
  end
end

function LoveLayer:dispatch_action(action)
  if not action then
    return
  end
  if action.type == "key" then
    self:keypressed(action.key)
  elseif action.type == "ui_button" then
    self:handle_ui_button(action.id)
  elseif action.type == "modal_button" then
    local idx = action.index or 1
    if not self.modal:press_button(idx) then
      self.modal:keypressed("space")
    end
  elseif action.type == "modal_confirm" then
    if not self.modal:confirm() then
      self.modal:keypressed("space")
    end
  end
end

function LoveLayer:mousepressed(x, y, button)
  if button ~= 1 then
    return
  end
  if self.modal:click_buttons(x, y) or self.modal:mousepressed(x, y) then
    return
  end
  for _, btn in ipairs(self.ui.buttons) do
    if self:is_inside(x, y, btn) then
      self:handle_ui_button(btn.id)
      return
    end
  end

  if self.ui.hover_tile then
    self.ui.selected_tile = self.ui.hover_tile
  end
end

function LoveLayer:keypressed(key)
  if self.modal.active and self.modal:keypressed(key) then
    return
  end
  if key == "space" or key == "return" then
    self:step_turn()
  elseif key == "a" then
    self.ui.auto_play = not self.ui.auto_play
    self.auto_runner:set_enabled(self.ui.auto_play)
    self.auto_runner:reset_timer()
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
  self.modal:draw(ui)

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

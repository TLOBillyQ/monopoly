local UIState = require("src.adapters.love2d.ui_state")
local constants = require("src.config.constants")
local Layout = require("src.adapters.love2d.layout")
local BoardRenderer = require("src.adapters.love2d.board_renderer")
local PanelRenderer = require("src.adapters.love2d.panel_renderer")
local Presenter = require("src.adapters.love2d.presenter")

local LoveRuntime = {}

function LoveRuntime.install(LoveLayer)
  function LoveLayer:layout()
    local store_state = (self.game and self.game.store and self.game.store.state) or {}
    local winner_name = self.game and (self.game.winner_names or (self.game.winner and self.game.winner.name)) or nil
    local view = Presenter.present(store_state, {
      game = self.game,
      last_turn = self.game and self.game.last_turn,
      finished = self.game and self.game.finished,
      winner_name = winner_name,
    })
    Layout.apply(self.ui, view)
  end

  function LoveLayer:is_inside(x, y, rect)
    return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
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
    local timeout = constants.action_timeout_seconds or 0
    if timeout > 0 and self.pending_choice and self.modal.active then
      if self.pending_choice_id ~= self.pending_choice.id then
        self.pending_choice_elapsed = 0
        self.pending_choice_id = self.pending_choice.id
      end
      self.pending_choice_elapsed = self.pending_choice_elapsed + dt
      if self.pending_choice_elapsed >= timeout then
        local choice = self.pending_choice
        self.pending_choice_elapsed = 0
        local first = choice.options and choice.options[1]
        if first then
          self:dispatch_action({ type = "choice_select", choice_id = choice.id, option_id = first.id or first })
        elseif choice.allow_cancel ~= false then
          self:dispatch_action({ type = "choice_cancel", choice_id = choice.id })
        end
      end
    else
      self.pending_choice_elapsed = 0
      self.pending_choice_id = nil
    end
    self.modal:update()
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
      self:_sync_auto_player(self.ui.auto_play)
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

    local store_state = (game and game.store and game.store.state) or {}
    local winner_name = game and (game.winner_names or (game.winner and game.winner.name)) or nil
    local view = Presenter.present(store_state, {
      last_turn = game and game.last_turn,
      finished = game and game.finished,
      winner_name = winner_name,
    })

    local w, h = love.graphics.getDimensions()
    love.graphics.setColor(ui.palette.bg)
    love.graphics.rectangle("fill", 0, 0, w, h)

    love.graphics.setColor(0.2, 0.25, 0.3, 0.2)
    love.graphics.circle("fill", ui.board.center.x - 120, ui.board.center.y - 80, ui.board.size * 0.45)
    love.graphics.setColor(0.2, 0.3, 0.25, 0.15)
    love.graphics.circle("fill", ui.board.center.x + 140, ui.board.center.y + 90, ui.board.size * 0.4)

    BoardRenderer.draw(ui, view)
    PanelRenderer.draw(ui, view, ui.buttons, self.item_name_by_id)
    self.modal:draw(ui)

    if view and view.finished then
      love.graphics.setColor(0, 0, 0, 0.45)
      love.graphics.rectangle("fill", 0, 0, w, h)
      love.graphics.setFont(ui.fonts.title)
      love.graphics.setColor(ui.palette.text)
      local winner = view.winner_name or "无人"
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
end

return LoveRuntime

local logger = require("src.util.logger")
local items_cfg = require("src.config.items")
local UIState = require("src.adapters.love2d.ui_state")
local Layout = require("src.adapters.love2d.layout")
local BoardRenderer = require("src.adapters.love2d.board_renderer")
local PanelRenderer = require("src.adapters.love2d.panel_renderer")
local Presenter = require("src.adapters.love2d.presenter")
local Modal = require("src.adapters.love2d.modal")
local AutoRunner = require("src.adapters.love2d.auto_runner")
local constants = require("src.config.constants")
local TurnUsecase = require("src.gameplay.app.usecases.turn_usecase")
local ActionUsecase = require("src.gameplay.app.usecases.action_usecase")
local Agent = require("src.gameplay.ai.agent")

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
    turn_usecase = nil,
    action_usecase = nil,
    modal = Modal.new(),
    auto_runner = AutoRunner.new({ interval = ui.auto_interval }),
    _auto_handled_choice_id = nil,
    _auto_choice_retry_timer = 0,
    _choice_timeout_choice_id = nil,
    _choice_timeout_timer = 0,
  }
  return setmetatable(self, LoveLayer)
end

function LoveLayer:_reset_choice_timeout()
  self._choice_timeout_choice_id = nil
  self._choice_timeout_timer = 0
end

function LoveLayer:_touch_choice_timeout(pending_choice)
  if not pending_choice or not pending_choice.id then
    self:_reset_choice_timeout()
    return
  end
  self._choice_timeout_choice_id = pending_choice.id
  self._choice_timeout_timer = 0
end

function LoveLayer:set_game(g)
  self.game = g
  if self.game then
    self.turn_usecase = self.game.turn_usecase or TurnUsecase.new(self.game)
    self.action_usecase = self.game.action_usecase or ActionUsecase.new({ game = self.game, turn_usecase = self.turn_usecase })
    self.game.turn_usecase = self.turn_usecase
    self.game.action_usecase = self.action_usecase
    self.game.ui_port = self
  else
    self.turn_usecase = nil
    self.action_usecase = nil
  end
end

function LoveLayer:get_pending_choice()
  if self.action_usecase and self.action_usecase.pending_choice then
    return self.action_usecase:pending_choice()
  end
  if self.game and self.game.store then
    return self.game.store:get({ "turn", "pending_choice" })
  end
end


function LoveLayer:push_popup(payload)
  self.modal:push({
    title = payload and payload.title,
    body = payload and payload.body,
    severity = payload and payload.severity,
    buttons = payload and payload.buttons,
    button_text = payload and payload.button_text,
    on_confirm = payload and payload.on_confirm,
  })
  return true
end


function LoveLayer:request_choice(opts)
  if not opts or not opts.candidates or #opts.candidates == 0 then
    local buttons = opts and opts.buttons
    if buttons and #buttons > 0 then
      self.modal:push({
        title = opts.title or "请选择",
        body = table.concat(opts.body_lines or {}, "\n"),
        buttons = buttons,
        button_text = opts.cancel_label or "取消",
      })
      return true
    end
    return false
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
      table.insert(body_lines, p.name .. " 现金:" .. p.cash .. (p.status and p.status.deity and (" 神:" .. p.status.deity.type) or ""))
    end
  end

  if opts.allow_cancel ~= false then
    table.insert(buttons, {
      label = opts.cancel_label or "取消",
      on_click = function()
        
      end,
    })
  end

  self.modal:push({
    title = opts.title or "选择玩家",
    body = table.concat(body_lines or {}, "\n"),
    buttons = buttons,
    button_text = opts.cancel_label or "取消",
  })
  return true
end


function LoveLayer:play_animation(payload)
  if payload and payload.on_complete then
    payload.on_complete()
  end
  return true
end

function LoveLayer:sync_pending_choice_modal()
  if not self.game or not self.game.store then
    return
  end
  local pending = self:get_pending_choice()
  if not pending then
    return
  end
  if self.modal.active and self.modal.active._pending_choice_id == pending.id then
    return
  end

  if self.modal.active and not self.modal.active._pending_choice_id then
    table.insert(self.modal.queue, 1, self.modal.active)
  end

  local buttons = {}
  for _, opt in ipairs(pending.options or {}) do
    table.insert(buttons, {
      label = opt.label or tostring(opt.id),
      on_click = function()
        self:dispatch_action({ type = "choice_select", choice_id = pending.id, option_id = opt.id })
      end,
    })
  end

  self.modal.active = {
    title = pending.title or "请选择",
    body = table.concat(pending.body_lines or {}, "\n"),
    buttons = buttons,
    button_text = pending.cancel_label or "取消",
    on_confirm = function()
      self:dispatch_action({ type = "choice_cancel", choice_id = pending.id })
    end,
    _pending_choice_id = pending.id,
  }
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
  local store_state = (self.game and self.game.store and self.game.store.state) or {}
  local view = Presenter.present(store_state, {
    last_turn = self.game and self.game.last_turn,
    finished = self.game and self.game.finished,
    winner_name = self.game and self.game.winner and self.game.winner.name or nil,
  })
  Layout.apply(self.ui, view)
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
  if self.action_usecase then
    self.action_usecase:advance_turn()
  elseif self.turn_usecase then
    self.turn_usecase:advance()
  end
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
  self:sync_pending_choice_modal()
  local mx, my = love.mouse.getPosition()
  self:update_hover_tile(mx, my)

  local pending_choice = self:get_pending_choice()
  if not pending_choice then
    self:_reset_choice_timeout()
  elseif self._choice_timeout_choice_id ~= pending_choice.id then
    self:_touch_choice_timeout(pending_choice)
  end

  if self.ui.auto_play and pending_choice then
    
    if self._auto_handled_choice_id == pending_choice.id then
      self._auto_choice_retry_timer = self._auto_choice_retry_timer + dt
    else
      self._auto_handled_choice_id = nil
      self._auto_choice_retry_timer = 0
    end

    if self._auto_handled_choice_id ~= pending_choice.id or self._auto_choice_retry_timer >= 0.6 then
      local auto_action = Agent.auto_action_for_choice(self.game, pending_choice)
      if auto_action and auto_action.choice_id and auto_action.choice_id ~= pending_choice.id then
        auto_action = nil
      end
      if auto_action and not auto_action.choice_id then
        auto_action.choice_id = pending_choice.id
      end
      if not auto_action then
        local first = pending_choice.options and pending_choice.options[1]
        if first then
          auto_action = { type = "choice_select", choice_id = pending_choice.id, option_id = first.id or first }
        else
          auto_action = { type = "choice_cancel", choice_id = pending_choice.id }
        end
      end
      self:dispatch_action(auto_action)
      self._auto_handled_choice_id = pending_choice.id
      self._auto_choice_retry_timer = 0
      if self.modal.active and self.modal.active._pending_choice_id == pending_choice.id then
        self.modal:dismiss()
      end
    end
  elseif not pending_choice then
    self._auto_handled_choice_id = nil
    self._auto_choice_retry_timer = 0
  end

  pending_choice = self:get_pending_choice()
  if pending_choice and not self.ui.auto_play then
    self._choice_timeout_timer = self._choice_timeout_timer + dt
    local timeout = constants.action_timeout_seconds or 10
    if timeout > 0 and self._choice_timeout_timer >= timeout then
      if pending_choice.allow_cancel ~= false then
        self:dispatch_action({ type = "choice_cancel", choice_id = pending_choice.id })
      else
        local first = pending_choice.options and pending_choice.options[1]
        if first then
          self:dispatch_action({ type = "choice_select", choice_id = pending_choice.id, option_id = first.id or first })
        else
          self:dispatch_action({ type = "choice_cancel", choice_id = pending_choice.id })
        end
      end
      self:_touch_choice_timeout(pending_choice)
      if self.modal.active and self.modal.active._pending_choice_id == pending_choice.id then
        self.modal:dismiss()
      end
    end
  end

  pending_choice = self:get_pending_choice()

  local auto_action = self.auto_runner:next_action(dt, {
    modal_active = self.modal.active ~= nil,
    modal_buttons = self.modal.active and self.modal.active.buttons,
    pending_choice = pending_choice,
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
    self:_touch_choice_timeout(self:get_pending_choice())
    local idx = action.index or 1
    if not self.modal:press_button(idx) then
      self.modal:keypressed("space")
    end
  elseif action.type == "modal_confirm" then
    self:_touch_choice_timeout(self:get_pending_choice())
    if not self.modal:confirm() then
      self.modal:keypressed("space")
    end
  elseif action.type == "choice_select" or action.type == "choice_cancel" then
    self:_touch_choice_timeout(self:get_pending_choice())
    if self.action_usecase then
      self.action_usecase:handle_choice(action)
    end
  end
end

function LoveLayer:mousepressed(x, y, button)
  if button ~= 1 then
    return
  end
  self:_touch_choice_timeout(self:get_pending_choice())
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
  self:_touch_choice_timeout(self:get_pending_choice())
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

  local store_state = (game and game.store and game.store.state) or {}
  local view = Presenter.present(store_state, {
    last_turn = game and game.last_turn,
    finished = game and game.finished,
    winner_name = game and game.winner and game.winner.name or nil,
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

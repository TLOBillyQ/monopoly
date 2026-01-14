local logger = require("src.util.logger")
local items_cfg = require("src.config.items")
local UIState = require("src.adapters.love2d.ui_state")
local Modal = require("src.adapters.love2d.modal")
local AutoRunner = require("src.adapters.love2d.auto_runner")
local LoveRuntime = require("src.adapters.love2d.love_runtime")

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
  if self.game then
    self.game.ui_port = self
  end
end

function LoveLayer:get_pending_choice()
  if self.game then
    return self.game:pending_choice()
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

function LoveLayer:step_turn()
  if self.modal.active then
    return
  end
  if not self.game or self.game.finished then
    return
  end
  self.game:advance_turn()
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
  elseif action.type == "choice_select" or action.type == "choice_cancel" then
    if self.game then
      self.game:dispatch_action(action)
    end
  end
end

LoveRuntime.install(LoveLayer)

return LoveLayer

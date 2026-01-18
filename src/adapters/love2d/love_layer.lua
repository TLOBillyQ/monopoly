local logger = require("src.util.logger")
local items_cfg = require("src.config.items")
local UIState = require("src.adapters.love2d.ui_state")
local Modal = require("src.adapters.love2d.modal")
local AutoRunner = require("src.adapters.love2d.auto_runner")
local LoveRuntime = require("src.adapters.love2d.love_runtime")
local IntentDispatcher = require("src.util.intent_dispatcher")

local LoveLayer = {}
LoveLayer.__index = LoveLayer

function LoveLayer.new(opts)
  opts = opts or {}
  local ui = UIState.create()
  local self = {
    ui = ui,
    game = nil,
    item_name_by_id = {},
    pending_choice = nil,
    game_factory = opts.game_factory,
    modal = Modal.new(),
    auto_runner = AutoRunner.new({ interval = ui.auto_interval }),
  }
  IntentDispatcher.on("need_choice", function(payload)
    if payload and payload.game == self.game then
      self.pending_choice = payload.choice
      self:open_choice_modal(payload.choice)
    end
  end)
  return setmetatable(self, LoveLayer)
end

function LoveLayer:set_game(g)
  self.game = g
  if self.game then
    self.game.ui_port = self
  end
  self.pending_choice = self.game and self.game:pending_choice() or nil
  if self.pending_choice then
    self:open_choice_modal(self.pending_choice)
  end
end

local function build_phase_title(game, base_title)
  if not (game and game.store) then
    return base_title
  end
  local phase = game.store:get({ "turn", "item_phase_active" })
  if not phase then
    return base_title
  end
  local label = phase == "pre_action" and "行动前"
    or phase == "pre_move" and "投骰后"
    or phase == "post_action" and "行动后"
    or phase
  return "[" .. label .. "] " .. (base_title or "请选择")
end

function LoveLayer:push_popup(payload)
  self.modal:push({
    title = build_phase_title(self.game, payload and payload.title),
    body = payload and payload.body,
    severity = payload and payload.severity,
    buttons = payload and payload.buttons,
    button_text = payload and payload.button_text,
    on_confirm = payload and payload.on_confirm,
  })
  return true
end

function LoveLayer:open_choice_modal(pending)
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
    title = build_phase_title(self.game, pending.title or "请选择"),
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
    self.pending_choice = nil
    if self.game then
      self.game:dispatch_action(action)
    end
  end
end

LoveRuntime.install(LoveLayer)

return LoveLayer

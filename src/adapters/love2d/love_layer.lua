local UIState = require("src.adapters.love2d.ui_state")
local Modal = require("src.adapters.love2d.modal")
local AutoRunner = require("src.adapters.core.auto_runner")
local LoveRuntime = require("src.adapters.love2d.love_runtime")
local AdapterLayer = require("src.adapters.core.adapter_layer")
local ChoiceView = require("src.adapters.core.ui_choice")
local PhaseView = require("src.adapters.core.ui_phase")

local LoveLayer = {}
LoveLayer.__index = LoveLayer

function LoveLayer:_sync_auto_player(enabled)
  if not self.game or not self.game.players then
    return
  end
  local player = self.game.players[1]
  if not player then
    return
  end
  player.auto = enabled
  if player._store_set then
    player:_store_set({ "players", player.id, "auto" }, player.auto)
  end
end

function LoveLayer.new(opts)
  opts = opts or {}
  local ui = UIState.create()
  local self = setmetatable({
    ui = ui,
    modal = Modal.new(),
  }, LoveLayer)
  AdapterLayer.attach(self, {
    ui = ui,
    game_factory = opts.game_factory,
    auto_runner = AutoRunner.new({ interval = ui.auto_interval }),
    on_need_choice = function(layer, choice)
      layer:open_choice_modal(choice)
    end,
  })
  return self
end

function LoveLayer:set_game(g)
  AdapterLayer.set_game(self, g, {
    on_set_game = function(layer)
      layer:_sync_auto_player(layer.ui.auto_play)
    end,
    on_pending_choice = function(layer, pending)
      layer:open_choice_modal(pending)
    end,
  })
end

function LoveLayer:push_popup(payload)
  self.modal:push({
    title = PhaseView.build_phase_title(self.game, payload and payload.title),
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

  local function love_option_label(opt)
    if opt and opt.label then
      return opt.label
    end
    return tostring(opt and opt.id)
  end

  local view = ChoiceView.build_choice_view(pending, {
    game = self.game,
    option_label = love_option_label,
    body_lines_only = true,
  })
  if not view then
    return
  end

  local buttons = {}
  for _, opt in ipairs(view.options or {}) do
    local raw = opt.raw
    local opt_id = nil
    if type(raw) == "table" then
      opt_id = raw.id
    end
    table.insert(buttons, {
      label = opt.label,
      on_click = function()
        self:dispatch_action({ type = "choice_select", choice_id = pending.id, option_id = opt_id })
      end,
    })
  end

  self.modal.active = {
    title = view.title,
    body = view.body,
    buttons = buttons,
    button_text = view.cancel_label,
    on_confirm = function()
      self:dispatch_action({ type = "choice_cancel", choice_id = pending.id })
    end,
    _pending_choice_id = pending.id,
  }
  self.pending_choice_elapsed = 0
  self.pending_choice_id = pending.id
end

function LoveLayer:get_game()
  return self.game
end

function LoveLayer:build_item_index()
  AdapterLayer.build_item_index(self)
end

function LoveLayer:new_game()
  return AdapterLayer.new_game(self, {
    on_new_game = function(layer)
      layer.ui.selected_tile = nil
      layer.ui.hover_tile = nil
    end,
  })
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
    self:_sync_auto_player(self.ui.auto_play)
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
    AdapterLayer.clear_choice(self)
    if self.game then
      self.game:dispatch_action(action)
    end
  end
end

LoveRuntime.install(LoveLayer)

return LoveLayer

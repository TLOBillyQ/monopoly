local logger = require("src.util.logger")
local constants = require("src.config.constants")
local UIState = require("src.adapters.eggy.ui_state")
local AutoRunner = require("src.adapters.love2d.auto_runner")
local Presenter = require("src.adapters.eggy.presenter")
local IntentDispatcher = require("src.util.intent_dispatcher")
local Agent = require("src.gameplay.agent")

local EggyLayer = {}
EggyLayer.__index = EggyLayer

local function build_log_prefix()
  return "[EggyAdapter]"
end

function EggyLayer.new(opts)
  opts = opts or {}
  local ui = UIState.create()
  local self = {
    ui = ui,
    game = nil,
    pending_choice = nil,
    pending_choice_elapsed = 0,
    pending_choice_id = nil,
    game_factory = opts.game_factory,
    auto_runner = AutoRunner.new({ interval = ui.auto_interval }),
  }

  IntentDispatcher.on("need_choice", function(payload)
    if payload and payload.game == self.game then
      self.pending_choice = payload.choice
      self.pending_choice_elapsed = 0
      self.pending_choice_id = payload.choice and payload.choice.id or nil
      self:_open_choice_modal(payload.choice)
    end
  end)

  return setmetatable(self, EggyLayer)
end

function EggyLayer:set_game(g)
  self.game = g
  if self.game then
    self.game.ui_port = self
  end
  self.pending_choice = self.game and self.game:pending_choice() or nil
  if self.pending_choice then
    self.pending_choice_elapsed = 0
    self.pending_choice_id = self.pending_choice.id
    self:_open_choice_modal(self.pending_choice)
  end
end

function EggyLayer:new_game()
  logger.clear()
  assert(self.game_factory, "game_factory not set")
  local g = self.game_factory()
  self.auto_runner:reset_timer()
  g.logger.info("启动蛋仔大富翁，玩家数:", #g.players)
  return g
end

function EggyLayer:_log_status(view)
  if not view then
    return
  end
  logger.info(
    build_log_prefix(),
    "玩家:",
    tostring(view.current_player_name),
    "现金:",
    tostring(view.current_player_cash),
    "回合:",
    tostring(view.turn_count)
  )
end

function EggyLayer:tick(dt)
  if not self.game then
    return
  end

  if self.pending_choice then
    self:_open_choice_modal(self.pending_choice)
  end

  local auto_action = self.auto_runner:next_action(dt, {
    modal_active = false,
    modal_buttons = nil,
    game_finished = self.game.finished,
  })
  if auto_action then
    self:dispatch_action(auto_action)
  end

  local timeout = constants.action_timeout_seconds or 0
  if timeout > 0 and self.pending_choice then
    if self.pending_choice_id ~= self.pending_choice.id then
      self.pending_choice_elapsed = 0
      self.pending_choice_id = self.pending_choice.id
    end
    self.pending_choice_elapsed = self.pending_choice_elapsed + dt
    if self.pending_choice_elapsed >= timeout then
      local choice = self.pending_choice
      self.pending_choice_elapsed = 0
      local auto_choice = Agent.auto_action_for_choice(self.game, choice)
      if auto_choice then
        self:dispatch_action(auto_choice)
      else
        local first = choice.options and choice.options[1]
        if first then
          self:dispatch_action({
            type = "choice_select",
            choice_id = choice.id,
            option_id = first.id or first,
          })
        elseif choice.allow_cancel ~= false then
          self:dispatch_action({ type = "choice_cancel", choice_id = choice.id })
        end
      end
    end
  else
    self.pending_choice_elapsed = 0
    self.pending_choice_id = nil
  end

  self:_log_status(self:build_view())
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

function EggyLayer:_open_choice_modal(pending)
  if not pending then
    return
  end
  if self.pending_choice_id == pending.id and self.ui.choice_active then
    return
  end

  local title = build_phase_title(self.game, pending.title or "请选择")
  local body = ""
  if pending.body_lines then
    body = table.concat(pending.body_lines, "\n")
  elseif pending.body then
    body = pending.body
  end

  self.ui:set_label(self.ui.choice.title, title)
  self.ui:set_label(self.ui.choice.body, body)
  self.ui:set_visible(self.ui.choice.root, true)

  local option_nodes = self.ui.choice.option_buttons or {}
  for idx, name in ipairs(option_nodes) do
    local opt = pending.options and pending.options[idx]
    if opt then
      self.ui:set_button(name, opt.label or tostring(opt.id or opt))
      self.ui:set_visible(name, true)
      self.ui:set_touch_enabled(name, true)
    else
      self.ui:set_visible(name, false)
      self.ui:set_touch_enabled(name, false)
    end
  end

  if pending.allow_cancel == false then
    self.ui:set_visible(self.ui.choice.cancel, false)
    self.ui:set_touch_enabled(self.ui.choice.cancel, false)
  else
    self.ui:set_button(self.ui.choice.cancel, pending.cancel_label or "取消")
    self.ui:set_visible(self.ui.choice.cancel, true)
    self.ui:set_touch_enabled(self.ui.choice.cancel, true)
  end

  self.ui.choice_active = true
  self.pending_choice_elapsed = 0
  self.pending_choice_id = pending.id
end

function EggyLayer:_close_choice_modal()
  if not self.ui.choice_active then
    return
  end
  self.ui:set_visible(self.ui.choice.root, false)
  self.ui.choice_active = false
end

function EggyLayer:build_view()
  local store_state = (self.game and self.game.store and self.game.store.state) or {}
  local winner_name = self.game and (self.game.winner_names or (self.game.winner and self.game.winner.name)) or nil
  return Presenter.present(store_state, {
    game = self.game,
    last_turn = self.game and self.game.last_turn,
    finished = self.game and self.game.finished,
    winner_name = winner_name,
  })
end

function EggyLayer:step_turn()
  if not self.game or self.game.finished then
    return
  end
  self.game:advance_turn()
end

function EggyLayer:dispatch_action(action)
  if not action then
    return
  end
  if action.type == "ui_button" then
    if action.id == "next" then
      self:step_turn()
    elseif action.id == "auto" then
      self.ui.auto_play = not self.ui.auto_play
      self.auto_runner:set_enabled(self.ui.auto_play)
      self.auto_runner:reset_timer()
    elseif action.id == "restart" then
      local was_auto = self.ui.auto_play
      self:set_game(self:new_game())
      self.auto_runner:set_enabled(was_auto)
    end
  elseif action.type == "choice_select" or action.type == "choice_cancel" then
    self.pending_choice = nil
    self.pending_choice_elapsed = 0
    self.pending_choice_id = nil
    self:_close_choice_modal()
    if self.game then
      self.game:dispatch_action(action)
    end
  end
end

function EggyLayer:tick_once(dt)
  self:tick(dt)
end

return EggyLayer

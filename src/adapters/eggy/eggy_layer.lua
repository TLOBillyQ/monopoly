local logger = require("src.util.logger")
local AutoRunner = require("src.adapters.core.auto_runner")
local Presenter = require("src.adapters.core.presenter")
local AdapterLayer = require("src.adapters.core.adapter_layer")
local ChoiceView = require("src.adapters.core.ui_choice")
local EggyLayerUI = require("src.adapters.eggy.eggy_layer_ui")
local EggyLayerMarket = require("src.adapters.eggy.eggy_layer_market")
local EggyLayerBoard = require("src.adapters.eggy.eggy_layer_board")
local MarketUI = require("src.adapters.eggy.market_ui")
local MoveAnim = require("src.adapters.eggy.move_anim")
local ActionAnim = require("src.adapters.eggy.action_anim")
local Agent = require("src.gameplay.agent")

local EggyLayer = {}
EggyLayer.__index = EggyLayer

local function build_log_prefix()
  return "[EggyAdapter]"
end

local function log_once(self, level, key, ...)
  if not self or not self._log_once or self._log_once[key] then
    return
  end
  self._log_once[key] = true
  if level == "warn" then
    logger.warn(...)
  else
    logger.info(...)
  end
end

local function show_tips(message, duration)
  local text = message and tostring(message) or ""
  if text == "" then
    return false
  end
  local tip_duration = duration
  if type(duration) == "number" and math and math.tofixed then
    tip_duration = math.tofixed(duration)
  end
  if GlobalAPI and GlobalAPI.show_tips then
    GlobalAPI.show_tips(text, tip_duration)
    return true
  end
  local role = Role
  if role and role.show_tips then
    role.show_tips(text, tip_duration)
    return true
  end
  return false
end

local NEXT_TURN_COOLDOWN = 0.4

local function get_timestamp_seconds()
  if not (GameAPI and GameAPI.get_timestamp) then
    return nil
  end
  local ts = GameAPI.get_timestamp()
  if type(ts) ~= "number" then
    return nil
  end
  if ts > 10000000000 then
    return ts / 1000
  end
  return ts
end

function EggyLayer.new(opts)
  opts = opts or {}
  local ui = EggyLayerUI.build_ui_state()
  local self = setmetatable({
    ui = ui,
    tile_units = nil,
    tile_positions = nil,
    tile_spacing = nil,
    player_units = nil,
    player_units_missing = false,
    board_last_positions = nil,
    board_sync_pending = false,
    board_last_phase = nil,
    next_turn_locked = false,
    next_turn_last_click = nil,
    next_turn_lock_phase = nil,
    _log_once = {},
  }, EggyLayer)
  AdapterLayer.attach(self, {
    ui = ui,
    game_factory = opts.game_factory,
    auto_runner = AutoRunner.new({ interval = ui.auto_interval }),
    on_need_choice = function(layer, choice)
      layer:_open_choice_modal(choice)
    end,
  })
  logger.set_adapter({
    level = "event",
    on_log = function(entry)
      show_tips(entry.text, 2)
    end,
  })

  return self
end

function EggyLayer:set_game(g)
  AdapterLayer.set_game(self, g, {
    on_pending_choice = function(layer, pending)
      layer:_open_choice_modal(pending)
    end,
  })
  self.player_units = nil
  self.player_units_missing = false
end

function EggyLayer:build_item_index()
  AdapterLayer.build_item_index(self)
end

function EggyLayer:new_game()
  return AdapterLayer.new_game(self)
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

  AdapterLayer.step_auto_runner(self, dt, {
    modal_active = false,
    modal_buttons = nil,
    game_finished = self.game and self.game.finished,
  })

  AdapterLayer.step_choice_timeout(self, dt, {
    build_action = function(layer, choice)
      local auto_choice = Agent.auto_action_for_choice(layer.game, choice)
      if auto_choice then
        return auto_choice
      end
      local first = choice.options and choice.options[1]
      if first then
        return {
          type = "choice_select",
          choice_id = choice.id,
          option_id = first.id or first,
        }
      end
      if choice.allow_cancel ~= false then
        return { type = "choice_cancel", choice_id = choice.id }
      end
      return nil
    end,
  })

  AdapterLayer.step_modal_timeout(self, dt, {
    is_active = function(layer)
      return layer.ui and layer.ui.popup_active
    end,
    get_ref = function(layer)
      return layer.ui and layer.ui.popup_active and layer.ui.popup_seq or nil
    end,
    on_timeout = function(layer)
      layer:close_popup()
    end,
  })

  AdapterLayer.step_move_anim(self, {
    on_move_anim = function(_, anim)
      if not anim then
        return nil
      end
      local player_id = anim.player_id
      local from_index = anim.from_index
      local to_index = anim.to_index
      if not (player_id and from_index and to_index) then
        return nil
      end
      local dir = anim.direction
      if not dir and anim.steps then
        if anim.steps < 0 then
          dir = V3_RIGHT
        elseif anim.steps > 0 then
          dir = V3_LEFT
        end
      end
      return MoveAnim.one_step(player_id, dir, from_index, to_index)
    end,
  })

  AdapterLayer.step_action_anim(self, {
    on_action_anim = function(layer, anim)
      return ActionAnim.play(layer, anim)
    end,
  })

  local store = self.game and self.game.store
  if store and store.get then
    local phase = store:get({ "turn", "phase" })
    if self.board_last_phase == "wait_move_anim" and phase ~= "wait_move_anim" then
      self.board_sync_pending = true
    end
    if self.next_turn_locked and self.next_turn_lock_phase and phase and phase ~= self.next_turn_lock_phase then
      self.next_turn_locked = false
      self.next_turn_lock_phase = phase
    end
    self.board_last_phase = phase
  end

  if self.pending_choice then
    self:_open_choice_modal(self.pending_choice)
  end

  self:refresh_view()

  self:_log_status(self:build_view())
end

function EggyLayer:select_market_option(option_id)
  EggyLayerMarket.select_market_option(self, option_id)
end

function EggyLayer:_open_market_panel(pending)
  return EggyLayerMarket.open_market_panel(self, pending)
end

function EggyLayer:_close_market_panel()
  EggyLayerMarket.close_market_panel(self)
end

function EggyLayer:_open_choice_modal(pending)
  if not pending then
    return
  end
  if self.pending_choice_id == pending.id
    and (self.ui.choice_active or self.ui.market_active) then
    return
  end

  if pending.kind == "market_buy"
    and MarketUI.is_panel_ready
    and MarketUI.is_panel_ready() then
    if self.ui.choice_active then
      self.ui:set_visible(self.ui.choice.root, false)
      self.ui.choice_active = false
    end
    self:_open_market_panel(pending)
    return
  end
  if self.ui.market_active then
    self:_close_market_panel()
  end

  local view = ChoiceView.build_choice_view(pending, { game = self.game })
  if not view then
    return
  end

  self.ui:set_label(self.ui.choice.title, view.title)
  self.ui:set_label(self.ui.choice.body, view.body)
  self.ui:set_visible(self.ui.choice.root, true)

  local option_nodes = self.ui.choice.option_buttons or {}
  for idx, name in ipairs(option_nodes) do
    local opt = view.options and view.options[idx]
    if opt then
      self.ui:set_button(name, opt.label)
      self.ui:set_visible(name, true)
      self.ui:set_touch_enabled(name, true)
    else
      self.ui:set_visible(name, false)
      self.ui:set_touch_enabled(name, false)
    end
  end

  if not view.allow_cancel then
    self.ui:set_visible(self.ui.choice.cancel, false)
    self.ui:set_touch_enabled(self.ui.choice.cancel, false)
  else
    self.ui:set_button(self.ui.choice.cancel, view.cancel_label)
    self.ui:set_visible(self.ui.choice.cancel, true)
    self.ui:set_touch_enabled(self.ui.choice.cancel, true)
  end

  self.ui.choice_active = true
  self.pending_choice_elapsed = 0
  self.pending_choice_id = pending.id
end

function EggyLayer:_close_choice_modal()
  if self.ui.choice_active then
    self.ui:set_visible(self.ui.choice.root, false)
    self.ui.choice_active = false
  end
  if self.ui.market_active then
    self:_close_market_panel()
  end
  self.market_choice_option_ids = nil
  self.pending_choice_selected_option_id = nil
end

function EggyLayer:build_view()
  local store_state = self.game.store.state
  local winner_name = self.game.winner_names
  if not winner_name and self.game.winner then
    winner_name = self.game.winner.name
  end
  return Presenter.present(store_state, {
    game = self.game,
    last_turn = self.game.last_turn,
    finished = self.game.finished,
    winner_name = winner_name,
  })
end

function EggyLayer:refresh_view()
  local view = self:build_view()
  self:refresh_panel(view)
  self:refresh_board(view)
end

function EggyLayer:refresh_panel(view)
  EggyLayerUI.refresh_panel(self, view)
end

function EggyLayer:refresh_item_slots(view)
  EggyLayerUI.refresh_item_slots(self, view)
end

function EggyLayer:refresh_board(view)
  EggyLayerBoard.refresh_board(self, view, log_once, build_log_prefix)
end

function EggyLayer:on_tile_upgraded(tile_id, level)
  EggyLayerBoard.on_tile_upgraded(self, tile_id, level)
end

function EggyLayer:on_tile_owner_changed(tile_id, owner_id)
  EggyLayerBoard.on_tile_owner_changed(self, tile_id, owner_id)
end

function EggyLayer:step_turn()
  if not self.game or self.game.finished then
    return
  end
  print("[debug] step_turn: advance_turn")
  self.game:advance_turn()
end

function EggyLayer:dispatch_action(action)
  if not action then
    return
  end
  if action.type == "ui_button" then
    local slot_index = action.id and string.match(action.id, "^item_slot_(%d+)$")
    if slot_index then
      slot_index = tonumber(slot_index)
      local choice = self.pending_choice
      if not (choice and choice.kind == "item_phase_choice") then
        return
      end
      local item_ids = self.ui and self.ui.item_slot_item_ids or nil
      local item_id = item_ids and item_ids[slot_index] or nil
      if not item_id then
        return
      end
      local options = choice.options or {}
      local option_ok = false
      for _, opt in ipairs(options) do
        local opt_id = opt.id or opt
        if opt_id == item_id then
          option_ok = true
          break
        end
      end
      if not option_ok then
        return
      end
      self:dispatch_action({ type = "choice_select", choice_id = choice.id, option_id = item_id })
      return
    end
    if action.id == "next" then
      print("[debug] dispatch ui_button next")
      local phase = nil
      local store = self.game and self.game.store
      if store and store.get then
        phase = store:get({ "turn", "phase" })
      end
      local now = get_timestamp_seconds()
      if self.next_turn_locked then
        local allow = false
        if self.next_turn_lock_phase and phase and phase ~= self.next_turn_lock_phase then
          allow = true
        elseif now and self.next_turn_last_click
          and (now - self.next_turn_last_click) >= NEXT_TURN_COOLDOWN then
          allow = true
        end
        if not allow then
          return
        end
      end
      self.next_turn_locked = true
      self.next_turn_last_click = now
      self.next_turn_lock_phase = phase
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
    AdapterLayer.clear_choice(self, {
      on_close_choice = function(layer)
        layer:_close_choice_modal()
      end,
    })
    if self.game then
      self.game:dispatch_action(action)
    end
  end
end

function EggyLayer:push_popup(payload)
  if not payload then
    return false
  end
  self.ui:set_label(self.ui.popup.title, payload.title or "提示")
  self.ui:set_label(self.ui.popup.body, payload.body or "")
  self.ui:set_button(self.ui.popup.confirm, payload.button_text or "知道了")
  self.ui:set_visible(self.ui.popup.root, true)
  self.ui.popup_active = true
  self.ui.popup_seq = (self.ui.popup_seq or 0) + 1
  return true
end

function EggyLayer:close_popup()
  if not self.ui.popup_active then
    return
  end
  self.ui:set_visible(self.ui.popup.root, false)
  self.ui.popup_active = false
end

function EggyLayer:tick_once(dt)
  self:tick(dt)
end

return EggyLayer

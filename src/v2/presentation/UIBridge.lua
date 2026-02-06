local ui_view = require("src.ui.UIView")
local ui_aliases = require("src.ui.UIAliases")
local board_scene = require("src.ui.BoardScene")
local market_ui = require("src.ui.MarketUI")
local ui_events = require("Config.UIEvents")
local logger = require("src.core.Logger")

local ui_bridge = {}
ui_bridge.__index = ui_bridge

local function _query_nodes(name)
  local resolved = ui_aliases.resolve(name)
  return UIManager.query_nodes_by_name(resolved)
end

local function _register_click(listener_store, name, callback)
  local nodes = _query_nodes(name)
  if not nodes or not nodes[1] then
    return
  end
  for _, node in ipairs(nodes) do
    local listener = node:listen(UIManager.EVENT.CLICK, function(data)
      callback(data)
    end)
    listener_store[#listener_store + 1] = listener
  end
end

local function _log_once(state, level, key, ...)
  if state._log_once[key] then
    return
  end
  state._log_once[key] = true
  if level == "warn" then
    logger.warn(...)
  else
    logger.info(...)
  end
end

local function _prefix()
  return "[V2]"
end

function ui_bridge.new(opts)
  opts = opts or {}
  local state = {
    ui = ui_view.build_ui_state(),
    board_last_positions = {},
    board_sync_pending = false,
    pending_choice = nil,
    pending_choice_elapsed = 0,
    pending_choice_id = nil,
    pending_choice_selected_option_id = nil,
    ui_modal_elapsed = 0,
    ui_modal_ref = nil,
    move_anim_seq = nil,
    action_anim_seq = nil,
    wait_move_anim = true,
    wait_action_anim = true,
    _log_once = {},
    ui_dirty = true,
  }

  local instance = {
    state = state,
    listeners = {},
    map_cfg = opts.map_cfg,
    input_handler = nil,
  }
  setmetatable(instance, ui_bridge)
  return instance
end

function ui_bridge:initialize()
  require "vendor.third_party.UIManager.Utils"
  UIManager.Builder:new(require "Data.UIManagerNodes")
  if self.map_cfg then
    board_scene.init(self.state, self.map_cfg)
  end
  ui_view.init_ui_assets(self.state)
  ui_events.send_to_all(ui_events.show["加载屏"], {})
  SetTimeOut(1.0, function()
    ui_events.send_to_all(ui_events.hide["加载屏"], {})
    ui_events.send_to_all(ui_events.show["基础屏"], {})
  end)
end

function ui_bridge:set_board_adapter(board)
  self.state.game = self.state.game or {}
  self.state.game.board = board
end

function ui_bridge:unbind()
  for _, listener in ipairs(self.listeners) do
    if listener and listener.destroy then
      listener:destroy()
    end
  end
  self.listeners = {}
end

function ui_bridge:bind_inputs(on_intent)
  self:unbind()
  self.input_handler = on_intent

  _register_click(self.listeners, "行动按钮", function()
    on_intent({ type = "next" })
  end)
  _register_click(self.listeners, "托管按钮", function()
    on_intent({ type = "auto_toggle" })
  end)
  _register_click(self.listeners, "自动控制按钮", function()
    on_intent({ type = "auto_toggle" })
  end)

  for idx = 1, 5 do
    _register_click(self.listeners, "道具槽位" .. tostring(idx), function()
      local model = self.state.ui_model or {}
      local choice = model.choice
      if not choice or choice.kind ~= "item_phase_choice" then
        return
      end
      local item_id = model.item_slots and model.item_slots[idx]
      if not item_id then
        return
      end
      on_intent({
        type = "use_item",
        item_id = item_id,
      })
    end)
  end

  _register_click(self.listeners, "通用选择_取消", function()
    local choice = self.state.ui_model and self.state.ui_model.choice
    if choice and choice.allow_cancel ~= false then
      on_intent({ type = "choice_cancel", choice_id = choice.id })
    end
  end)

  for idx, name in ipairs({
    "通用选择_选项_01",
    "通用选择_选项_02",
    "通用选择_选项_03",
    "通用选择_选项_04",
  }) do
    _register_click(self.listeners, name, function()
      local choice = self.state.ui_model and self.state.ui_model.choice
      if not choice then
        return
      end
      local option = choice.options and choice.options[idx]
      if not option then
        return
      end
      on_intent({
        type = "choice_select",
        choice_id = choice.id,
        option_id = option.id or option,
      })
    end)
  end

  for idx, name in ipairs(market_ui.item_buttons) do
    _register_click(self.listeners, name, function()
      local market = self.state.ui_model and self.state.ui_model.market
      if not market or not market.options then
        return
      end
      local option = market.options[idx]
      if not option then
        return
      end
      local option_id = option.id or option
      self.state.pending_choice_selected_option_id = option_id
      ui_view.select_market_option(self.state, option_id)
      on_intent({ type = "market_select", option_id = option_id, choice_id = market.choice_id })
    end)
  end

  _register_click(self.listeners, market_ui.confirm_button, function()
    local market = self.state.ui_model and self.state.ui_model.market
    local option_id = self.state.pending_choice_selected_option_id
    if market and option_id then
      on_intent({ type = "market_buy", choice_id = market.choice_id, option_id = option_id })
    end
  end)

  _register_click(self.listeners, market_ui.cancel_button, function()
    on_intent({ type = "market_cancel" })
  end)

  _register_click(self.listeners, "弹窗确认", function()
    if self.state.ui and self.state.ui.popup_active then
      ui_view.close_popup(self.state)
    end
  end)
end

function ui_bridge:render(model)
  self.state.ui_model = model

  local phase = model and model.board and model.board.phase
  local block = phase == "wait_move_anim" or phase == "wait_action_anim"
  if self.state.ui then
    self.state.ui.input_blocked = block
  end

  ui_view.render(self.state, model, _log_once, _prefix)

  if model.choice then
    ui_view.open_choice_modal(self.state, model.choice, model.market)
  else
    if self.state.ui.choice_active or self.state.ui.market_active then
      ui_view.close_choice_modal(self.state)
    end
  end

  if model.popup then
    if not self.state.ui.popup_active then
      ui_view.push_popup(self.state, model.popup)
    end
  elseif self.state.ui.popup_active then
    ui_view.close_popup(self.state)
  end

  ui_view.apply_input_lock(self.state)
end

return ui_bridge

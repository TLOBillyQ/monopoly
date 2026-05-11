local modal_state = require("src.ui.state.modal")
local common = require("src.ui.coord.choice_screens.helpers")
local ui_nodes = require("src.ui.render.node_ops")
local ui_controls = require("src.ui.render.support.ui_controls")
local logger = require("src.foundation.log.logger")

local M = {}

local function _open_screen(state, screen_key, choice, choice_id)
  local ui = state.ui
  local screen = ui.choice_screens[screen_key]
  assert(screen ~= nil, "missing choice screen: " .. tostring(screen_key))

  common.hide_choice_screens(ui)
  ui_controls.set_control_state(ui, screen.root, { visible = true })
  if screen.title then
    ui:set_label(screen.title, choice.title or "请选择")
  end
  if screen.body then
    ui:set_label(screen.body, choice.body or "")
  end
  common.switch_modal_canvas(state, common.resolve_canvas_for_screen(screen_key))
  ui.choice_active = true
  ui.active_choice_screen_key = screen_key
  return ui, screen
end

local function _compact_options(options)
  local out = {}
  for _, option in ipairs(options or {}) do
    if option ~= nil then
      out[#out + 1] = option
    end
  end
  return out
end

local function _set_action_button(ui, name, visible, enabled, label)
  if not name then
    return
  end
  if visible and label ~= nil then
    ui:set_button(name, label)
  end
  ui_controls.set_control_state(ui, name, {
    visible = visible,
    touch_enabled = enabled,
  })
end

local function _store_target_button_labels(screen, choice)
  if not screen then
    return
  end
  screen.confirm_label = "确定"
  screen.cancel_label = choice and choice.cancel_label or "取消"
end

local function _sync_slot_label(ui, label_node, option)
  if not label_node then
    return
  end
  if option then
    ui:set_label(label_node, common.resolve_option_label(option))
  else
    ui:set_label(label_node, "")
  end
  ui_controls.set_control_state(ui, label_node, {
    visible = option ~= nil,
    touch_enabled = false,
  })
end

local function _sync_projection_node(ui, projection_node, option)
  if not projection_node then
    return
  end
  ui_controls.set_control_state(ui, projection_node, {
    visible = option ~= nil,
    touch_enabled = false,
  })
end

local function _capture_selected_option(selected, option_id)
  if selected ~= nil then
    return selected
  end
  return option_id
end

local function _fill_option_nodes(ui, screen, options, opts)
  local option_ids = {}
  local selected = nil
  opts = opts or {}
  for index, name in ipairs(screen.option_buttons or {}) do
    local option = options[index]
    local option_id = common.set_option_node(ui, name, option)
    option_ids[index] = option_id
    if opts.clear_button_text == true and option then
      ui:set_button(name, "")
    end

    _sync_slot_label(ui, screen.slot_labels and screen.slot_labels[index] or nil, option)
    _sync_projection_node(ui, screen.slot_projections and screen.slot_projections[index] or nil, option)
    selected = _capture_selected_option(selected, option_id)
  end
  return option_ids, selected
end

local function _order_target_options(choice)
  local options = choice.options or {}
  local layout = choice.target_slot_layout
  if not layout then
    return options
  end
  local slots = {}
  for i, option in ipairs(options) do
    local slot = layout[i] or i
    slots[slot] = option
  end
  return slots
end

local function _resolve_player_or_remote_options(choice, screen_key)
  if screen_key == "player" and choice.target_slot_layout then
    return _order_target_options(choice)
  end
  return _compact_options(choice.options)
end

function M.open_choice_modal(state, choice, market)
  local screen_key = common.resolve_screen_key(choice)
  if screen_key == "base_inline" or screen_key == "market" then
    return false
  end

  local openers = {
    player = M.open_player_or_remote_screen,
    remote = M.open_player_or_remote_screen,
    secondary_confirm = M.open_secondary_confirm_screen,
    target = M.open_target_screen,
  }
  local open = openers[screen_key]
  if not open then
    logger.warn("unsupported choice screen key:", tostring(screen_key))
    return false
  end
  open(state, choice, choice.id, screen_key)
  return true
end

function M.open_player_or_remote_screen(state, choice, choice_id, screen_key)
  local ui, screen = _open_screen(state, screen_key, choice, choice_id)
  local option_ids, selected = _fill_option_nodes(ui, screen, _resolve_player_or_remote_options(choice, screen_key))
  _set_action_button(ui, screen.confirm, true, true, "确定")

  local allow_cancel = choice.allow_cancel ~= false
  _set_action_button(ui, screen.cancel, allow_cancel, allow_cancel, choice.cancel_label or "取消")
  modal_state.open_choice(state, choice_id, option_ids, selected)
end

function M.open_target_screen(state, choice, choice_id)
  local ui, screen = _open_screen(state, "target", choice, choice_id)
  local option_ids, selected = _fill_option_nodes(ui, screen, _order_target_options(choice), {
    clear_button_text = true,
  })
  _store_target_button_labels(screen, choice)
  modal_state.open_choice(state, choice_id, option_ids, selected)
  ui_nodes.sync_target_choice_buttons(state)
end

function M.open_secondary_confirm_screen(state, choice, choice_id)
  local ui, screen = _open_screen(state, "secondary_confirm", choice, choice_id)
  local first_option = choice.options and choice.options[1] or nil
  local selected = common.resolve_option_id(first_option)
  ui:set_label(screen.title, common.resolve_secondary_confirm_title(choice, state.game, "secondary_confirm", selected))
  if screen.body then
    ui:set_label(screen.body, common.build_secondary_confirm_body(choice, state.game, selected))
  end

  _set_action_button(ui, screen.confirm, true, selected ~= nil, "")
  local allow_cancel = choice.allow_cancel ~= false
  _set_action_button(ui, screen.cancel, allow_cancel, allow_cancel, allow_cancel and "" or nil)
  modal_state.open_choice(state, choice_id, { selected }, selected)
end

function M.open_pre_confirm_screen(state, choice, option_id, title, body)
  local ui, screen = _open_screen(state, "secondary_confirm", choice, choice.id)
  ui:set_label(screen.title, title or "请确认")
  if screen.body then
    ui:set_label(screen.body, body or "")
  end
  _set_action_button(ui, screen.confirm, true, option_id ~= nil, "")
  _set_action_button(ui, screen.cancel, true, true, "")
  modal_state.open_choice(state, choice.id, { option_id }, option_id)
end

return M

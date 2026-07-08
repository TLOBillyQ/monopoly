local common = require("src.ui.coord.choice_helpers")
local ui_controls = require("src.ui.render.support.ui_controls")
local logger = require("src.foundation.log")
local panel_interrupt = require("src.ui.coord.panel_interrupt")

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
  panel_interrupt.interrupt(state)
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
    selected = selected or option_id
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

local _screen_openers = {}

function M.open_choice_modal(state, choice, market)
  local screen_key = common.resolve_screen_key(choice)
  if screen_key == "base_inline" or screen_key == "market" then
    return false
  end

  local open = require("src.ui.screens.registry").opener_for(screen_key) or _screen_openers[screen_key]
  if not open then
    logger.warn("unsupported choice screen key:", tostring(screen_key))
    return false
  end
  open(state, choice, choice.id, screen_key)
  return true
end

M.open_screen = _open_screen
M.fill_option_nodes = _fill_option_nodes
M.order_target_options = _order_target_options
M.store_target_button_labels = _store_target_button_labels
M.set_action_button = _set_action_button
M.resolve_player_or_remote_options = _resolve_player_or_remote_options

-- 向后兼容：旧调用点/测试仍通过 choice_openers 访问二次确认开屏；内部已迁至 screen 模块。
function M.open_secondary_confirm_screen(state, choice, choice_id)
  return require("src.ui.screens.secondary_confirm").open(state, choice, choice_id)
end
function M.open_pre_confirm_screen(state, choice, option_id, title, body)
  return require("src.ui.screens.secondary_confirm").open_pre_confirm(state, choice, option_id, title, body)
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=258ffb9abf1a025a
scope.0.id=chunk:src/ui/coord/choice_openers.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=157
scope.0.semanticHash=90f6a517e8407885
scope.1.id=function:_open_screen:8
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=26
scope.1.semanticHash=e8187e8c16ff2e5a
scope.2.id=function:_set_action_button:38
scope.2.kind=function
scope.2.startLine=38
scope.2.endLine=49
scope.2.semanticHash=16d72b062f9702f3
scope.3.id=function:_store_target_button_labels:51
scope.3.kind=function
scope.3.startLine=51
scope.3.endLine=57
scope.3.semanticHash=777b337e22176953
scope.4.id=function:_sync_slot_label:59
scope.4.kind=function
scope.4.startLine=59
scope.4.endLine=72
scope.4.semanticHash=855adb364dfbcfa3
scope.5.id=function:_sync_projection_node:74
scope.5.kind=function
scope.5.startLine=74
scope.5.endLine=82
scope.5.semanticHash=616db41c911ce8ea
scope.6.id=function:_resolve_player_or_remote_options:117
scope.6.kind=function
scope.6.startLine=117
scope.6.endLine=122
scope.6.semanticHash=f17c6d4d50036915
scope.7.id=function:M.open_choice_modal:126
scope.7.kind=function
scope.7.startLine=126
scope.7.endLine=139
scope.7.semanticHash=bcd047b438de49ac
scope.8.id=function:M.open_secondary_confirm_screen:149
scope.8.kind=function
scope.8.startLine=149
scope.8.endLine=151
scope.8.semanticHash=0e59536342869284
scope.9.id=function:M.open_pre_confirm_screen:152
scope.9.kind=function
scope.9.startLine=152
scope.9.endLine=154
scope.9.semanticHash=ded3854126c5c48e
]]

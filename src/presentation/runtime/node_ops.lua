local runtime = require("src.presentation.runtime.ui")
local debug_nodes = require("src.presentation.schema.canvas.debug.nodes")
local player_choice_nodes = require("src.presentation.schema.canvas.player_choice.nodes")
local target_choice_nodes = require("src.presentation.schema.canvas.target_choice.nodes")
local remote_choice_nodes = require("src.presentation.schema.canvas.remote_choice.nodes")
local secondary_confirm_nodes = require("src.presentation.schema.canvas.secondary_confirm.nodes")
local always_show_contract = require("src.presentation.schema.canvas.always_show.contract")

local M = {}

local function query_node(name)
  return runtime.query_node(name)
end

local function mutate_node(name, mutator)
  assert(name ~= nil, "missing ui node name")
  assert(type(mutator) == "function", "missing node mutator")
  local active_role = runtime.get_client_role and runtime.get_client_role() or nil
  if active_role ~= nil then
    local node = query_node(name)
    mutator(node)
    return
  end
  runtime.for_each_role_or_global(function()
    local node = query_node(name)
    mutator(node)
  end)
end

local function set_text(_, name, text)
  mutate_node(name, function(node)
    node.text = text or ""
  end)
end

local function set_visible(_, name, visible)
  mutate_node(name, function(node)
    node.visible = visible == true
  end)
end

local function set_touch_enabled(_, name, enabled)
  mutate_node(name, function(node)
    node.disabled = not enabled
  end)
end

local function _resolve_target_screen(ui)
  if not ui then
    return nil
  end
  return ui.choice_screens and ui.choice_screens.target or nil
end

local function _is_target_choice_active(ui)
  return ui.choice_active == true and ui.active_choice_screen_key == "target"
end

local function _sync_target_button(ui, button_name, active, locked)
  if not button_name then
    return
  end
  ui:set_visible(button_name, active)
  ui:set_touch_enabled(button_name, active and locked == true)
end

local function sync_target_choice_buttons(state, locked)
  local ui = state and state.ui or nil
  local screen = _resolve_target_screen(ui)
  if not screen then
    return
  end
  local active = _is_target_choice_active(ui)
  _sync_target_button(ui, screen.confirm, active, locked)
  _sync_target_button(ui, screen.cancel, active, locked)
end

local function set_debug_log(_, text)
  set_text(nil, always_show_contract.action_log.label, text)
end

local function set_debug_visible(ui, visible)
  if ui then
    ui.debug_visible = visible == true
  end
  set_visible(nil, debug_nodes.canvas, visible)
end

local function set_item_slot_image(slot_name, image_key)
  assert(slot_name ~= nil, "missing slot name")
  assert(image_key ~= nil, "missing image key for slot: " .. tostring(slot_name))
  local active_role = runtime.get_client_role and runtime.get_client_role() or nil
  local function apply()
    local nodes = runtime.query_nodes(slot_name)
    for _, node in ipairs(nodes) do
      runtime.set_node_texture_keep_size(node, image_key)
    end
  end
  if active_role ~= nil then
    apply()
    return
  end
  runtime.for_each_role_or_global(function()
    apply()
  end)
end

local function build_choice_screens()
  return {
    player = {
      key = "player",
      root = player_choice_nodes.canvas,
      title = player_choice_nodes.title,
      option_buttons = player_choice_nodes.slots,
    },
    target = {
      key = "target",
      root = target_choice_nodes.canvas,
      title = target_choice_nodes.title,
      body = target_choice_nodes.body,
      option_buttons = target_choice_nodes.slot_buttons,
      slot_labels = target_choice_nodes.slot_labels,
      slot_projections = target_choice_nodes.slot_projections,
      confirm = target_choice_nodes.confirm,
      cancel = target_choice_nodes.cancel,
    },
    remote = {
      key = "remote",
      root = remote_choice_nodes.canvas,
      title = remote_choice_nodes.title,
      body = remote_choice_nodes.body,
      option_buttons = remote_choice_nodes.options,
    },
    secondary_confirm = {
      key = "secondary_confirm",
      root = secondary_confirm_nodes.canvas,
      title = secondary_confirm_nodes.title,
      body = secondary_confirm_nodes.body,
      confirm = secondary_confirm_nodes.confirm,
      cancel = secondary_confirm_nodes.cancel,
    },
  }
end

M.query_node = query_node
M.set_text = set_text
M.set_visible = set_visible
M.set_touch_enabled = set_touch_enabled
M.set_debug_log = set_debug_log
M.set_debug_visible = set_debug_visible
M.set_item_slot_image = set_item_slot_image
M.build_choice_screens = build_choice_screens
M.sync_target_choice_buttons = sync_target_choice_buttons

return M

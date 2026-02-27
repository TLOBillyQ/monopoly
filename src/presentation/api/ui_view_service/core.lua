local runtime = require("src.presentation.api.UIRuntimePort")
local ui_nodes = require("src.presentation.shared.UINodes")
local always_show_contract = require("src.presentation.canvas.always_show.contract")

local M = {}

local function query_node(name)
  return runtime.query_node(name)
end

local function set_text(_, name, text)
  local node = query_node(name)
  node.text = text or ""
end

local function set_visible(_, name, visible)
  local node = query_node(name)
  node.visible = visible == true
end

local function set_touch_enabled(_, name, enabled)
  local node = query_node(name)
  node.disabled = not enabled
end

local function set_debug_log(_, text)
  set_text(nil, always_show_contract.action_log.label, text)
end

local function set_debug_visible(ui, visible)
  if ui then
    ui.debug_visible = visible == true
  end
  set_visible(nil, ui_nodes.canvas.debug, visible)
end

local function set_item_slot_image(slot_name, image_key)
  assert(slot_name ~= nil, "missing slot name")
  assert(image_key ~= nil, "missing image key for slot: " .. tostring(slot_name))
  local nodes = runtime.query_nodes(slot_name)
  for _, node in ipairs(nodes) do
    runtime.set_node_texture_keep_size(node, image_key)
  end
end

local function build_choice_screens()
  return {
    player = {
      key = "player",
      root = ui_nodes.player_choice.canvas,
      title = ui_nodes.player_choice.title,
      option_buttons = ui_nodes.player_choice.slots,
    },
    target = {
      key = "target",
      root = ui_nodes.target_choice.canvas,
      title = ui_nodes.target_choice.title,
      body = ui_nodes.target_choice.body,
      option_buttons = ui_nodes.target_choice.slots,
      under_button = ui_nodes.target_choice.under,
    },
    remote = {
      key = "remote",
      root = ui_nodes.remote_choice.canvas,
      title = ui_nodes.remote_choice.title,
      body = ui_nodes.remote_choice.body,
      option_buttons = ui_nodes.remote_choice.options,
      cancel = ui_nodes.remote_choice.cancel,
    },
    building = {
      key = "building",
      root = ui_nodes.building_choice.canvas,
      title = ui_nodes.building_choice.title,
      body = ui_nodes.building_choice.body,
      confirm = ui_nodes.building_choice.confirm,
      cancel = ui_nodes.building_choice.cancel,
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

return M

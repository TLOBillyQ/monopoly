local runtime = require("src.presentation.api.UIRuntimePort")
local ui_nodes = require("src.presentation.shared.UINodes")

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
  set_text(nil, ui_nodes.action_log.log_label, text)
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
      root = ui_nodes.choice.player.root,
      title = ui_nodes.choice.player.title,
      body = ui_nodes.choice.player.body,
      option_buttons = ui_nodes.choice.player.slots,
      cancel = ui_nodes.choice.player.cancel,
    },
    target = {
      key = "target",
      root = ui_nodes.choice.target.root,
      title = ui_nodes.choice.target.title,
      body = ui_nodes.choice.target.body,
      option_buttons = ui_nodes.choice.target.slots,
      under_button = ui_nodes.choice.target.under,
      cancel = ui_nodes.choice.target.cancel,
    },
    remote = {
      key = "remote",
      root = ui_nodes.choice.remote.root,
      title = ui_nodes.choice.remote.title,
      body = ui_nodes.choice.remote.body,
      option_buttons = ui_nodes.choice.remote.options,
      cancel = ui_nodes.choice.remote.cancel,
    },
    building = {
      key = "building",
      root = ui_nodes.choice.building.root,
      title = ui_nodes.choice.building.title,
      body = ui_nodes.choice.building.body,
      confirm = ui_nodes.choice.building.confirm,
      cancel = ui_nodes.choice.building.cancel,
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

local runtime = require("src.presentation.api.UIRuntimePort")
local debug_nodes = require("src.presentation.canvas.debug.nodes")
local player_choice_nodes = require("src.presentation.canvas.player_choice.nodes")
local target_choice_nodes = require("src.presentation.canvas.target_choice.nodes")
local remote_choice_nodes = require("src.presentation.canvas.remote_choice.nodes")
local secondary_confirm_nodes = require("src.presentation.canvas.secondary_confirm.nodes")
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
  set_visible(nil, debug_nodes.canvas, visible)
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
      root = player_choice_nodes.canvas,
      title = player_choice_nodes.title,
      option_buttons = player_choice_nodes.slots,
    },
    target = {
      key = "target",
      root = target_choice_nodes.canvas,
      title = target_choice_nodes.title,
      body = target_choice_nodes.body,
      option_buttons = target_choice_nodes.slots,
      under_button = target_choice_nodes.under,
    },
    remote = {
      key = "remote",
      root = remote_choice_nodes.canvas,
      title = remote_choice_nodes.title,
      body = remote_choice_nodes.body,
      option_buttons = remote_choice_nodes.options,
      cancel = remote_choice_nodes.cancel,
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

return M

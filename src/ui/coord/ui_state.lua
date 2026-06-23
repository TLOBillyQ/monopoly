local base_nodes = require("src.ui.schema.base")
local popup_nodes = require("src.ui.schema.popup")
local bankruptcy_nodes = require("src.ui.schema.bankruptcy")
local permanent_nodes = require("src.ui.schema.permanent")
local ui_nodes = require("src.ui.render.node_ops")
local base_contract = require("src.ui.schema.base_contract")
local canvas_store = require("src.ui.state.canvas_store")

local M = {}

function M.build_ui_state()
  local item_slots = permanent_nodes.item_slots
  local card_outlines = permanent_nodes.card_outlines
  local base_hidden_nodes = {
    base_nodes.action_button,
    base_nodes.end_button,
    base_nodes.skin_button,
    base_nodes.skin_label,
  }
  for _, name in ipairs(item_slots) do
    table.insert(base_hidden_nodes, name)
  end
  local choice_screens = ui_nodes.build_choice_screens()
  local popup_screen = {
    root = popup_nodes.canvas,
    title = popup_nodes.title,
    card = popup_nodes.card,
    dismiss_nodes = popup_nodes.dismiss_nodes,
  }
  local bankruptcy_screen = {
    root = bankruptcy_nodes.canvas,
    text = bankruptcy_nodes.text,
    avatar = bankruptcy_nodes.avatar,
  }
  local auto_control_nodes = { base_nodes.auto_button, base_nodes.auto_label }
  local canvas_state = {
    base = {
      hidden_nodes = base_hidden_nodes,
      hidden_labels = {},
      auto_control_nodes = auto_control_nodes,
      action_log = {
        toggle_targets = base_contract.action_log.toggle_targets,
      },
    },
    permanent = {
      item_slots = item_slots,
      card_outlines = card_outlines,
    },
    choice = {
      screens = choice_screens,
    },
    popup = {
      screen = popup_screen,
    },
    bankruptcy = {
      screen = bankruptcy_screen,
    },
  }
  local ui_state = {
    canvas_state = canvas_state,
    auto_play = false,
    auto_interval = 0.1,
    input_blocked = false,
    role_control_lock = { by_role = {} },
    role_control_lock_exempt_by_role = {},
    role_control_lock_exempt_count_by_role = {},
    debug_visible_by_role = {},
    debug_log_enabled_by_role = {},
    anim_debug_enabled_by_role = {},
    item_slots = canvas_state.permanent.item_slots,
    card_outlines = canvas_state.permanent.card_outlines,
    base_hidden_nodes = canvas_state.base.hidden_nodes,
    base_hidden_labels = {},
    auto_control_nodes = canvas_state.base.auto_control_nodes,
    market_active = false,
    choice_active = false,
    popup_active = false,
    move_active = false,
    active_choice_screen_key = nil,
    choice_screens = canvas_state.choice.screens,
    popup_screen = canvas_state.popup.screen,
    bankruptcy_screen = canvas_state.bankruptcy.screen,
    popup_kind = nil,
    popup_seq = 0,
    popup_return_canvas = nil,
    item_slot_item_ids_by_role = {},
    query_node = ui_nodes.query_node,
    set_label = ui_nodes.set_text,
    set_button = ui_nodes.set_text,
    set_visible = ui_nodes.set_visible,
    set_touch_enabled = ui_nodes.set_touch_enabled,
    set_event_log = ui_nodes.set_event_log,
    set_event_log_visible = ui_nodes.set_event_log_visible,
  }
  canvas_store.ensure(ui_state)
  return ui_state
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=e0bcab1847c8e6e1
scope.0.id=chunk:src/ui/coord/ui_state.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=100
scope.0.semanticHash=c0e31d38d01c1e72
scope.0.lastMutatedAt=2026-06-23T03:22:59Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=11
scope.0.lastMutationKilled=11
]]

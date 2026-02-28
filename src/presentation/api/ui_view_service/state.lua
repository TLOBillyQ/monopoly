local ui_nodes = require("src.presentation.shared.UINodes")
local core = require("src.presentation.api.ui_view_service.core")
local always_show_contract = require("src.presentation.canvas.always_show.contract")
local canvas_store = require("src.presentation.canvas_runtime.CanvasStore")

local M = {}

function M.build_ui_state()
  local item_slots = ui_nodes.base.item_slots
  local card_outlines = ui_nodes.base.card_outlines
  local base_hidden_nodes = { ui_nodes.base.action_button }
  for _, name in ipairs(item_slots) do
    table.insert(base_hidden_nodes, name)
  end
  local choice_screens = core.build_choice_screens()
  local popup_screen = {
    root = ui_nodes.popup.canvas,
    title = ui_nodes.popup.title,
    card = ui_nodes.popup.card,
    dismiss_nodes = ui_nodes.popup.dismiss_nodes,
  }
  local bankruptcy_screen = {
    root = ui_nodes.bankruptcy.canvas,
    text = ui_nodes.bankruptcy.text,
    avatar = ui_nodes.bankruptcy.avatar,
  }
  local auto_control_nodes = { ui_nodes.always_show.auto_button, ui_nodes.always_show.auto_label }
  local canvas_state = {
    base = {
      item_slots = item_slots,
      card_outlines = card_outlines,
      hidden_nodes = base_hidden_nodes,
      hidden_labels = {},
    },
    always_show = {
      auto_control_nodes = auto_control_nodes,
      action_log = {
        toggle_targets = always_show_contract.action_log.toggle_targets,
      },
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
    local_actor_role_id = nil,
    auto_play = false,
    auto_interval = 0.1,
    input_blocked = false,
    role_control_lock = { by_role = {}, warn_once = {} },
    role_control_lock_exempt_by_role = {},
    role_control_lock_exempt_count_by_role = {},
    debug_visible = false,
    debug_visible_by_role = {},
    debug_log_enabled_override = nil,
    debug_log_enabled_by_role = {},
    item_slots = canvas_state.base.item_slots,
    card_outlines = canvas_state.base.card_outlines,
    base_hidden_nodes = canvas_state.base.hidden_nodes,
    base_hidden_labels = {},
    auto_control_nodes = canvas_state.always_show.auto_control_nodes,
    market_active = false,
    choice_active = false,
    active_choice_screen_key = nil,
    choice_screens = canvas_state.choice.screens,
    popup_screen = canvas_state.popup.screen,
    bankruptcy_screen = canvas_state.bankruptcy.screen,
    popup_kind = nil,
    popup_seq = 0,
    popup_return_canvas = nil,
    item_slot_item_ids_by_role = {},
    query_node = core.query_node,
    set_label = core.set_text,
    set_button = core.set_text,
    set_visible = core.set_visible,
    set_touch_enabled = core.set_touch_enabled,
    set_debug_log = core.set_debug_log,
    set_debug_visible = core.set_debug_visible,
  }
  canvas_store.ensure(ui_state)
  return ui_state
end

return M

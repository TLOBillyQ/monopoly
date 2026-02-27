local ui_nodes = require("src.presentation.shared.UINodes")
local core = require("src.presentation.api.ui_view_service.core")

local M = {}

function M.build_ui_state()
  local item_slots = ui_nodes.base.item_slots
  local base_hidden_nodes = { ui_nodes.base.action_button }
  for _, name in ipairs(item_slots) do
    table.insert(base_hidden_nodes, name)
  end
  return {
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
    item_slots = item_slots,
    base_hidden_nodes = base_hidden_nodes,
    base_hidden_labels = {},
    auto_control_nodes = { ui_nodes.always_show.auto_button, ui_nodes.always_show.auto_label },
    market_active = false,
    choice_active = false,
    active_choice_screen_key = nil,
    choice_screens = core.build_choice_screens(),
    popup_screen = {
      root = ui_nodes.popup.canvas,
      title = ui_nodes.popup.title,
      card = ui_nodes.popup.card,
      dismiss_nodes = ui_nodes.popup.dismiss_nodes,
    },
    bankruptcy_screen = {
      root = ui_nodes.bankruptcy.canvas,
      text = ui_nodes.bankruptcy.text,
      avatar = ui_nodes.bankruptcy.avatar,
    },
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
end

return M

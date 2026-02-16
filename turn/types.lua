local port_types = {}

port_types.groups = {
  modal = {
    "close_choice_modal",
    "open_choice_modal",
    "close_popup",
  },
  anim = {
    "play_move_anim",
    "play_action_anim",
    "reset_status_3d",
    "sync_status_3d",
  },
  ui_sync = {
    "apply_input_lock",
    "step_choice_timeout",
    "step_modal_timeout",
    "update_countdown",
    "build_model",
    "refresh_from_dirty",
    "get_ui_state",
    "is_input_blocked",
    "is_popup_active",
    "is_choice_active",
    "is_market_active",
    "get_popup_owner_index",
    "set_input_blocked",
  },
  debug = {
    "log_status",
    "sync_debug_log",
    "resolve_debug_enabled",
  },
  state = {
    "apply_role_control_lock",
    "install_event_handlers",
    "on_bankruptcy_tiles_cleared",
  },
}

port_types.group_names = {
  "modal",
  "anim",
  "ui_sync",
  "debug",
  "state",
}

return port_types

local port_types = {}

port_types.keys = {
  "close_choice_modal",
  "open_choice_modal",
  "close_popup",
  "apply_input_lock",
  "apply_role_control_lock",
  "play_move_anim",
  "play_action_anim",
  "step_choice_timeout",
  "step_modal_timeout",
  "update_countdown",
  "build_model",
  "refresh_from_dirty",
  "log_status",
  "sync_debug_log",
  "reset_status_3d",
  "sync_status_3d",
  "install_event_handlers",
  "on_bankruptcy_tiles_cleared",
  "get_ui_state",
  "is_input_blocked",
  "is_popup_active",
  "is_choice_active",
  "is_market_active",
  "get_popup_owner_index",
  "set_input_blocked",
}

return port_types

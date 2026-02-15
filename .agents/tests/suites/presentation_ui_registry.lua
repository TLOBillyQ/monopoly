local names = {
  "_test_move_anim_callback_and_delay",
  "_test_popup_timeout_auto_confirm",
  "_test_runtime_port_with_client_role_restores_nested_context",
  "_test_choice_timeout_supports_explicit_timeout_strategy",
  "_test_tick_timeout_default_policy_isolation",
  "_test_invalid_choice_option_rejected",
  "_test_move_anim_wait_and_resume",
  "_test_move_anim_zero_distance_safe",
  "_test_move_anim_step_unlocks_and_relocks",
  "_test_move_anim_vehicle_uses_set_position_jump",
  "_test_move_anim_vehicle_enter_delay_once",
  "_test_move_anim_vehicle_move_api_enabled_uses_move_event",
  "_test_board_view_vehicle_resync_uses_set_position",
  "_test_board_view_vehicle_disabled_uses_unit_set_position",
  "_test_ui_model_structure",
  "_test_ui_panel_clamps_negative_assets_to_zero",
  "_test_ui_model_player_slot_map_and_choice_owner",
  "_test_ui_model_player_profile_prefers_role_api_with_fallback",
  "_test_ui_model_player_profile_accepts_stringified_avatar",
  "_test_turn_dispatch_rejects_non_current_actor",
  "_test_turn_dispatch_rejects_choice_non_owner",
  "_test_turn_dispatch_auto_rejects_unmapped_role",
  "_test_turn_dispatch_item_slot_uses_actor_slot_map",
  "_test_ui_intent_dispatcher_market_confirm_routes_choice_select",
  "_test_ui_intent_dispatcher_market_select_updates_ui_only",
  "_test_ui_intent_dispatcher_popup_confirm_closes_popup",
  "_test_ui_intent_dispatcher_toggle_action_log_uses_actor_role_context",
  "_test_ui_view_render_by_role_slots_are_isolated",
  "_test_ui_events_send_without_roles_no_crash",
  "_test_ui_nodes_validate_reports_missing",
  "_test_apply_input_lock_keeps_auto_controls_enabled",
  "_test_apply_input_lock_keeps_auto_button_enabled_when_role_unmapped",
  "_test_ui_touch_policy_auto_controls_touch",
  "_test_ui_touch_policy_runtime_nodes_touch_enabled",
  "_test_role_control_lock_add_remove_owned_only",
  "_test_role_control_lock_unit_swap_release_old_and_lock_new",
  "_test_gameplay_loop_full_turn_lock_toggle",
  "_test_push_popup_sets_card_image_by_image_ref",
  "_test_push_popup_hides_card_and_clears_image_when_missing",
  "_test_popup_hidden_for_non_current_role",
  "_test_popup_visible_for_all_roles_when_allowed_kind",
  "_test_bankruptcy_popup_visible_for_all_roles",
  "_test_popup_timeout_closes_even_when_input_blocked",
  "_test_choice_modal_routes_to_new_screens",
  "_test_ui_event_router_player_target_click_direct_submit",
  "_test_ui_event_router_action_log_toggle_uses_role_context",
  "_test_market_selection_updates_icon_without_resize",
  "_test_market_close_resets_icon_without_resize",
  "_test_item_slot_uses_keep_size_path",
  "_test_tick_skips_anim_when_no_anim",
  "_test_action_anim_queue_consumes_in_order",
  "_test_action_anim_default_duration",
  "_test_action_anim_no_camera_focus_side_effect",
  "_test_status3d_init_and_global_visibility",
  "_test_status3d_priority_single_status",
  "_test_status3d_roadblock_only_current_turn",
  "_test_status3d_reset_destroy_layers",
  "_test_tick_ui_sync_turn_switch_still_follows",
}

local function slice(suite_name, first_index, last_index)
  local all = require("presentation_ui")
  local selected = {}
  for index = first_index, last_index do
    local run = all[index]
    assert(type(run) == "function", "missing presentation_ui test at index " .. tostring(index))
    selected[#selected + 1] = {
      name = names[index] or ("presentation_ui_test_" .. tostring(index)),
      run = run,
    }
  end
  return {
    name = suite_name,
    tests = selected,
  }
end

return {
  slice = slice,
}

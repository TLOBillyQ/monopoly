local names = {
  -- timing_anim: 1-14
  "_test_move_anim_callback_and_delay",                                       -- 1
  "_test_popup_timeout_auto_confirm",                                         -- 2
  "_test_runtime_port_with_client_role_restores_nested_context",              -- 3
  "_test_runtime_port_native_size_prefers_native_method",                     -- 4
  "_test_runtime_port_native_size_fallback_keep_size",                        -- 5
  "_test_runtime_port_native_size_fallback_image_texture",                    -- 6
  "_test_choice_timeout_supports_explicit_timeout_strategy",                  -- 7
  "_test_tick_timeout_default_policy_isolation",                              -- 8
  "_test_invalid_choice_option_rejected",                                     -- 9
  "_test_move_anim_wait_and_resume",                                          -- 10
  "_test_move_anim_zero_distance_safe",                                       -- 11
  "_test_move_anim_step_unlocks_and_relocks",                                 -- 12
  "_test_move_anim_vehicle_uses_set_position_jump",                           -- 13
  "_test_move_anim_vehicle_enter_delay_once",                                 -- 14
  -- model_dispatch: 15-27
  "_test_move_anim_vehicle_move_api_enabled_uses_move_event",                 -- 15
  "_test_board_view_vehicle_resync_uses_set_position",                        -- 16
  "_test_board_view_vehicle_disabled_uses_unit_set_position",                 -- 17
  "_test_ui_model_structure",                                                 -- 18
  "_test_ui_panel_clamps_negative_assets_to_zero",                            -- 19
  "_test_ui_model_player_slot_map_and_choice_owner",                          -- 20
  "_test_ui_model_player_profile_prefers_role_api_with_fallback",             -- 21
  "_test_ui_model_player_profile_accepts_stringified_avatar",                 -- 22
  "_test_turn_dispatch_rejects_non_current_actor",                            -- 23
  "_test_turn_dispatch_rejects_choice_non_owner",                             -- 24
  "_test_turn_dispatch_auto_rejects_unmapped_role",                           -- 25
  "_test_turn_dispatch_item_slot_uses_actor_slot_map",                        -- 26
  "_test_ui_intent_dispatcher_market_confirm_routes_choice_select",           -- 27
  -- interaction: 28-37
  "_test_ui_intent_dispatcher_market_select_updates_ui_only",                 -- 28
  "_test_ui_intent_dispatcher_popup_confirm_closes_popup",                    -- 29
  "_test_ui_intent_dispatcher_toggle_action_log_uses_actor_role_context",     -- 30
  "_test_ui_intent_dispatcher_toggle_action_log_ignores_block_without_game",  -- 31
  "_test_ui_intent_dispatcher_toggle_action_log_resolves_role_via_game_api",  -- 32
  "_test_ui_intent_dispatcher_toggle_action_log_warns_when_role_event_channel_missing", -- 33
  "_test_ui_intent_dispatcher_auto_button_forces_local_role_id",              -- 34
  "_test_ui_intent_dispatcher_auto_button_falls_back_to_intent_actor_when_local_missing", -- 35
  "_test_ui_intent_dispatcher_auto_button_toggles_local_role_during_other_turn", -- 36
  "_test_ui_view_render_by_role_slots_are_isolated",                          -- 37
  -- popup_market: 38-53
  "_test_ui_events_send_without_roles_no_crash",                              -- 38
  "_test_ui_nodes_validate_reports_missing",                                  -- 39
  "_test_apply_input_lock_keeps_auto_controls_enabled",                       -- 40
  "_test_apply_input_lock_keeps_auto_button_enabled_when_role_unmapped",      -- 41
  "_test_ui_view_render_auto_button_keeps_local_touch_when_unmapped_role_exists", -- 42
  "_test_ui_touch_policy_auto_controls_touch",                                -- 43
  "_test_ui_touch_policy_runtime_nodes_touch_enabled",                        -- 44
  "_test_role_control_lock_add_remove_owned_only",                            -- 45
  "_test_role_control_lock_unit_swap_release_old_and_lock_new",               -- 46
  "_test_gameplay_loop_full_turn_lock_toggle",                                -- 47
  "_test_push_popup_sets_card_image_by_image_ref",                            -- 48
  "_test_push_popup_hides_card_and_clears_image_when_missing",                -- 49
  "_test_popup_hidden_for_non_current_role",                                  -- 50
  "_test_popup_visible_for_all_roles_when_allowed_kind",                      -- 51
  "_test_bankruptcy_popup_visible_for_all_roles",                             -- 52
  "_test_bankruptcy_popup_avatar_uses_native_size_path",                      -- 53
  -- action_status: 54-81
  "_test_popup_timeout_closes_even_when_input_blocked",                       -- 54
  "_test_choice_modal_routes_to_new_screens",                                 -- 55
  "_test_choice_route_policy_prefers_explicit_route_metadata",                -- 56
  "_test_ui_event_router_player_target_click_direct_submit",                  -- 57
  "_test_ui_event_router_action_log_toggle_uses_role_context",                -- 58
  "_test_market_selection_updates_icon_without_resize",                       -- 59
  "_test_market_close_resets_icon_without_resize",                            -- 60
  "_test_item_slot_uses_keep_size_path",                                      -- 61
  "_test_item_slot_refresh_shows_only_playable_outlines",                     -- 62
  "_test_item_slot_intents_include_outline_nodes",                            -- 63
  "_test_tick_skips_anim_when_no_anim",                                       -- 64
  "_test_action_anim_queue_consumes_in_order",                                -- 65
  "_test_action_anim_default_duration",                                       -- 66
  "_test_action_anim_no_camera_focus_side_effect",                            -- 67
  "_test_status3d_init_and_global_visibility",                                -- 68
  "_test_status3d_priority_single_status",                                    -- 69
  "_test_status3d_roadblock_only_current_turn",                               -- 70
  "_test_status3d_reset_destroy_layers",                                      -- 71
  "_test_turn_effects_prompt_visibility_follows_phase_and_role",              -- 72
  "_test_turn_effects_other_prompt_fallback_text",                            -- 73
  "_test_tick_ui_sync_turn_switch_still_follows",                             -- 74
  "_test_tick_ui_sync_turn_switch_skip_follow_when_trigger_unavailable",      -- 75
  "_test_ui_sync_defers_choice_modal_during_wait_action_anim",                -- 76
  "_test_ui_sync_opens_choice_modal_after_wait_action_anim",                  -- 77
  "_test_ui_sync_defers_choice_modal_during_wait_move_anim",                  -- 78
  "_test_popup_defer_policy_queues_and_replays_in_order",                     -- 79
  "_test_panel_avatar_uses_keep_size_path",                                   -- 80
  "_test_item_slot_refresh_resets_highlight_without_client_role",             -- 81
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

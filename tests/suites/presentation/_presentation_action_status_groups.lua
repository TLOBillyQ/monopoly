local case_modules = {
  require("suites.presentation._presentation_action_status_choice_and_target_cases"),
  require("suites.presentation._presentation_action_status_market_and_anim_cases"),
  require("suites.presentation._presentation_action_status_status3d_and_panel_cases"),
}

local suite_names = {
  choice_routes = "presentation_choice_routes",
  target_pick = "presentation_target_pick",
  action_log_and_role_context = "presentation_action_log_and_role_context",
  market_panel = "presentation_market_panel",
  item_slots = "presentation_item_slots",
  action_anim_queue_and_turn_lock = "presentation_action_anim_queue_and_turn_lock",
  status3d_and_turn_effects = "presentation_status3d_and_turn_effects",
  popup_and_modal_renderers = "presentation_popup_and_modal_renderers",
  player_panels = "presentation_player_panels",
}

local case_groups = {
  choice_routes = {
    "_test_choice_modal_routes_to_new_screens",
    "_test_choice_route_policy_prefers_explicit_route_metadata",
    "_test_secondary_confirm_copy_item_phase_selected_option",
    "_test_secondary_confirm_copy_land_actions",
    "_test_secondary_confirm_copy_generic_pre_confirm",
    "_test_secondary_confirm_prefers_usecase_confirm_copy",
  },
  target_pick = {
    "_test_target_screen_uses_labels_only_and_hides_projection_with_slots",
    "_test_target_screen_hides_unused_slots_when_unique_options_less_than_seven",
    "_test_target_confirm_dispatches_selected_option",
    "_test_target_pick_tick_updates_selection_on_hit_change",
    "_test_target_pick_tick_ignores_non_candidate",
    "_test_target_pick_scene_click_locks_target_and_pauses_raycast",
    "_test_target_pick_confirm_requires_lock",
    "_test_target_pick_cancel_unlocks_and_resumes_raycast",
    "_test_target_pick_cancel_noop_when_unlocked",
    "_test_target_pick_leave_hides_scene_units",
    "_test_target_pick_enter_spawns_candidate_markers_at_height_1_6",
    "_test_target_pick_degrades_without_raycast_api",
    "_test_ui_event_router_player_target_click_direct_submit",
    "_test_target_pick_prefers_explicit_owner_role_id",
  },
  action_log_and_role_context = {
    "_test_ui_event_router_action_log_toggle_uses_role_context",
    "_test_ui_event_router_rejects_action_log_without_role",
    "_test_ui_event_router_action_log_uses_cached_local_role_when_event_role_missing",
    "_test_ui_event_router_auto_uses_cached_local_role_instead_of_current_player",
    "_test_ui_event_state_resolve_debug_enabled_supports_mixed_role_id_keys",
  },
  market_panel = {
    "_test_market_selection_updates_icon_without_resize",
    "_test_market_close_resets_icon_without_resize",
    "_test_market_view_default_selection_shows_matching_selection_frame",
    "_test_market_select_switches_selection_frame",
    "_test_market_view_empty_filtered_tab_hides_selection_frames",
    "_test_market_view_refresh_retargets_selection_frame_on_page_change",
    "_test_market_view_hides_market_disabled_entries",
    "_test_market_view_unbuyable_option_is_clickable",
    "_test_market_view_hides_disabled_market_tab",
    "_test_market_view_invalid_selected_option_falls_back_to_current_visible_option",
    "_test_market_view_page_arrows_visibility_follows_page_count",
    "_test_ui_model_market_payload_prefers_explicit_choice_fields",
    "_test_modal_presenter_market_same_choice_id_still_refreshes_market_panel",
    "_test_ui_event_router_market_cancel_button_dispatches_choice_cancel",
  },
  item_slots = {
    "_test_item_slot_uses_keep_size_path",
    "_test_item_slot_refresh_shows_only_playable_outlines",
    "_test_item_slot_intents_include_outline_nodes",
    "_test_item_phase_ask_confirm_clears_highlight_suppress",
    "_test_item_phase_ask_single_option_pre_confirm_dispatches_choice_select",
    "_test_item_phase_confirmed_skips_replay_before_slot_click",
    "_test_item_slot_refresh_item_phase_ask_replays_highlight_then_reveals_outlines",
    "_test_item_slot_refresh_resets_highlight_without_client_role",
  },
  action_anim_queue_and_turn_lock = {
    "_test_tick_skips_anim_when_no_anim",
    "_test_action_anim_queue_consumes_in_order",
    "_test_action_anim_default_duration",
    "_test_action_anim_no_camera_focus_side_effect",
    "_test_ui_sync_defers_choice_modal_during_wait_action_anim",
    "_test_ui_sync_opens_choice_modal_after_wait_action_anim",
    "_test_ui_sync_defers_choice_modal_during_wait_move_anim",
    "_test_role_control_lock_add_remove_owned_only",
    "_test_role_control_lock_unit_swap_release_old_and_lock_new",
    "_test_gameplay_loop_full_turn_lock_toggle",
  },
  status3d_and_turn_effects = {
    "_test_status3d_init_and_global_visibility",
    "_test_status3d_priority_single_status",
    "_test_status3d_roadblock_only_current_turn",
    "_test_status3d_hospital_visible_when_no_action_notice_even_if_stay_turns_zero",
    "_test_status3d_mountain_visible_when_no_action_notice_even_if_stay_turns_zero",
    "_test_status3d_hospital_mountain_not_visible_when_not_detained_and_stay_turns_zero",
    "_test_status3d_reset_destroy_layers",
    "_test_turn_effects_prompt_visibility_follows_phase_and_role",
    "_test_turn_effects_other_prompt_fallback_text",
    "_test_turn_effects_sync_restores_client_role_nil",
    "_test_tick_ui_sync_turn_switch_still_follows",
    "_test_tick_ui_sync_turn_switch_skip_follow_when_trigger_unavailable",
    "_test_ui_sync_refresh_from_dirty_renders_board_with_fix32_ai_stop",
  },
  popup_and_modal_renderers = {
    "_test_popup_timeout_closes_even_when_input_blocked",
    "_test_popup_defer_policy_queues_and_replays_in_order",
    "_test_popup_renderer_switch_popup_canvas_restores_client_role_nil",
    "_test_market_modal_renderer_open_restores_client_role_nil",
    "_test_debug_ports_sync_restores_client_role_nil",
  },
  player_panels = {
    "_test_panel_avatar_uses_native_size_path",
    "_test_panel_cash_delta_shows_negative_and_auto_hides",
    "_test_panel_cash_delta_shows_positive_and_auto_hides",
    "_test_panel_cash_delta_keeps_latest_when_changes_are_continuous",
    "_test_panel_cash_delta_hides_when_value_unchanged",
    "_test_panel_cash_delta_missing_node_is_safe",
    "_test_panel_crown_shows_for_top_total_assets_and_ties",
    "_test_panel_crown_excludes_eliminated_players",
  },
}

local case_overrides = {
  _test_status3d_priority_single_status = {
    disabled_in = {
      release_trimmed = true,
    },
  },
}

local case_index = {}

local function _clone_table(value)
  local clone = {}
  for key, entry in pairs(value or {}) do
    clone[key] = entry
  end
  return clone
end

local function _clone_case(test)
  local clone = {}
  for key, value in pairs(test or {}) do
    clone[key] = value
  end
  clone.disabled_in = _clone_table(clone.disabled_in)
  clone.tags = _clone_table(clone.tags)
  return clone
end

for _, cases in ipairs(case_modules) do
  for _, test in ipairs(cases) do
    local case_name = test and test.name or nil
    assert(case_name ~= nil, "action_status case missing name")
    assert(case_index[case_name] == nil, "duplicate action_status case: " .. tostring(case_name))
    case_index[case_name] = test
  end
end

local function _build_case(case_name)
  local test = assert(case_index[case_name], "missing action_status case: " .. tostring(case_name))
  local cloned = _clone_case(test)
  local override = case_overrides[case_name]
  if override then
    if override.disabled_in then
      local disabled_in = cloned.disabled_in
      for mode, value in pairs(override.disabled_in) do
        disabled_in[mode] = value
      end
    end
  end
  return cloned
end

local M = {}

function M.build_suite(group_key)
  local suite_name = assert(suite_names[group_key], "unknown action_status suite: " .. tostring(group_key))
  local tests = {}
  for _, case_name in ipairs(assert(case_groups[group_key], "missing action_status group: " .. tostring(group_key))) do
    tests[#tests + 1] = _build_case(case_name)
  end
  return {
    name = suite_name,
    tests = tests,
  }
end

return M

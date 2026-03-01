local names = {
  -- core: 1-8
  "_test_mandatory_payment_causes_bankruptcy",                                -- 1
  "_test_bankruptcy_resets_owned_tiles",                                       -- 2
  "_test_bankruptcy_notifier_reads_grouped_ports",                            -- 3
  "_test_chance_pay_others_stops_after_bankruptcy",                           -- 4
  "_test_set_tile_owner_without_ui_port_does_not_crash",                      -- 5
  "_test_tile_owner_notifier_receives_owner_changes",                         -- 6
  "_test_dispatch_validator_accepts_ui_state_snapshot",                        -- 7
  "_test_intent_dispatcher_sets_choice_route_metadata",                       -- 8
  -- runtime: 9-16
  "_test_stop_all_players_movement_clears_move_dir_and_stop_event",           -- 9
  "_test_end_turn_stops_all_players_movement",                                -- 10
  "_test_stop_all_players_movement_skips_invalid_role_without_error",         -- 11
  "_test_runtime_context_get_vehicle_player_no_fallback",                     -- 12
  "_test_runtime_context_forward_stop_skips_invalid_role",                    -- 13
  "_test_runtime_context_split_install_stages",                               -- 14
  "_test_runtime_context_install_helpers_without_globals",                    -- 15
  "_test_runtime_context_install_environment_fails_fast",                     -- 16
  -- loop: 17-41
  "_test_game_startup_build_state_is_pure_and_bridge_installs_events",        -- 17
  "_test_set_player_seat_emits_exit_then_enter",                              -- 18
  "_test_mine_destroy_vehicle_emits_exit_event",                              -- 19
  "_test_vehicle_feature_disabled_ignores_seat_bonus",                        -- 20
  "_test_turn_move_anim_omits_vehicle_id_when_disabled",                      -- 21
  "_test_autorunner_runs_to_end",                                             -- 22
  "_test_complex_consecutive_turn_settlement",                                -- 23
  "_test_complex_market_interrupt_with_rent",                                 -- 24
  "_test_tick_headless_ports_cover_anim_phases",                              -- 25
  "_test_action_button_timeout_auto_advances",                                -- 26
  "_test_action_button_timeout_blocked_when_input_locked",                    -- 27
  "_test_action_button_timeout_blocked_when_popup_active",                    -- 28
  "_test_auto_runner_auto_advances_ai_player",                                -- 29
  "_test_auto_runner_human_turn_not_auto_advanced",                           -- 30
  "_test_auto_runner_not_advanced_when_input_blocked",                        -- 31
  "_test_auto_runner_depends_on_current_player_auto",                         -- 32
  "_test_turn_prompt_initialized_for_first_player",                           -- 33
  "_test_turn_prompt_emitted_on_next_player_switch",                          -- 34
  "_test_turn_dispatch_uses_clock_ports_without_game_api",                    -- 35
  "_test_gameplay_loop_set_game_uses_runtime_ui_port_dto",                    -- 36
  "_test_gameplay_loop_refresh_drives_camera_follow_via_port",                -- 37
  "_test_gameplay_loop_clock_ports_split_wall_and_cpu_semantics",             -- 38
  "_test_choice_auto_policy_consistent_between_wait_and_timeout",             -- 39
  "_test_popup_countdown_uses_effective_modal_timeout",                       -- 40
  "_test_dispatch_gate_blocks_next_when_choice_active",                       -- 41
}

local function slice(suite_name, first_index, last_index)
  local all = require("gameplay")
  local selected = {}
  for index = first_index, last_index do
    local run = all[index]
    assert(type(run) == "function", "missing gameplay test at index " .. tostring(index))
    selected[#selected + 1] = {
      name = names[index] or ("gameplay_test_" .. tostring(index)),
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

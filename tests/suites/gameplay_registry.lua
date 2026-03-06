local names = {
  -- core: 1-8
  "_test_mandatory_payment_causes_bankruptcy",                                -- 1
  "_test_bankruptcy_resets_owned_tiles",                                       -- 2
  "_test_bankruptcy_notifier_reads_grouped_ports",                            -- 3
  "_test_chance_pay_others_stops_after_bankruptcy",                           -- 4
  "_test_set_tile_owner_without_ui_port_does_not_crash",                      -- 5
  "_test_tile_owner_notifier_receives_owner_changes",                         -- 6
  "_test_dispatch_validator_accepts_ui_state_snapshot",                       -- 7
  "_test_intent_dispatcher_sets_choice_route_metadata",                       -- 8
  -- runtime: 9-13
  "_test_intent_dispatcher_sets_choice_route_metadata",                       -- 9
  "_test_runtime_event_bridge_detects_unbound_binding_without_call",          -- 10
  "_test_runtime_context_split_install_stages",                               -- 11
  "_test_runtime_context_install_helpers_without_globals",                    -- 12
  "_test_runtime_context_install_environment_fails_fast",                     -- 13
  -- loop: 14-39
  "_test_game_startup_build_state_is_pure_and_bridge_installs_events",        -- 14
  "_test_autorunner_runs_to_end",                                             -- 15
  "_test_complex_consecutive_turn_settlement",                                -- 16
  "_test_complex_market_interrupt_with_rent",                                 -- 17
  "_test_tick_headless_ports_cover_anim_phases",                              -- 18
  "_test_action_button_timeout_auto_advances",                                -- 19
  "_test_action_button_timeout_blocked_when_input_locked",                    -- 20
  "_test_action_button_timeout_blocked_when_popup_active",                    -- 21
  "_test_auto_runner_auto_advances_ai_player",                                -- 22
  "_test_auto_runner_human_turn_not_auto_advanced",                           -- 23
  "_test_auto_runner_not_advanced_when_input_blocked",                        -- 24
  "_test_auto_runner_depends_on_current_player_auto",                         -- 25
  "_test_turn_prompt_initialized_for_first_player",                           -- 26
  "_test_turn_prompt_emitted_on_next_player_switch",                          -- 27
  "_test_turn_dispatch_uses_clock_ports_without_game_api",                    -- 28
  "_test_gameplay_loop_set_game_uses_runtime_ui_port_dto",                    -- 29
  "_test_gameplay_loop_refresh_drives_camera_follow_via_port",                -- 30
  "_test_gameplay_loop_camera_follow_skips_eliminated_current_player",        -- 31
  "_test_gameplay_loop_clock_ports_split_wall_and_cpu_semantics",             -- 32
  "_test_choice_auto_policy_consistent_between_wait_and_timeout",             -- 33
  "_test_popup_countdown_uses_effective_modal_timeout",                       -- 34
  "_test_market_countdown_uses_double_action_timeout",                        -- 35
  "_test_dispatch_gate_blocks_next_when_choice_active",                       -- 36
  "_test_game_startup_role_roster_retries_before_debug_players_fallback",     -- 37
  "_test_find_player_by_id_accepts_mixed_representation",                     -- 38
  "_test_runtime_context_change_skin_exports_and_event",                      -- 39
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

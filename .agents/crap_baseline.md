# CRAP Baseline Freeze

- generated_at: None
- report_source: `/var/folders/qw/32_j34_d44zbrwgwp0_x487h0000gn/T/monopoly_crap/crap_report.json`
- total_functions: 2102
- over_8_count: 210
- over_8_refactor_count: 67
- over_8_coverage_first_count: 143

## Ownership Summary

- T2: count=48, max_crap=182.0, must_refactor=18, coverage_first=30
- T3: count=5, max_crap=27.52, must_refactor=3, coverage_first=2
- T4: count=38, max_crap=90.0, must_refactor=14, coverage_first=24
- T5: count=48, max_crap=361.33, must_refactor=13, coverage_first=35
- T6: count=39, max_crap=90.0, must_refactor=13, coverage_first=26
- T7: count=31, max_crap=56.0, must_refactor=6, coverage_first=25
- T8: count=1, max_crap=12.0, must_refactor=0, coverage_first=1

## Top 40 Hotspots

- T5 | must_refactor | crap=361.33 | complexity=19 | coverage=0.02 | coverage_needed_for_8=- | `src/presentation/model/init.lua:94` | `model_api.update`
- T2 | must_refactor | crap=182.0 | complexity=13 | coverage=0.0 | coverage_needed_for_8=- | `src/game/flow/turn/await.lua:144` | `await.move_anim`
- T4 | must_refactor | crap=90.0 | complexity=9 | coverage=0.0 | coverage_needed_for_8=- | `src/game/systems/items/post_effects.lua:227` | `anonymous@227`
- T6 | must_refactor | crap=90.0 | complexity=9 | coverage=0.0 | coverage_needed_for_8=- | `src/presentation/view/render/board_scene.lua:4` | `board_scene.init`
- T5 | must_refactor | crap=78.97 | complexity=9 | coverage=0.05 | coverage_needed_for_8=- | `src/presentation/model/panel_slice.lua:45` | `panel_slice.update`
- T5 | must_refactor | crap=76.53 | complexity=9 | coverage=0.06 | coverage_needed_for_8=- | `src/presentation/runtime/event_handlers.lua:20` | `_apply_game_result_panels`
- T2 | coverage_first | crap=72.0 | complexity=8 | coverage=0.0 | coverage_needed_for_8=1.0 | `src/game/flow/turn/start.lua:16` | `_phase_start`
- T5 | coverage_first | crap=72.0 | complexity=8 | coverage=0.0 | coverage_needed_for_8=1.0 | `src/presentation/runtime/controllers/modal_controller.lua:15` | `modal_presenter.select_choice_option`
- T2 | coverage_first | crap=64.62 | complexity=8 | coverage=0.04 | coverage_needed_for_8=1.0 | `src/game/flow/turn/land.lua:46` | `handle_need_landing`
- T4 | coverage_first | crap=56.71 | complexity=8 | coverage=0.09 | coverage_needed_for_8=1.0 | `src/game/systems/endgame/bankruptcy.lua:9` | `_try_call_life_die`
- T4 | must_refactor | crap=56.14 | complexity=10 | coverage=0.23 | coverage_needed_for_8=- | `src/game/core/player/state_ops/status_ops.lua:21` | `status_ops.set_player_seat`
- T7 | coverage_first | crap=56.0 | complexity=7 | coverage=0.0 | coverage_needed_for_8=0.7267 | `src/app/bootstrap/ui_bootstrap.lua:31` | `_required_click_nodes`
- T2 | coverage_first | crap=56.0 | complexity=7 | coverage=0.0 | coverage_needed_for_8=0.7267 | `src/game/flow/turn/await.lua:89` | `await.choice`
- T7 | coverage_first | crap=56.0 | complexity=7 | coverage=0.0 | coverage_needed_for_8=0.7267 | `src/infrastructure/runtime/synthetic_actor_registry.lua:14` | `_safe_query_start_pos`
- T5 | coverage_first | crap=56.0 | complexity=7 | coverage=0.0 | coverage_needed_for_8=0.7267 | `src/presentation/runtime/controllers/modal_controller.lua:109` | `modal_presenter.close_choice_modal`
- T5 | coverage_first | crap=56.0 | complexity=7 | coverage=0.0 | coverage_needed_for_8=0.7267 | `src/presentation/runtime/ports/view_command_ports.lua:15` | `_toggle_action_log`
- T6 | coverage_first | crap=56.0 | complexity=7 | coverage=0.0 | coverage_needed_for_8=0.7267 | `src/presentation/view/render/anim_overlay_runtime.lua:116` | `runtime.spawn_transient`
- T6 | coverage_first | crap=56.0 | complexity=7 | coverage=0.0 | coverage_needed_for_8=0.7267 | `src/presentation/view/render/tile_renderer.lua:11` | `tile_renderer.render_tile`
- T7 | coverage_first | crap=51.8 | complexity=7 | coverage=0.03 | coverage_needed_for_8=0.7267 | `src/infrastructure/runtime/synthetic_actor_registry.lua:110` | `registry.spawn_pending`
- T7 | coverage_first | crap=49.62 | complexity=7 | coverage=0.05 | coverage_needed_for_8=0.7267 | `src/infrastructure/runtime/context.lua:31` | `_first_valid_role`
- T4 | coverage_first | crap=49.01 | complexity=7 | coverage=0.05 | coverage_needed_for_8=0.7267 | `src/game/systems/market/application/eligibility.lua:55` | `eligibility.build_visible_entries`
- T6 | must_refactor | crap=42.02 | complexity=16 | coverage=0.53 | coverage_needed_for_8=- | `src/presentation/view/render/status3d/status.lua:82` | `M.sync_layer_status`
- T2 | coverage_first | crap=42.0 | complexity=6 | coverage=0.0 | coverage_needed_for_8=0.6184 | `src/game/flow/turn/await.lua:27` | `_resolve_after_action_anim`
- T2 | coverage_first | crap=42.0 | complexity=6 | coverage=0.0 | coverage_needed_for_8=0.6184 | `src/game/flow/turn/await.lua:165` | `await.action_anim`
- T2 | coverage_first | crap=42.0 | complexity=6 | coverage=0.0 | coverage_needed_for_8=0.6184 | `src/game/flow/turn/await.lua:272` | `await.seconds`
- T2 | coverage_first | crap=42.0 | complexity=6 | coverage=0.0 | coverage_needed_for_8=0.6184 | `src/game/flow/turn/phase_registry.lua:25` | `_phase_post`
- T4 | coverage_first | crap=42.0 | complexity=6 | coverage=0.0 | coverage_needed_for_8=0.6184 | `src/game/systems/items/phase.lua:27` | `_resolve_after_action_anim`
- T6 | coverage_first | crap=42.0 | complexity=6 | coverage=0.0 | coverage_needed_for_8=0.6184 | `src/presentation/input/intent_dispatch/pre_confirm.lua:19` | `_resolve_item_slot_option`
- T4 | coverage_first | crap=36.61 | complexity=6 | coverage=0.05 | coverage_needed_for_8=0.6184 | `src/game/systems/chance/handlers/cash_handlers.lua:133` | `handlers.collect_from_others`
- T5 | coverage_first | crap=36.33 | complexity=6 | coverage=0.06 | coverage_needed_for_8=0.6184 | `src/presentation/model/board_slice.lua:65` | `board_slice.update`
- T7 | coverage_first | crap=33.73 | complexity=6 | coverage=0.08 | coverage_needed_for_8=0.6184 | `src/infrastructure/runtime/synthetic_actor_registry.lua:91` | `registry.register_specs`
- T6 | must_refactor | crap=32.67 | complexity=10 | coverage=0.39 | coverage_needed_for_8=- | `src/presentation/view/render/anim_tip_text.lua:28` | `tip_text.build`
- T7 | coverage_first | crap=30.0 | complexity=5 | coverage=0.0 | coverage_needed_for_8=0.5068 | `src/app/bootstrap/ui_bootstrap.lua:19` | `_spawn_startup_synthetic_actors`
- T7 | coverage_first | crap=30.0 | complexity=5 | coverage=0.0 | coverage_needed_for_8=0.5068 | `src/app/bootstrap/ui_bootstrap.lua:88` | `anonymous@88`
- T2 | coverage_first | crap=30.0 | complexity=5 | coverage=0.0 | coverage_needed_for_8=0.5068 | `src/game/flow/turn/decision.lua:13` | `turn_decision.decide_choice_action`
- T2 | coverage_first | crap=30.0 | complexity=5 | coverage=0.0 | coverage_needed_for_8=0.5068 | `src/game/flow/turn/land.lua:19` | `_has_pending_move_action_anim`
- T5 | coverage_first | crap=30.0 | complexity=5 | coverage=0.0 | coverage_needed_for_8=0.5068 | `src/presentation/runtime/host/raycast.lua:23` | `_vec_add`
- T5 | coverage_first | crap=30.0 | complexity=5 | coverage=0.0 | coverage_needed_for_8=0.5068 | `src/presentation/runtime/host/raycast.lua:37` | `_vec_scale`
- T5 | coverage_first | crap=30.0 | complexity=5 | coverage=0.0 | coverage_needed_for_8=0.5068 | `src/presentation/runtime/host/raycast.lua:226` | `raycast.get_unit_id`
- T6 | coverage_first | crap=30.0 | complexity=5 | coverage=0.0 | coverage_needed_for_8=0.5068 | `src/presentation/view/render/anim_tip_text.lua:16` | `_resolve_player_name`

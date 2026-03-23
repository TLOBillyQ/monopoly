# CRAP 热点函数

来源：`C:/Users/Lzx_8/AppData/Local/Temp/monopoly_crap/crap_report.json`
生成时间：`2026-03-23T08:37:25Z`

## Top Hotspots

| Rank | Function | Location | CRAP | Complexity | Coverage | Risk |
|---|---|---|---:|---:|---:|---|
| 1 | `_can_offer_rent_response` | `src/rules/items/availability.lua:103` | 56.00 | 7 | 0.00% | critical |
| 2 | `units.play_mine_trigger` | `src/ui/render/anim_units.lua:66` | 42.00 | 6 | 0.00% | critical |
| 3 | `item_preconsume_policy.decorate_followup_choice_spec` | `src/core/choice/item_preconsume_policy.lua:51` | 30.00 | 5 | 0.00% | warning |
| 4 | `resolve_any_role` | `src/host/eggy/context.lua:51` | 30.00 | 5 | 0.00% | warning |
| 5 | `_resolve_tile_index` | `src/ui/ctl/event_handlers.lua:126` | 25.02 | 5 | 7.00% | warning |
| 6 | `_safe_get_role` | `src/host/eggy/context.lua:15` | 20.00 | 4 | 0.00% | warning |
| 7 | `validator.resolve_item_slot_action` | `src/turn/actions/validator.lua:137` | 16.04 | 13 | 74.00% | warning |
| 8 | `_resolve_backward_next_id` | `src/rules/board/init.lua:155` | 16.00 | 8 | 50.00% | warning |
| 9 | `_remote_priority` | `src/computer/policies/core_agent.lua:54` | 13.05 | 6 | 42.00% | warning |
| 10 | `_direction` | `src/config/content/maps/ring_map_builder.lua:48` | 12.00 | 3 | 0.00% | warning |
| 11 | `_profile` | `src/config/testing/test_profiles.lua:1` | 12.00 | 3 | 0.00% | warning |
| 12 | `availability.trigger_timing_allowed` | `src/rules/items/availability.lua:70` | 12.00 | 3 | 0.00% | warning |
| 13 | `phase_module.build_wait_choice_args` | `src/rules/items/phase.lua:121` | 12.00 | 3 | 0.00% | warning |
| 14 | `anonymous@42` | `src/ui/ctl/ui_runtime.lua:42` | 12.00 | 3 | 0.00% | warning |
| 15 | `_run_auto_phase` | `src/rules/items/phase.lua:211` | 9.97 | 7 | 61.00% | low |
| 16 | `turn_timer_policy.update_action_button_timer` | `src/turn/policies/timer_policy.lua:111` | 9.51 | 9 | 81.00% | low |
| 17 | `startup_policy.resolve` | `src/app/bootstrap/startup_policy.lua:7` | 9.03 | 9 | 93.00% | low |
| 18 | `choice_resolver.resolve` | `src/core/choice/resolver.lua:134` | 9.00 | 9 | 97.00% | low |
| 19 | `defaults.cpu_now_seconds` | `src/host/eggy/default_ports.lua:175` | 8.67 | 3 | 14.00% | low |
| 20 | `defaults.wall_now_seconds` | `src/host/eggy/default_ports.lua:147` | 8.67 | 3 | 14.00% | low |

## 观察

- 当前最高风险集中在 `src/rules/items/availability.lua`、`src/host/eggy/context.lua`、`src/rules/items/phase.lua`。
- 前 6 个热点里有 5 个覆盖率为 `0%`，优先补 characterization tests 收益最高。
- `src/turn/actions/validator.lua:137` 的 `validator.resolve_item_slot_action` 复杂度高，但覆盖率已到 `74%`，更偏向局部降复杂度而不是先补覆盖。

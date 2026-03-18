# LuaLS `src/` Frozen Inventory

Command baseline:
`lua-language-server --check=src --configpath=../.luarc.json --check_format=json --logpath=/tmp/luals-t2 --checklevel=Warning`

Frozen result after T1 + T2:
- `34` warnings
- `13` files

## T4 Write Set

- `src/player/actions/inventory.lua`
  - `L11 redundant-parameter`
- `src/state/state_access/landing_visual_hold.lua`
  - `L126 redundant-parameter`
- `src/ui/pres/panel_slice.lua`
  - `L35 redundant-parameter`
  - `L49 redundant-parameter`
- `src/ui/render/market.lua`
  - `L59 redundant-parameter`
  - `L83 redundant-parameter`
  - `L87 redundant-parameter`
  - `L95 redundant-parameter`

Notes:
- `market_controls.lua` and `panel_builder.lua` are in the planned area but have no remaining LuaLS warnings in this frozen pass.
- T4 owns only call-shape drift and redundant parameters. Do not touch `src/ui/render/board_feedback_service.lua` or T6 files.

## T5 Write Set

- `src/host/eggy/synthetic_actor_registry.lua`
  - `L121 undefined-field create_creature_fixed_scale`
  - `L121 need-check-nil`
- `src/ui/render/board/player_units.lua`
  - `L40 need-check-nil`
- `src/ui/render/board_feedback_service.lua`
  - `L142 need-check-nil`
  - `L142 undefined-field play_3d_sound`
  - `L144 need-check-nil`
  - `L144 undefined-field schedule`
  - `L164 need-check-nil`
  - `L164 undefined-field play_sfx_by_key`
  - `L171 need-check-nil`
  - `L171 undefined-field bind_sfx_to_unit`
  - `L188 need-check-nil`
  - `L188 undefined-field play_3d_sound`

Notes:
- T5 owns host/runtime bridge warnings and render-side nil guards.
- Do not edit `src/ui/render/market.lua`.

## T6 Write Set

- `src/app/bootstrap/startup_policy.lua`
  - `L11 cast-local-type`
- `src/rules/items/demolish.lua`
  - `L14 deprecated`
- `src/state/state_access/runtime_editor_exports.lua`
  - `L53 return-type-mismatch`
  - `L110 return-type-mismatch`
  - `L116 return-type-mismatch`
  - `L134 return-type-mismatch`
  - `L138 return-type-mismatch`
  - `L142 return-type-mismatch`
- `src/turn/timing/session_script.lua`
  - `L45 need-check-nil`
- `src/ui/ctl/target_choice_effects.lua`
  - `L195 need-check-nil`
  - `L195 undefined-field id`
- `src/ui/input/dispatch_pre_confirm.lua`
  - `L53 need-check-nil`
  - `L53 undefined-field options`

Notes:
- T6 owns nilability, annotation contract fixes, and the remaining non-render, non-host warnings.
- Do not edit `src/ui/render/**` or `src/host/eggy/**`.

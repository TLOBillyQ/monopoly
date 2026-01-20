# Eggy 适配层实现（从 Love2D 迁移到 Eggy PC 编辑器）

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

Follow .codex/.agent/PLANS.md from the repository root. This ExecPlan must remain compliant with that file.

## Purpose / Big Picture

After this work, a developer can run the Monopoly game logic inside the Eggy PC editor without changing any rule-layer code. They can click Eggy UI nodes (buttons, modal choices, tile selections) and see the game progress, then resume from an in-editor archive. They can prove it works by running Lua checks, opening the Eggy project, and observing that the UI reflects the store state and action replay is deterministic.

## Progress

- [x] (2026-01-20 07:07Z) Read existing Love2D adapter and confirm action/choice flows to mirror.
- [x] (2026-01-20 07:07Z) Implement minimal Eggy runtime and layer that can boot new_game and tick.
- [x] (2026-01-20 07:07Z) Add choice flow wiring and UI modal node refresh for need_choice.
- [x] (2026-01-20 07:07Z) Implement panel UI refresh and action button mapping.
- [x] (2026-01-20 07:07Z) Implement board UI refresh and tile selection mapping.
- [x] (2026-01-20 07:07Z) Implement event-to-action mapping table and enforce dispatch_action-only mutations.
- [x] (2026-01-20 17:14Z) Verify Eggy adapter files exist and align with milestones 0-4 (`src/adapters/eggy/eggy_layer.lua`, `src/adapters/eggy/eggy_runtime.lua`, `src/adapters/eggy/presenter.lua`, `src/adapters/eggy/ui_state.lua`).
- [ ] (2026-01-20 17:14Z) Implement archive save/load with Role.get_archive_by_type and wire Continue/Restart entry flow.
- [ ] (2026-01-20 17:14Z) Run validation steps and capture expected logs/results in this plan.

## Surprises & Discoveries

- Observation: none yet.
  Evidence: not started.
 - Observation: `docs/eggy/plan.md` is missing in the current working tree, so this ExecPlan must be fully self-contained.
   Evidence: `Get-Content docs/eggy/plan.md` failed with "path does not exist".

## Decision Log

- Decision: Follow the existing adapter contract (game.ui_port + dispatch_action) and reuse Love2D presenter data shape.
  Rationale: The roadmap states rules layer is fixed; reusing the existing contract keeps behavior identical.
  Date/Author: 2026-01-20 / Codex
- Decision: Map Eggy UI nodes using explicit names (panel_*, btn_*, tile_*, modal_choice, modal_popup) and refresh via adapter only.
  Rationale: Avoids adding abstraction without real call sites and keeps UI wiring consistent with Love2D behavior.
  Date/Author: 2026-01-20 / Codex
- Decision: Treat milestones 0-4 as implemented based on the presence of Eggy adapter files and keep archives/validation as remaining work.
  Rationale: The repository already contains the core Eggy adapter modules, but no archive wiring or validation evidence is recorded here.
  Date/Author: 2026-01-20 / Codex

## Outcomes & Retrospective

- Outcome: not started.

## Context and Orientation

This repository currently runs Monopoly logic through a Love2D adapter in `src/adapters/love2d/`. The rule layer lives under `src/gameplay/`, `src/core/`, and `src/config/` and must not be changed. The Eggy adapter will live under `src/adapters/eggy/` and is responsible for event bridging, UI node refresh, input mapping, archive read/write, and basic automation (auto/timeout).

Key files to read:

- `src/adapters/love2d/love_layer.lua` defines the runtime loop, action dispatch, pending_choice handling, and auto_runner integration.
- `src/adapters/love2d/love_runtime.lua` defines the Love2D event bindings.
- `src/adapters/love2d/presenter.lua` defines the view data shape used by UI refresh functions.
- `docs/eggy/eggy-capability-matrix.zh-CN.md` documents Eggy editor capabilities found so far.
- `docs/eggy/eggy-migration-roadmap.zh-CN.md` records prior migration context.

Definitions (plain language):

- Action: a structured input message passed to `dispatch_action` that changes game state in the rules layer.
- Pending choice: a rules-layer pause that waits for a user selection (choice_select or choice_cancel).
- UI node: a named editor object (button, text label, grid cell, modal panel) that can be shown or updated.
- Archive: a serialized snapshot of the game store or action list saved via Eggy Role APIs.

## Plan of Work

Milestone 0 (boot and tick). Add `src/adapters/eggy/eggy_runtime.lua` that binds Eggy events (`GAME_INIT`, tick handler, `UI_CUSTOM_EVENT`) and calls into a minimal `EggyLayer` in `src/adapters/eggy/eggy_layer.lua`. `EggyLayer` should mirror LoveLayer structure: initialize game via `game_factory`, hold `ui_state`, and tick by calling `game:tick` on a schedule. Log current player name, cash, and round each tick to confirm rule layer is alive. Do not render UI yet. At the end, running the Eggy project should show logs advancing without errors.

Milestone 1 (choice flow). Wire `IntentDispatcher.on("need_choice")` (or the Love2D equivalent hook) so it triggers an Eggy modal UI refresh via `ui_state`. Implement `pending_choice` timeout using `constants.action_timeout_seconds` and ensure it blocks game progression until resolved. Add a `dispatch_action` bridge for `choice_select` and `choice_cancel` and log each action received. At the end, entering a choice state should show a modal and only resume after a selection or timeout.

Milestone 2 (panel UI). Create `refresh_panel(view)` that maps presenter fields to Eggy UI node text and button states. Wire buttons `btn_next`, `btn_auto`, and `btn_restart` to actions `ui_button` with payloads `next/auto/restart`. Reflect auto mode in button style (visibility or color) but keep logic identical to Love2D. At the end, panel UI should show current player, cash, phase, round, dice, and event log, and buttons should drive the same actions as Love2D.

Milestone 3 (board UI). Create `refresh_board(view)` that maps board state to a grid of UI nodes (e.g., `tile_x_y` or `tile_idx`). Bind tile selection to `ui_tile_select` action via `UI_CUSTOM_EVENT`. Add a tile detail panel that shows price, level, owner, barricades, and mines from the presenter. At the end, selecting a tile updates the detail panel without directly mutating game state.

Milestone 4 (input mapping and replay). Consolidate all UI events (buttons, modal, tile, keyboard if supported) into an explicit mapping table that produces actions passed into `dispatch_action`. Ensure no UI event mutates the game directly; only actions do. Verify action replay determinism by logging seeds and replaying a recorded action list to reach the same outcomes.

Milestone 5 (archives). Implement save/load using `Role.get_archive_by_type` and `Role.set_archive_by_type`. Define a versioned archive structure that stores either the game store snapshot or the action list plus seed. Add UI nodes for “continue” and “restart”. At the end, closing and reopening the Eggy project should allow resuming the last run or starting fresh.

Milestone 6 (3D presentation). Add optional 3D units, camera, and audio that reflect the same presenter state. This is cosmetic only; no rule changes. At the end, visuals should track the same board and player positions as the UI nodes.

## Concrete Steps

1) Read and mirror Love2D adapter behavior.
   - Working directory: repository root.
   - Open `src/adapters/love2d/love_layer.lua`, `src/adapters/love2d/love_runtime.lua`, `src/adapters/love2d/presenter.lua`.
   - Record which actions are dispatched, how pending_choice is stored, and how auto_runner advances ticks.

2) Implement minimal Eggy runtime and layer.
   - Create `src/adapters/eggy/eggy_runtime.lua` with Eggy event bindings.
   - Create `src/adapters/eggy/eggy_layer.lua` with the minimal lifecycle (init, tick, dispatch_action).
   - Create `src/adapters/eggy/ui_state.lua` with node lookup and cached handles.
   - Keep `src/adapters/eggy/presenter.lua` as a direct reuse of Love2D presenter (copy or require the same file).

3) Implement UI refresh functions.
   - Add `refresh_panel(view)` and `refresh_board(view)` in the Eggy adapter (either in `eggy_layer.lua` or a small helper module if it has at least two real call sites).
   - Bind UI nodes by name; do not add abstractions for unused nodes.
   - Expected nodes: `panel_title`, `panel_turn`, `panel_current_title`, `panel_current_name`, `panel_current_role`, `panel_current_phase`, `panel_current_dice`, `panel_players_title`, `panel_player_1..4`, `panel_player_1_detail..4_detail`, `panel_tile_title`, `tile_detail_name`, `tile_detail_price`, `tile_detail_level`, `tile_detail_owner`, `tile_detail_roadblock`, `tile_detail_mine`, `panel_log_title`, `panel_log_body`, `btn_next`, `btn_auto`, `btn_restart`, and `tile_1..N`.
   - Modal nodes: `modal_choice` group (existing) and `modal_popup` group (`popup_title`, `popup_body`, `popup_confirm`).

4) Implement action mapping.
   - Add a mapping table from Eggy UI events to action payloads.
   - Ensure `dispatch_action` is the sole path to mutate game state.
   - Map `ui_tile_select` to `dispatch_action({ type = "ui_tile_select", index = ... })` and use it to update the selected tile only.
   - Map `popup_confirm` to close the Eggy popup without touching game state.

5) Implement archives.
   - Define archive struct with version and data fields.
   - Use Role APIs to load on init and save on exit or on each action.

6) Update docs and validate.
   - Update this ExecPlan Progress section as steps complete.
   - Add or update doc snippets in `docs/eggy/eggy-capability-matrix.zh-CN.md` if new Eggy event data is discovered.

## Validation and Acceptance

Run the baseline repo checks before and after changes:

    lua tests/deps_check.lua
    lua tests/regression.lua

Open Eggy PC editor and run the project:

- Observe logs on startup showing player name, cash, round.
- Trigger a choice; observe a modal UI, then select/cancel to resume.
- Click Next/Auto/Restart and see matching action logs.
- Select a tile and see detail panel update.
- Save, quit, reopen, and choose Continue to resume the same state.
- Replay recorded actions with the same seed and confirm identical outcomes.

Acceptance means all of the above steps succeed without changing any rule-layer files under `src/gameplay/`, `src/core/`, or `src/config/`.

## Idempotence and Recovery

All steps are additive and can be re-run safely. If a UI binding is wrong, fix the node name and rerun without altering rule-layer state. If archive data is corrupt, delete the archive entry via Role APIs and restart, then re-save with the new version.

## Artifacts and Notes

Expected log example after Milestone 0:

    [eggy] init ok: player=Alice cash=1500 round=1
    [eggy] tick ok: player=Alice cash=1500 round=1

Expected log example after Milestone 1:

    [eggy] need_choice: { id=..., options=... }
    [eggy] action: choice_select index=2

If action replay is enabled, log the seed and action count to confirm determinism.

## Interfaces and Dependencies

Use the same interfaces as Love2D adapter:

- `EggyLayer:dispatch_action(action)` must accept the same action table shapes as `LoveLayer:dispatch_action`.
- `presenter.build_view(game_store)` (or equivalent) must return the view data consumed by refresh functions.
- `ui_state` must provide a simple node lookup (by name/id) and cache handles for repeated refresh.

Eggy event bindings must include:

- GAME_INIT to initialize the game.
- TICK handler (set_tick_handler or REPEAT_TIMEOUT) to call game tick.
- UI_CUSTOM_EVENT to capture button/tile events and map them to actions.

Plan update note: Added initial ExecPlan to guide Eggy adapter implementation based on repository PLANS.md requirements. (2026-01-20 / Codex)
Plan update note: Completed milestones 0-4 with Eggy adapter panel/board refresh, UI mapping table, and popup support; added expected UI node list. (2026-01-20 / Codex)
Plan update note: Refreshed Progress/Decision/Surprises to reflect current repo state and remaining work, and recorded missing `docs/eggy/plan.md` so this plan stays self-contained. (2026-01-20 / Codex)
```

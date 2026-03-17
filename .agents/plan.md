# Plan: Next Round Presentation/Runtime Boundary Cleanup

**Generated**: 2026-03-17

## Overview
This round follows the completed `src.entry` hard cut and focuses on the next highest-value cleanup: shrinking presentation ownership so `src/ui/**` and `src/presentation/runtime/**` stop reaching into runtime state and host details directly. The intent is to make the presentation layer consume narrow injected seams, while leaving deeper `flow -> runtime` simplification as a later dedicated round.

Assumption for this plan: the next round prioritizes `presentation -> runtime` cleanup before the broader `flow -> runtime` edge reduction, because the current UI stack still imports `runtime_state`, `landing_visual_hold`, and `src.host.eggy*` in many places and that leak will otherwise keep the new root semantics blurry.

## Prerequisites
- Current post-migration tree is the baseline: `main.lua -> src.app.bootstrap`
- No new external libraries are expected for this round; Context7 is not needed unless implementation introduces a new dependency
- Keep the round scoped: do not physically migrate `src/ui`, `src/turn`, `src/state`, `src/player`, or `src/host`
- Keep startup/test-profile behavior unchanged, especially fake `new(...)` patch points
- Treat grouped loop ports and startup/runtime tests as protected contracts, not incidental implementation details

## Dependency Graph

```text
T1 ──┬── T3 ──┬── T4 ──┐
     │        │        ├── T6 ── T7 ── T8
T2 ──┘        └── T5 ──┘
```

## Tasks

### T1: Create narrow presentation state seams
- **depends_on**: []
- **location**: `src/presentation/runtime/state_factory.lua`, `src/ui/ctl/ports/common.lua`, `src/ui/ctl/ports/ui_sync_ports.lua`, `src/ui/ctl/ports/view_command_ports.lua`, `src/ui/ctl/ports/state_ports.lua`, new seam module(s) under `src/ui/ctl/ports/`
- **description**: Introduce narrow read/write seams for UI-facing state such as `ui_model`, `pending_choice`, modal timer, landing-visual deferral, board feedback, and debug/runtime flags so generic presentation modules no longer import `src.state.state_access.runtime_state` or `src.state.state_access.landing_visual_hold` directly. `state_factory` should assemble these seams, not own reusable state logic.
- **validation**: `rg -n 'require\("src\.state\.state_access\.(runtime_state|landing_visual_hold)' src/ui src/presentation/runtime` only hits the intentionally retained adapter files; targeted presentation suites still pass.
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T2: Isolate host runtime access behind explicit presentation adapters
- **depends_on**: []
- **location**: `src/ui/ctl/deps.lua`, `src/ui/ctl/actor_context.lua`, `src/ui/ctl/event_handlers.lua`, `src/ui/ctl/event_bindings.lua`, `src/ui/ctl/target_choice_effects.lua`, `src/ui/ctl/canvas_event_router.lua`, `src/ui/ctl/ports/ui_sync/camera_sync.lua`, `src/presentation/runtime/ui_bootstrap.lua`
- **description**: Consolidate `src.host.eggy` and `src.host.eggy.context` usage into a small adapter surface that presentation code receives via injected deps/ports. The expected host-touching allowlist at end of round is bootstrap/deps/adapter code only (for example `src/presentation/runtime/ui_bootstrap.lua`, `src/ui/ctl/deps.lua`, and the dedicated adapter files under `src/ui/ctl/ports/` that truly need host access).
- **validation**: `rg -n 'require\("src\.host\.eggy' src/ui src/presentation/runtime` is reduced to the agreed adapter/bootstrap files only; behavior stays unchanged.
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T3: Freeze seam contracts and state-shape allowlists
- **depends_on**: [T1, T2]
- **location**: `src/ui/ctl/ports/init.lua`, `src/turn/loop/ports.lua`, `tests/suites/runtime/runtime_ports_contract.lua`, `tests/suites/presentation/_presentation_action_status_*.lua`, `tests/guards/dep_rules.lua`
- **description**: Lock the grouped loop-port contract and define the allowed state-shape ownership before broad consumer rewrites begin. This includes codifying which files may still touch `state.presentation_runtime`, `state.gameplay_loop_ports`, `state.game`, cached resolved ports, or host-touching bootstrap state directly.
- **validation**: `lua tests/contract.lua` stays green with the seam contract assertions in place; grep/guard rules describe both import allowlists and direct state-field allowlists.
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T4: Refactor presentation consumers to use the new seams
- **depends_on**: [T1, T2, T3]
- **location**: `src/ui/render/board.lua`, `src/ui/render/board/placement.lua`, `src/ui/render/market.lua`, `src/ui/render/market_controls.lua`, `src/ui/pres/choice_slice.lua`, `src/ui/stores/modal_state.lua`, `src/ui/ctl/modal_controller.lua`, `src/ui/ctl/market_controller.lua`, `src/ui/ctl/item_slots.lua`, `src/ui/input/*.lua`, `src/ui/ctl/choice_screens/helpers.lua`
- **description**: Replace direct runtime-state and host-runtime reads/writes inside production presentation modules with the seams from T1/T2/T3. Keep gameplay behavior unchanged; this is an ownership cleanup, not a feature round.
- **validation**: presentation suites under `tests/suites/presentation/` pass; grep confirms generic presentation modules no longer import runtime internals directly.
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T5: Migrate test fixtures and integration helpers onto the same seams
- **depends_on**: [T3]
- **location**: `tests/support/shared_support.lua`, `tests/support/gameplay_support.lua`, `tests/support/runtime_support.lua`, `tests/suites/runtime/startup_profile.lua`, `tests/suites/runtime/runtime_bootstrap.lua`, `tests/suites/gameplay/gameplay_cases.lua`, `tests/suites/gameplay/gameplay_items_startup.lua`
- **description**: Update helpers and integration suites that build `state.gameplay_loop_ports`, `state.presentation_runtime`, or startup/runtime fixtures so they use the same seams and allowlists as production code. This prevents helper drift from hiding or reintroducing coupling.
- **validation**: helper-backed startup/gameplay/runtime suites stay green while using the new contracts.
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T6: Slim `src/presentation/runtime` down to orchestration only
- **depends_on**: [T4, T5]
- **location**: `src/presentation/runtime/gameplay_runtime_bootstrap.lua`, `src/presentation/runtime/runtime_event_bridge.lua`, `src/presentation/runtime/state_factory.lua`, `src/app/bootstrap/init.lua`, `src/turn/loop.lua`, `src/turn/loop/loop_runtime.lua`
- **description**: After consumers and fixtures have stabilized on the new seams, move reusable logic out of the runtime bootstrap layer so these modules only wire `state`, `ports`, `deps`, and bridge callbacks together. Any durable UI/runtime behavior discovered here should move to `src/ui/ctl/ports/*` or `src/turn/*` seam modules.
- **validation**: code review shows bootstrap modules are mostly assembly; startup/runtime/gameplay tests continue to pass; no new direct ownership of `ui.*` behavior is added here.
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T7: Lock the boundary in guards, arch config, and viewer alignment
- **depends_on**: [T6]
- **location**: `tests/guards/dep_rules.lua`, `scripts/quality/arch/config.json`, `tests/suites/architecture/arch_view_contract.lua`, `docs/architecture/arch_view.md`, `scripts/quality/arch/viewer/`
- **description**: Tighten the static boundary so presentation code cannot drift back to direct `runtime_state`, `landing_visual_hold`, or `src.host.eggy*` imports outside the chosen adapter files, and keep arch-view config/contracts/viewer aligned if the stricter rules expose root-view or projection drift.
- **validation**: `lua tests/guard.lua` and `lua scripts/quality/arch.lua check` pass with the stricter rules enabled; viewer snapshot stays aligned with contract expectations.
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T8: Full verification and closeout
- **depends_on**: [T7]
- **location**: repo-wide test commands and snapshot outputs
- **description**: Run the full validation set, refresh viewer snapshots only if architecture output changed, and verify the round did not accidentally widen into general `flow -> runtime` surgery.
- **validation**: `lua scripts/quality/arch.lua check`; `lua scripts/quality/arch.lua viewer --out-dir scripts/quality/arch/viewer`; `lua tests/guard.lua`; `lua tests/contract.lua`; `lua tests/behavior.lua`; `lua tests/regression.lua`; plus grep checks from T1/T2/T3.
- **status**: Not Completed
- **log**:
- **files edited/created**:

## Parallel Execution Groups

| Wave | Tasks | Can Start When |
|------|-------|----------------|
| 1 | T1, T2 | Immediately |
| 2 | T3 | T1 and T2 complete |
| 3 | T4, T5 | T3 complete |
| 4 | T6 | T4 and T5 complete |
| 5 | T7 | T6 complete |
| 6 | T8 | T7 complete |

## Testing Strategy
- Use grep-based boundary checks during implementation, not only at the end
- Protect grouped loop-port compatibility with contract tests before broad rewrites
- Keep startup-profile and gameplay startup tests green to protect constructor patch seams
- Migrate helper fixtures early enough that production and test seams stay aligned
- Run full `arch/check + guard + contract + behavior + regression` before closing the round

## Risks & Mitigations
- **Risk**: scope creep into full `flow -> runtime` redesign; **Mitigation**: allow only seam extraction needed by T6 and defer larger flow cleanup to a separate round
- **Risk**: presentation tests depend on current state shape and may break noisily; **Mitigation**: freeze seam contracts in T3 and migrate helpers in T5 before bootstrap slimming in T6
- **Risk**: host/runtime access gets hidden but not reduced; **Mitigation**: enforce concrete bootstrap/adapter allowlists in T2 and T7 so only explicit files may touch `src.host.eggy*`
- **Risk**: coupling leaks through direct state-field ownership instead of imports; **Mitigation**: T3/T7 guard both import edges and direct state-shape allowlists
- **Risk**: arch-view root/projection drift becomes part of the failure surface once config tightens; **Mitigation**: T7 explicitly owns config/contract/viewer alignment instead of treating it as out of scope

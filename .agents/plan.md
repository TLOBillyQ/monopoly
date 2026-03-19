# Swarm-Ready Rewrite of `./.agents/plan.md`

## Summary

Upgrade the existing simplify plan into a dependency-aware execution plan for parallel agents. The code scope stays the same: reduce duplication around dirty buckets, choice owner parsing, route metadata, intent event emission, and action animation guards without changing player-visible behavior or crossing architecture boundaries.

Two repo facts must be reflected in the plan before implementation starts:
- raw suite files are not valid verification entrypoints here; they must run through lane/bootstrap entrypoints
- `lua tests/behavior.lua` is green on the current tree (`999` checks passed), while `guard` / `arch` still need one confirmed runnable context before they can be used as final acceptance gates in this shell

## Public/Internal Interface Changes

- `src/core/utils/dirty_tracker.lua` becomes the single source for dirty-bucket shape plus merge/reset helpers; snapshot behavior from `consume()` stays byte-for-byte compatible in semantics
- `src/core/choice/contract.lua` may add pure field-level helpers for `owner_role_id` / `target_picker_owner_role_id`; it must not absorb `game` or current-player fallback
- `src/core/choice/route_policy.lua` becomes the canonical reader for explicit route and confirm metadata; `src/ui/input/choice_route_policy.lua` remains the UI-facing alias
- `src/core/events/monopoly_events.lua` may add a dedicated intent-emission helper so `src/turn/output/intent_dispatcher.lua` stops re-assembling event emission locally

## Task Graph

### T0: Lock runnable validation context and plan ownership
- **depends_on**: `[]`
- **location**: `./.agents/plan.md`, test/quality entrypoints
- **description**: Rewrite the plan’s verification section to use lane entrypoints (`lua tests/behavior.lua`, `lua tests/contract.lua`, `lua tests/guard.lua`, `lua tools/quality/arch.lua check`) instead of raw suite files; document one concrete runnable context for `guard` / `arch`; make this task the only one that rewrites plan structure and commands
- **validation**: plan text no longer references raw suite execution; runnable validation context is explicit; current baseline evidence includes `behavior` green and the current `guard` / `arch` precondition

### T1: Unify dirty bucket construction, merge, and reset
- **depends_on**: `[T0]`
- **location**: `src/core/utils/dirty_tracker.lua`, `src/state/state_access/landing_visual_hold.lua`
- **description**: Move duplicated dirty-bucket shape, merge, and reset logic behind `dirty_tracker`; replace `_new_dirty_bucket`, merge helpers, and reset sites in landing visual hold while preserving deferred dirty behavior
- **validation**: keep `dirty_tracker.consume()` snapshot semantics exactly, including `inventory_ids` reference/reset behavior; keep landing hold release/replay behavior unchanged

### T2: Centralize pure choice owner parsing
- **depends_on**: `[T0]`
- **location**: `src/core/choice/contract.lua`, `src/presentation/runtime/ports/ui_sync/choice_state.lua`, `src/ui/ctl/target_choice_effects.lua`, `src/turn/actions/validator.lua`
- **description**: Centralize field parsing for `owner_role_id` and `target_picker_owner_role_id` in `choice_contract`; outer layers keep their own current-player fallback; remove duplicated numeric parsing from presentation/UI/turn callers
- **validation**: preserve current-player fallback where explicit owner fields are absent; preserve permissive target-pick behavior when `actor_role_id` is missing and only reject mismatches when parsed actor id is non-nil

### T3: Centralize route and confirm metadata reads
- **depends_on**: `[T0]`
- **location**: `src/core/choice/route_policy.lua`, `src/ui/input/choice_route_policy.lua`, `src/ui/ctl/target_choice_effects.lua`
- **description**: Give `route_policy` one shared path for explicit `route_key` and `requires_confirm` extraction; keep the UI adapter file as a thin boundary alias; audit target-pick route checks so route semantics do not stay duplicated in UI code
- **validation**: preserve fallback warning text, `secondary_confirm` semantics, target-route detection, and UI boundary import path

### T4: Micro-clean `action_anim_port`
- **depends_on**: `[T0]`
- **location**: `src/core/ports/action_anim_port.lua`
- **description**: Simplify boolean/guard flow only; do not change asserts, nil handling, queue behavior, or return contract
- **validation**: missing `anim_gate_port` still asserts; disabled/no-queue paths still return `false`; successful queue still returns `true`

### T5: Consolidate intent dispatch side effects and intent-event emission
- **depends_on**: `[T2, T3]`
- **location**: `src/core/events/monopoly_events.lua`, `src/turn/output/intent_dispatcher.lua`
- **description**: Use shared route helpers and a single intent-event emission path in gameplay intent dispatch; preserve required-meta normalization/validation and owner backfill for market/item/landing choices
- **validation**: preserve side-effect order in `open_choice()` as `choice_seq` increment -> `pending_choice` assignment -> dirty flags -> log text -> event emission; preserve event names, payload keys, waiting-choice log text, and `owner_role_id` / `target_picker_owner_role_id` backfill

### T6: Serial evidence capture and plan closeout
- **depends_on**: `[T1, T2, T3, T4, T5]`
- **location**: `./.agents/plan.md`
- **description**: Append implementation evidence to the live-document sections (`进度`, `意外与发现`, `决策日志`, `结果与复盘`) after all code work lands; no structural rewrite here, only final evidence and outcome
- **validation**: plan reflects actual completed work, observed quirks, final decisions, and remaining gaps; final gates are recorded with pass/fail evidence

## Parallel Waves

- **Wave 1**: `T0`
- **Wave 2**: `T1`, `T2`, `T3`, `T4`
- **Wave 3**: `T5`
- **Wave 4**: `T6`

## Test Plan

- **Per-task checks**
  - `T1`: landing-hold dirty merge/release/runtime dirty tests
  - `T2`: presentation target-pick and owner-resolution tests plus validator actor-owner checks
  - `T3`: presentation route/confirm tests and target-route cases
  - `T4`: narrow runtime port contract covering `action_anim_port`
  - `T5`: gameplay intent dispatcher cases for route metadata, required meta errors, market/item/landing normalization, waiting-choice logs, and popup dispatch
- **Final gates**
  - `lua tests/behavior.lua`
  - `lua tests/contract.lua`
  - `lua tests/guard.lua`
  - `lua tools/quality/arch.lua check`

## Assumptions and Defaults

- No new library or framework dependency is introduced; Context7/web lookup is unnecessary for this plan because scope is internal repo code only
- `src/ui/input/choice_route_policy.lua` stays as a compatibility boundary even if it becomes thinner
- `choice_contract` stays pure and must not depend on `game`, `state`, or current-player lookup
- `.agents/plan.md` edits are serialized through `T0` and `T6` only to avoid swarm merge churn
- If `guard` / `arch` still cannot run in the agreed shell context, that is treated as a pre-existing validation-environment blocker to be documented in `T0`, not folded into the simplify refactor itself

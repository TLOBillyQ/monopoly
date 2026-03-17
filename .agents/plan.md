# Legacy Cleanup + Mutate Hardening

## Summary

This plan covers the two follow-up items you picked:

1. clean the remaining historical `release` / `vehicle` wording that is still only living in tests, docs, and helper-facing fixture text;
2. harden the mutate wrapper/driver surface so help text, accepted modes, and validation all match the current `dev|release` model.

This is intentionally **not** another vehicle-removal refactor. Any still-live compatibility shells or runtime bridge names stay in place unless they are only human-facing test/doc wording. No external dependency changes are involved, so no Context7 lookup is needed.

## Implementation Changes

### T1: Build a classified cleanup inventory
- **depends_on**: `[]`
- **location**: `tests/`, `docs/`, `scripts/quality/`, existing plan file for exclusion rules only
- **description**: Re-scan remaining legacy hits and classify each one into exactly one bucket: `rename`, `delete`, or `intentional_keep`. Search terms must include both symbol names and user-facing copy: `release_trimmed`, `MONO_REGRESSION_MODE`, `market_vehicle_replace`, `vehicle_enabled`, `vehicle replace`, `更换座驾`, `当前座驾`, `新座驾`.
- **validation**: Every repo-owned hit is assigned to a bucket, and the inventory explicitly excludes generated files and the plan file itself.
- **status**: Completed
- **log**: Classified remaining hits into three buckets: `rename` (`tests/suites/presentation/_presentation_action_status_choice_and_target_cases.lua`, `tests/suites/gameplay/gameplay_items_startup.lua`), `intentional_keep` (`src/rules/market/query/context.lua`, `src/rules/market/purchase/policy.lua`, `src/host/eggy/paid_purchase_gateway.lua`, `tests/guards/dep_rules.lua`, `tests/support/shared_support.lua`, `tests/support/test_env.lua`, `src/player/actions/state_ops/vehicle_ops.lua`), and `exclude_generated` (`scripts/quality/scrap/viewer/**`, `scripts/quality/arch/viewer/**`, `vendor/**`, this plan file). `scripts/data/export_xlsx.lua` keeps the `"更换座驾"` import key as an intentional spreadsheet-compatibility mapping.
- **files edited/created**: `.agents/plan.md`

### T2: Lock the mutate contract decision
- **depends_on**: `[]`
- **location**: `scripts/quality/mutate.lua`, `scripts/quality/mutate/driver.lua`, `docs/architecture/mutate4lua.md`, `docs/architecture/quality_map.md`
- **description**: Define one source-of-truth mutate contract:
  - wrapper syntax only accepts `--mode dev|release` when present;
  - behavior lane accepts `dev|release`;
  - contract lane runs in `dev` only;
  - `--lane contract --mode release` is rejected with a clear error instead of being silently normalized;
  - the same rule applies to `--index-suites`;
  - custom `--test-command` still passes through, but invalid mode syntax is rejected before execution.
- **validation**: The chosen behavior is written down once and all later code/tests/docs implement exactly that rule.
- **status**: Completed
- **log**: Locked the mutate contract to: wrapper/driver accept only `dev|release`; behavior lane accepts both; contract lane accepts only `dev`; explicit `release` for contract fails fast; the same rejection applies to wrapper `--index-suites`; invalid mode values fail before command execution.
- **files edited/created**: `.agents/plan.md`

### T3: Clean non-mutate historical wording
- **depends_on**: `[T1]`
- **location**: repo-owned tests/docs outside the mutate contract, especially `docs/reports/luarocks_busted_assessment.md`, `tests/catalog.lua`, `tests/suites/gameplay/gameplay_timeout_and_auto_runner.lua`, `tests/suites/presentation/_presentation_action_status_groups.lua`, `tests/suites/presentation/_presentation_action_status_choice_and_target_cases.lua`, `tests/suites/architecture/crap_contract.lua`
- **description**: Rename or rewrite stale `release_trimmed` and vehicle-era wording in tests/docs that are no longer tied to live behavior. Mutate-owned files are excluded from this task to avoid overlap with T4/T5. If a hit is only wording, rename it; if it is dead scaffolding, delete it; if it is a live compatibility contract, leave it unchanged.
- **validation**: Repo-owned non-mutate files no longer use stale mode wording or removed vehicle flow names/messages.
- **status**: Completed
- **log**: Cleaned residual non-mutate wording from docs/tests and renamed the remaining purchase-confirm fixture text so it no longer describes removed vehicle replacement behavior.
- **files edited/created**: `tests/suites/presentation/_presentation_action_status_choice_and_target_cases.lua`, `tests/suites/gameplay/gameplay_items_startup.lua`, `.agents/plan.md`

### T4: Harden mutate code paths
- **depends_on**: `[T2]`
- **location**: `scripts/quality/mutate.lua`, `scripts/quality/mutate/driver.lua`
- **description**: Implement the contract from T2 in code. Add explicit validation for missing mode values, invalid mode values, invalid lane values, contract-lane mode rejection, and `--index-suites` contract-mode rejection. Keep behavior-lane execution unchanged apart from clearer validation.
- **validation**: Wrapper/driver help and runtime behavior match T2, and invalid invocations fail with current wording.
- **status**: Completed
- **log**: Added explicit wrapper and driver validation for unsupported lanes/modes and for contract-lane `release` rejection. Help text now documents the actual supported contract.
- **files edited/created**: `scripts/quality/mutate.lua`, `scripts/quality/mutate/driver.lua`, `.agents/plan.md`

### T5: Align mutate docs and tests with the hardened contract
- **depends_on**: `[T2, T4]`
- **location**: `docs/architecture/mutate4lua.md`, `docs/architecture/quality_map.md`, `tests/suites/architecture/mutate4lua_contract.lua`, `tests/suites/architecture/mutate4lua_tooling_contract.lua`, `tests/suites/architecture/script_tools_contract.lua`
- **description**: Update all mutate-facing docs/tests to the new contract, including `--index-suites` behavior and contract-lane rejection rules. Do not leave any mutate-facing file still implying `release_trimmed` or silent contract-lane coercion.
- **validation**: All mutate-facing docs and tests describe the same `dev|release` model and the same contract-lane rule.
- **status**: Completed
- **log**: Updated mutate docs and architecture contracts to describe the explicit reject-fast contract, and added regression cases for invalid modes and contract-lane `release` rejections, including wrapper `--index-suites`.
- **files edited/created**: `docs/architecture/mutate4lua.md`, `docs/architecture/quality_map.md`, `tests/suites/architecture/mutate4lua_contract.lua`, `.agents/plan.md`

### T6: Run focused verification and close the inventory
- **depends_on**: `[T3, T5]`
- **location**: validation only
- **description**: Run the smallest complete proof set:
  - `lua tests/contract.lua`
  - `lua tests/tooling.lua --workers 1`
  - any touched behavior suites, or `lua tests/behavior.lua` if wording cleanup touched shared fixtures broadly
  - final grep with exact include/exclude rules.
  Grep exclusions must include at least `vendor/**`, `scripts/quality/scrap/viewer/**`, `scripts/quality/arch/viewer/**`, and `legacy-cleanup-and-mutate-hardening-plan.md`.
- **validation**: Tests pass, and final grep shows no repo-owned stale hits outside the explicit exclusion list.
- **status**: Completed
- **log**: Verified with `lua tests/contract.lua`, `lua tests/tooling.lua --workers 1`, and `lua tests/behavior.lua`. Final grep confirms only intentional compatibility names, generated viewer outputs, and this plan file still contain historical terms.
- **files edited/created**: `.agents/plan.md`

## Parallel Execution Groups

| Wave | Tasks | Can Start When |
|------|-------|----------------|
| 1 | T1, T2 | Immediately |
| 2 | T3, T4 | T1 complete for T3; T2 complete for T4 |
| 3 | T5 | T2 and T4 complete |
| 4 | T6 | T3 and T5 complete |

## Test Plan

- Mutate contract proof:
  - `lua tests/contract.lua`
  - `lua tests/tooling.lua --workers 1`
- Behavior proof:
  - run touched suites if edits stay local to wording-only tests;
  - otherwise run `lua tests/behavior.lua`
- Final grep proof:
  - include repo-owned `src/ tests/ docs/ scripts/quality/`
  - exclude `vendor/**`, generated viewer outputs, and the plan file itself
  - verify removal of stale terms and stale user-facing vehicle copy

## Assumptions

- Scope is limited to the two selected follow-ups, not a second vehicle retirement pass.
- Live compatibility names such as `vehicle_helper`, `vehicle_resync_seq`, or similar runtime-facing shells are kept unless T1 proves they are only dead wording.
- Mutate hardening chooses **explicit rejection** for `contract + release`, including `--index-suites`, instead of silent normalization.
- Generated viewer artifacts are not hand-edited; they are only regenerated later if their owning tooling is intentionally run.

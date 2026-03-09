# Test Reorg Inventory

Generated from the current worktree before the test reorganization cutover.

## Baseline

- `tests/` files: `56`
- `tests/suites/manifest.lua` modules: `38`
- Manifest-loaded suite cases: `471`
- `MONO_REGRESSION_MODE=release_trimmed lua tests/regression.lua`: `469`
- Guard scripts executed after suites: `5`

## Release Trimmed Hits

Current `tests/regression.lua` hardcodes four suite buckets, but only two entries actually match live case names:

- `suites.gameplay.gameplay_loop` / `gameplay.loop._test_action_button_timeout_auto_advances`
- `suites.presentation.presentation_ui_action_status` / `presentation_ui.action_status._test_status3d_priority_single_status`

The remaining hardcoded entries in `chance`, `config_sanity`, and one `gameplay.loop` case name are stale and should not be migrated blindly.

## Orphan Contract Suites

These suites exist on disk and pass local loading, but are not included in the current manifest:

- `suites.architecture.intent_output_contract` (`3` cases)
- `suites.runtime.narrow_runtime_ports_contract` (`6` cases)

## Compatibility References

Current repo references that must stay valid until the final cleanup wave:

- `require("TestSupport")` across most suites
- `require("TestHarness")` in ad hoc commands and docs
- `require("internal.dep_rules")`, `require("internal.forbidden_globals")`, `require("internal.legacy_path_guard")`
- Direct script execution via `tests/internal/*.lua`
- Legacy path snippets in `docs/architecture/arch_view.md`, `docs/architecture/boundaries.md`, `docs/architecture/layer-model.md`, and `docs/architecture/health_signals.md`

# Delete Config Compatibility Shells

## Summary

Retire both legacy config proxy namespaces in one pass: top-level `Config/` and `src/core/config/*`. After this change, `src/config/content/*`, `src/config/gameplay/*`, and `src/config/testing/*` are the only supported config entrypoints. The plan keeps non-config migration coverage intact, replaces config-specific old/new identity checks with explicit ban guards, and updates tooling so the default XLSX export path matches the canonical source tree.

## Interface Changes

- Retired require paths:
  - `Config.*`
  - `src.core.config.*`
- Supported require paths remain:
  - `src.config.content.*`
  - `src.config.gameplay.*`
  - `src.config.testing.*`
- Tooling behavior change:
  - `scripts/export_xlsx.lua` default output root changes from `Config/generated` to `src/config/content`
  - `--output-dir` override stays supported

## Tasks

### T0: Inventory remaining legacy config usage
- **depends_on**: []
- **location**: whole repo, especially `src/`, `tests/`, `scripts/`, `docs/`, `.agents/`
- **description**: Run a repo-wide scan for `require("Config...")`, `require('Config...')`, `require("src.core.config...")`, and direct path references like `Config/generated`, `Config/maps`, `Config/testing`, `Config/runtime_refs.lua`. Use this as the gating truth before deletion; the expected remaining hits are migration helpers, docs, and tooling only.
- **validation**: The scan produces a complete list of legacy references, and no runtime/gameplay/presentation module is left depending on either retired namespace.
- **status**: Completed
- **log**: Repo-wide grep confirmed no runtime/gameplay/presentation modules still import `Config.*` or `src.core.config.*`. Remaining hits are limited to the plan itself, migration helpers, `scripts/export_xlsx.lua`, `docs/eggy/guide/paid_currency.md`, and `.agents/research.md`.
- **files edited/created**: none

### T1: Redesign config migration safety net
- **depends_on**: [T0]
- **location**: `tests/support/migration_pairs.lua`, `tests/suites/architecture/migration_shim_contract.lua`, `tests/catalog.lua`, `tests/guards/dep_rules.lua`, `tests/guards/migration_shim_rules.lua`
- **description**: Remove `Config/*` and `src/core/config/*` pairs from migration-shim identity coverage while preserving all non-config migration pairs. Replace config compatibility expectations with ban-style protections: text guards that reject new legacy imports and one negative regression that proves a retired config require fails instead of silently resolving.
- **validation**: Contract coverage still exists for non-config migrations; guard lane fails on reintroduced `Config.*` or `src.core.config.*`; the negative regression confirms legacy config require paths no longer load.
- **status**: Completed
- **log**: Removed config shim pairs from `tests/support/migration_pairs.lua`, kept non-config migration coverage intact, added `dep_rules` bans for `Config.*` and `src.core.config.*` imports, and taught `migration_shim_contract` / `migration_shim_rules` to treat deleted config shims as retired rather than required compatibility aliases.
- **files edited/created**: `tests/support/migration_pairs.lua`, `tests/suites/architecture/migration_shim_contract.lua`, `tests/guards/dep_rules.lua`, `tests/guards/migration_shim_rules.lua`

### T2: Delete compatibility shell trees
- **depends_on**: [T1]
- **location**: `Config/`, `src/core/config/`
- **description**: Remove every pure forwarding Lua proxy under both trees and delete empty directories. Do not change canonical modules under `src/config/*`.
- **validation**: `Config/` and `src/core/config/` no longer contain Lua proxy files; canonical `src.config.*` requires still resolve.
- **status**: Completed
- **log**: Deleted the top-level `Config/` shim tree and the `src/core/config/` proxy tree so canonical `src.config.*` modules are the only remaining config entrypoints.
- **files edited/created**: deleted `Config/`, deleted `src/core/config/`

### T3: Update tooling and documentation to canonical paths
- **depends_on**: [T0]
- **location**: `scripts/export_xlsx.lua`, `docs/eggy/guide/paid_currency.md`, `.agents/research.md`, any additional hits from T0
- **description**: Change `export_xlsx` default output root to `src/config/content`, keep directory creation behavior intact, and preserve explicit `--output-dir` override. Update written guidance so market/map/runtime-ref references point at `src/config/*` instead of `Config/*`. Scrub any internal planning or automation notes that would otherwise revive the retired namespace.
- **validation**: Grep finds no intended references to retired config paths outside historical context; `scripts/export_xlsx.lua --help` and default-path behavior match the new canonical location.
- **status**: Completed
- **log**: Updated `scripts/export_xlsx.lua` to default to `src/config/content`, preserving `--output-dir` override and directory creation. Repointed paid-currency documentation and internal research notes from retired `Config/*` locations to canonical `src/config/*` paths.
- **files edited/created**: `scripts/export_xlsx.lua`, `docs/eggy/guide/paid_currency.md`, `.agents/research.md`

### T4: Regression and acceptance sweep
- **depends_on**: [T1, T2, T3]
- **location**: `tests/`, `scripts/`
- **description**: Run the architecture and regression lanes most likely to catch stale legacy imports, then run a lightweight require-level acceptance check proving canonical config modules load and retired ones fail.
- **validation**:
  - `lua tests/guard.lua`
  - `lua tests/contract.lua`
  - `lua scripts/arch.lua check`
  - `lua tests/behavior.lua`
  - a Lua smoke check that `pcall(require, "Config.generated.market")` and `pcall(require, "src.core.config.gameplay_rules")` fail, while canonical `src.config.content.market` and `src.config.gameplay.gameplay_rules` load successfully
- **status**: Completed
- **log**: Ran `lua tests/guard.lua`, `lua tests/contract.lua`, `lua scripts/arch.lua check`, and `lua tests/behavior.lua`, all passing after shim deletion. Added a Lua smoke check proving `Config.generated.market` and `src.core.config.gameplay_rules` now fail to resolve while canonical `src.config.content.market` and `src.config.gameplay.gameplay_rules` still load.
- **files edited/created**: none

## Parallel Execution Groups

| Wave | Tasks | Can Start When |
|------|-------|----------------|
| 1 | T0 | Immediately |
| 2 | T1, T3 | T0 complete |
| 3 | T2 | T1 complete |
| 4 | T4 | T1, T2, T3 complete |

## Test Plan

- Guard against reintroduction of retired config namespaces.
- Preserve non-config migration-shim coverage.
- Verify canonical `src.config.*` entrypoints still power runtime and tests.
- Prove behavior/contract/architecture lanes still pass after the shell deletion.
- Prove legacy requires fail fast instead of resolving through hidden proxies.

## Assumptions

- This change includes both shim layers by decision: `Config/` and `src/core/config/*`.
- Writing generated config into `src/config/content` is acceptable even though it updates versioned source files.
- Canonical config schemas and data shape stay unchanged; this is a path-retirement cleanup, not a config-format refactor.
- Other non-config migration shims remain in place and keep their existing contract coverage.
- Because this turn stays in Plan Mode, the plan is not written to disk now; when implementing outside Plan Mode, save it as `delete-config-compat-shell-plan.md`.

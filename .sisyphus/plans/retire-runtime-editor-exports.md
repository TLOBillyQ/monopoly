# Retire runtime_editor_exports

## TL;DR

> **Quick Summary**: Delete the dead `runtime_editor_exports.lua` module and remove all references across production code, tests, guard rules, and architecture config.
> 
> **Deliverables**:
> - `src/state/state_access/runtime_editor_exports.lua` deleted
> - `runtime_context.install_editor_exports` method removed from public API
> - 6 dead test functions and their suite registrations removed
> - Guard rules and arch config cleaned of stale entries
> 
> **Estimated Effort**: Quick
> **Parallel Execution**: NO — sequential (3 atomic commits)
> **Critical Path**: Task 1 → Task 2 → Task 3

---

## Context

### Original Request
User confirmed `runtime_editor_exports.lua` is no longer needed after a recent refactor. The entire module — including the `get_skin_id`, `get_change_skin_role`, and `get_camera_follow_creature` globals it installs — is dead code. The `runtime_context.install_editor_exports` wrapper should also be deleted entirely.

### Interview Summary
**Key Decisions**:
- Entire module is dead code — no behavior to preserve
- `install_editor_exports` on `runtime_context` should be deleted entirely (not stubbed or redirected)
- 3 camera target tests + 1 skin export test + forward-stop test + split-install test are all dead
- `vehicle_runtime_source.install_editor_exports` loses its only caller — intentionally dead

**Research Findings**:
- `_test_runtime_context_forward_stop_skips_invalid_role` is defined but never exported or registered in any suite — doubly dead
- `dep_rules.lua` has 4 entries (not 2) — 2 forbidden require patterns + 2 forbidden_files entries
- `change_skin_helper` / `camera_helper` context keys in shared_support must be KEPT — they are context objects, not editor exports

### Metis Review
**Identified Gaps** (addressed):
- `dep_rules.lua` L358 + L362 forbidden_files entries were missed initially → included in plan
- Forward-stop test has no export/case entry → only needs function definition deleted
- Risk of confusing `change_skin_helper` (alive) with `get_change_skin_role` (dead) → explicit MUST NOT guards added
- Line drift risk in multi-site edits → bottom-up editing order enforced

---

## Work Objectives

### Core Objective
Remove the dead `runtime_editor_exports` module and all its references from production code, tests, guards, and config.

### Concrete Deliverables
- `src/state/state_access/runtime_editor_exports.lua` — deleted
- `src/host/eggy/context.lua` — `require` removed, `install_editor_exports` method deleted, call in `install_globals` removed
- `src/app/bootstrap/runtime_install.lua` — `install_editor_exports` call removed
- `tests/suites/gameplay/gameplay_cases.lua` — 6 test function definitions deleted, 5 export entries removed, 3 sandbox keys removed
- `tests/suites/gameplay/gameplay_runtime_context_and_camera_sync.lua` — 5 `_case(...)` lines removed
- `tests/support/shared_support.lua` — 3 dead keys removed from `_RUNTIME_CONTEXT_KEYS`
- `tests/guards/dep_rules.lua` — 4 entries removed (2 forbidden patterns + 2 forbidden_files)
- `tools/quality/arch/config.json` — 1 match entry removed

### Definition of Done
- [ ] `grep -r "runtime_editor_exports" src/ tests/ tools/` → 0 results
- [ ] `grep -r "install_editor_exports" src/host/eggy/context.lua src/app/bootstrap/runtime_install.lua` → 0 results
- [ ] `grep -r "get_skin_id\|get_change_skin_role\|get_camera_follow_creature" tests/support/shared_support.lua tests/suites/gameplay/gameplay_cases.lua` → 0 results
- [ ] `python3 -c "import json; json.load(open('tools/quality/arch/config.json'))"` → valid JSON
- [ ] Full test suite passes

### Must Have
- All references to `runtime_editor_exports` removed from codebase
- All 6 dead test functions removed
- Guard rules and arch config cleaned

### Must NOT Have (Guardrails)
- MUST NOT touch `vehicle_runtime_source.lua` or `vehicle_runtime_legacy.lua`
- MUST NOT remove `change_skin_helper` or `camera_helper` from `_RUNTIME_CONTEXT_KEYS` (those are alive context objects)
- MUST NOT remove `get_vehicle_*` keys from `_with_runtime_context_globals` (those come from vehicle helper, not editor exports)
- MUST NOT leave trailing comma / syntax errors in Lua tables or JSON after deletions

---

## Verification Strategy

> **ZERO HUMAN INTERVENTION** — ALL verification is agent-executed.

### Test Decision
- **Infrastructure exists**: YES
- **Automated tests**: Tests-after (verify existing tests pass after deletion)
- **Framework**: `lua tests/regression.lua`

### QA Policy
Every task includes grep-based verification and test suite execution.

---

## Execution Strategy

### Sequential Execution (3 Atomic Commits)

```
Commit 1 — Production code cleanup:
└── Task 1: Delete module + remove production call sites [quick]

Commit 2 — Test cleanup:
└── Task 2: Delete 6 test functions + suite registrations + sandbox keys [quick]

Commit 3 — Config/guard cleanup:
└── Task 3: Clean dep_rules, arch config, shared_support [quick]
```

### Dependency Matrix
- **Task 1**: None → Task 2, Task 3
- **Task 2**: Task 1 → Task 3
- **Task 3**: Task 2 → (none)

### Agent Dispatch Summary
- **1**: **3 tasks** — All → `quick`

---

## TODOs

- [ ] 1. Remove dead production entrypoints and module file

  **What to do**:
  - Delete `src/state/state_access/runtime_editor_exports.lua`.
  - In `src/host/eggy/context.lua`, remove the `require("src.state.state_access.runtime_editor_exports")`, remove the `runtime_context.install_editor_exports(ctx)` call inside `install_globals`, and delete the `runtime_context.install_editor_exports` method entirely.
  - In `src/app/bootstrap/runtime_install.lua`, remove the `runtime_context.install_editor_exports(runtime_ctx)` call.
  - Keep all vehicle helper/runtime helper code untouched.

  **Must NOT do**:
  - Do not edit `src/state/state_access/vehicle_runtime_source.lua`.
  - Do not edit `src/host/eggy/vehicle_runtime_legacy.lua`.
  - Do not replace the deleted API with a stub or redirect.

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Small, mechanical deletion in 3 production files.
  - **Skills**: `[]`
  - **Skills Evaluated but Omitted**:
    - `clean-architecture-reviewer`: Boundary decision already made; this is direct retirement work.

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential
  - **Blocks**: Task 2, Task 3
  - **Blocked By**: None

  **References**:
  - `src/state/state_access/runtime_editor_exports.lua` - Dead module being retired; delete whole file.
  - `src/host/eggy/context.lua:4` - Dead `require` to remove.
  - `src/host/eggy/context.lua:183-188` - `install_globals` currently calls the dead wrapper; remove that call only.
  - `src/host/eggy/context.lua:248-251` - Public wrapper method to delete entirely.
  - `src/app/bootstrap/runtime_install.lua:28-33` - Bootstrap still invokes the dead API; remove this call.

  **Acceptance Criteria**:
  - [ ] `src/state/state_access/runtime_editor_exports.lua` no longer exists.
  - [ ] `grep -n "runtime_editor_exports" src/host/eggy/context.lua src/app/bootstrap/runtime_install.lua` returns no matches.
  - [ ] `grep -n "install_editor_exports" src/host/eggy/context.lua src/app/bootstrap/runtime_install.lua` returns no matches.

  **QA Scenarios**:

  ```
  Scenario: production references fully removed
    Tool: Bash (grep)
    Preconditions: Task 1 edits applied
    Steps:
      1. Run `grep -n "runtime_editor_exports\|install_editor_exports" src/host/eggy/context.lua src/app/bootstrap/runtime_install.lua`
      2. Confirm grep exits with status 1 and no matching lines are printed
      3. Run `test ! -f src/state/state_access/runtime_editor_exports.lua`
    Expected Result: No remaining production references and deleted file absent
    Failure Indicators: Any printed match line; deleted file still exists
    Evidence: .sisyphus/evidence/task-1-production-retirement.txt

  Scenario: unrelated vehicle runtime files remain untouched
    Tool: Bash (grep)
    Preconditions: Task 1 edits applied
    Steps:
      1. Run `grep -n "install_editor_exports" src/state/state_access/vehicle_runtime_source.lua src/host/eggy/vehicle_runtime_legacy.lua`
      2. Confirm matches still exist in these vehicle files
    Expected Result: Vehicle-side implementation files still contain their own editor export logic
    Failure Indicators: Accidental edits removed or changed those definitions
    Evidence: .sisyphus/evidence/task-1-vehicle-untouched.txt
  ```

  **Commit**: YES
  - Message: `refactor(state_access): retire dead runtime_editor_exports module`
  - Files: `src/state/state_access/runtime_editor_exports.lua`, `src/host/eggy/context.lua`, `src/app/bootstrap/runtime_install.lua`
  - Pre-commit: `grep -n "runtime_editor_exports\|install_editor_exports" src/host/eggy/context.lua src/app/bootstrap/runtime_install.lua`

- [ ] 2. Delete dead gameplay tests and suite registrations

  **What to do**:
  - In `tests/suites/gameplay/gameplay_cases.lua`, delete these dead function definitions in bottom-up order to avoid line drift:
    - `_test_runtime_context_change_skin_exports_and_event`
    - `_test_runtime_editor_exports_camera_target_returns_nil_when_unit_unavailable`
    - `_test_runtime_editor_exports_camera_target_returns_synthetic_actor_unit`
    - `_test_runtime_editor_exports_camera_target_returns_real_role_ctrl_unit`
    - `_test_runtime_context_split_install_stages`
    - `_test_runtime_context_forward_stop_skips_invalid_role`
  - In the same file, remove export-table entries for:
    - `_test_runtime_context_change_skin_exports_and_event`
    - `_test_runtime_context_split_install_stages`
    - `_test_runtime_editor_exports_camera_target_returns_real_role_ctrl_unit`
    - `_test_runtime_editor_exports_camera_target_returns_synthetic_actor_unit`
    - `_test_runtime_editor_exports_camera_target_returns_nil_when_unit_unavailable`
  - In `tests/suites/gameplay/gameplay_runtime_context_and_camera_sync.lua`, remove the 5 `_case(...)` registrations for split-install, the 3 camera tests, and the change-skin test.

  **Must NOT do**:
  - Do not delete `_test_runtime_context_release_helper_install_flow`.
  - Do not delete unrelated runtime-event or gameplay loop tests in the same suite.
  - Do not reorder surviving exported tests.

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Mechanical dead-test cleanup in two files.
  - **Skills**: `[]`
  - **Skills Evaluated but Omitted**:
    - `extract-legacy-test`: No replacement tests are needed; these tests are intentionally retired.

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential
  - **Blocks**: Task 3
  - **Blocked By**: Task 1

  **References**:
  - `tests/suites/gameplay/gameplay_cases.lua:1015` - Dead forward-stop test function; delete definition only.
  - `tests/suites/gameplay/gameplay_cases.lua:1110` - Dead split-install test function.
  - `tests/suites/gameplay/gameplay_cases.lua:1209-1307` - 3 dead camera follow export tests.
  - `tests/suites/gameplay/gameplay_cases.lua:3692-3727` - Dead skin export test.
  - `tests/suites/gameplay/gameplay_cases.lua:4972-4977` - Export table entries for dead tests.
  - `tests/suites/gameplay/gameplay_cases.lua:5066` - Export entry for change-skin test.
  - `tests/suites/gameplay/gameplay_runtime_context_and_camera_sync.lua:15-30` - Suite registrations to remove.

  **Acceptance Criteria**:
  - [ ] `grep -n "_test_runtime_context_forward_stop_skips_invalid_role\|_test_runtime_context_split_install_stages\|_test_runtime_editor_exports_camera_target_returns_real_role_ctrl_unit\|_test_runtime_editor_exports_camera_target_returns_synthetic_actor_unit\|_test_runtime_editor_exports_camera_target_returns_nil_when_unit_unavailable\|_test_runtime_context_change_skin_exports_and_event" tests/suites/gameplay/gameplay_cases.lua tests/suites/gameplay/gameplay_runtime_context_and_camera_sync.lua` returns no matches.
  - [ ] Remaining gameplay runtime-context suite still loads without missing-case errors.

  **QA Scenarios**:

  ```
  Scenario: dead gameplay cases are fully removed
    Tool: Bash (grep)
    Preconditions: Task 2 edits applied
    Steps:
      1. Run `grep -n "_test_runtime_context_forward_stop_skips_invalid_role\|_test_runtime_context_split_install_stages\|_test_runtime_editor_exports_camera_target_returns_real_role_ctrl_unit\|_test_runtime_editor_exports_camera_target_returns_synthetic_actor_unit\|_test_runtime_editor_exports_camera_target_returns_nil_when_unit_unavailable\|_test_runtime_context_change_skin_exports_and_event" tests/suites/gameplay/gameplay_cases.lua tests/suites/gameplay/gameplay_runtime_context_and_camera_sync.lua`
      2. Confirm grep exits with status 1 and prints nothing
    Expected Result: All six dead tests and all five suite/export registrations are gone
    Failure Indicators: Any matching function name remains in either file
    Evidence: .sisyphus/evidence/task-2-dead-tests-removed.txt

  Scenario: surviving suite wiring still parses cleanly
    Tool: Bash
    Preconditions: Task 2 edits applied
    Steps:
      1. Run `lua tests/regression.lua`
      2. Confirm there is no `missing gameplay case` assertion from `gameplay_runtime_context_and_camera_sync.lua`
    Expected Result: Suite registry only references existing gameplay cases
    Failure Indicators: `missing gameplay case` or Lua parse error in edited test files
    Evidence: .sisyphus/evidence/task-2-suite-load.txt
  ```

  **Commit**: YES
  - Message: `test: remove dead tests for retired runtime_editor_exports`
  - Files: `tests/suites/gameplay/gameplay_cases.lua`, `tests/suites/gameplay/gameplay_runtime_context_and_camera_sync.lua`
  - Pre-commit: `grep -n "_test_runtime_context_forward_stop_skips_invalid_role\|_test_runtime_context_split_install_stages\|_test_runtime_editor_exports_camera_target_returns_real_role_ctrl_unit\|_test_runtime_editor_exports_camera_target_returns_synthetic_actor_unit\|_test_runtime_editor_exports_camera_target_returns_nil_when_unit_unavailable\|_test_runtime_context_change_skin_exports_and_event" tests/suites/gameplay/gameplay_cases.lua tests/suites/gameplay/gameplay_runtime_context_and_camera_sync.lua`

- [ ] 3. Clean support globals, guard rules, and architecture config

  **What to do**:
  - In `tests/support/shared_support.lua`, remove `get_camera_follow_creature`, `get_skin_id`, and `get_change_skin_role` from `_RUNTIME_CONTEXT_KEYS`.
  - In `tests/suites/gameplay/gameplay_cases.lua`, remove the same 3 sandbox reset entries from `_with_runtime_context_globals`.
  - In `tests/guards/dep_rules.lua`, remove 4 stale references:
    - 2 forbidden `require(...)` patterns for `src.host.eggy.support.runtime_editor_exports`
    - `src/core/state_access/runtime_editor_exports.lua`
    - `src/host/eggy/support/runtime_editor_exports.lua`
  - In `tools/quality/arch/config.json`, remove `^src%.state%.state_access%.runtime_editor_exports$` from the `infrastructure_runtime_bridges` match list.
  - Validate Lua/JSON syntax after cleanup.

  **Must NOT do**:
  - Do not remove `change_skin_helper` or `camera_helper` from `_RUNTIME_CONTEXT_KEYS`.
  - Do not remove any `get_vehicle_*` sandbox entries.
  - Do not change unrelated guard rules.

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Small config/support cleanup with syntax validation.
  - **Skills**: `[]`
  - **Skills Evaluated but Omitted**:
    - `quality`: Heavy QA tooling is unnecessary for this narrow cleanup.

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential
  - **Blocks**: Final Verification Wave
  - **Blocked By**: Task 2

  **References**:
  - `tests/support/shared_support.lua:160-168` - `_RUNTIME_CONTEXT_KEYS`; remove only the 3 dead export keys.
  - `tests/suites/gameplay/gameplay_cases.lua:100-112` - Sandbox patch list; remove the same 3 dead globals for consistency.
  - `tests/guards/dep_rules.lua:121-124` - Stale forbidden require patterns.
  - `tests/guards/dep_rules.lua:357-362` - Stale forbidden_files entries; remove only runtime_editor_exports paths.
  - `tools/quality/arch/config.json:35-42` - Remove retired module from infrastructure bridge match list.

  **Acceptance Criteria**:
  - [ ] `grep -n "get_skin_id\|get_change_skin_role\|get_camera_follow_creature" tests/support/shared_support.lua tests/suites/gameplay/gameplay_cases.lua` returns no matches.
  - [ ] `grep -n "runtime_editor_exports" tests/guards/dep_rules.lua tools/quality/arch/config.json` returns no matches.
  - [ ] `python3 -c "import json; json.load(open('tools/quality/arch/config.json'))"` succeeds.
  - [ ] Edited Lua support/guard files parse under the project test runner.

  **QA Scenarios**:

  ```
  Scenario: support and guard references fully cleaned
    Tool: Bash (grep)
    Preconditions: Task 3 edits applied
    Steps:
      1. Run `grep -n "get_skin_id\|get_change_skin_role\|get_camera_follow_creature" tests/support/shared_support.lua tests/suites/gameplay/gameplay_cases.lua`
      2. Confirm grep exits with status 1
      3. Run `grep -n "runtime_editor_exports" tests/guards/dep_rules.lua tools/quality/arch/config.json`
      4. Confirm grep exits with status 1
    Expected Result: No stale support, guard, or config references remain
    Failure Indicators: Any remaining key or stale module path
    Evidence: .sisyphus/evidence/task-3-cleanup-grep.txt

  Scenario: config and guard files remain syntactically valid
    Tool: Bash
    Preconditions: Task 3 edits applied
    Steps:
      1. Run `python3 -c "import json; json.load(open('tools/quality/arch/config.json'))"`
      2. Run `lua tests/regression.lua`
      3. Confirm both commands succeed with exit code 0
    Expected Result: JSON valid and Lua guard file accepted by the existing test harness
    Failure Indicators: JSONDecodeError, Lua parse error, or test harness failure
    Evidence: .sisyphus/evidence/task-3-syntax-validation.txt
  ```

  **Commit**: YES
  - Message: `chore: clean guard rules and arch config for retired module`
  - Files: `tests/support/shared_support.lua`, `tests/suites/gameplay/gameplay_cases.lua`, `tests/guards/dep_rules.lua`, `tools/quality/arch/config.json`
  - Pre-commit: `python3 -c "import json; json.load(open('tools/quality/arch/config.json'))"`

---

## Final Verification Wave

> After ALL tasks, run a single comprehensive verification pass.

- [ ] F1. **Codebase Sweep** — `quick`
  Run `grep -r "runtime_editor_exports" src/ tests/ tools/` — expect 0 results.
  Run `grep -r "install_editor_exports" src/host/eggy/context.lua src/app/bootstrap/runtime_install.lua` — expect 0 results.
  Run `grep -r "get_skin_id\|get_change_skin_role\|get_camera_follow_creature" tests/support/shared_support.lua tests/suites/gameplay/gameplay_cases.lua` — expect 0 results.
  Verify `tools/quality/arch/config.json` is valid JSON.
  Run `lua tests/regression.lua` — expect all pass.

---

## Commit Strategy

- **Commit 1**: `refactor(state_access): retire dead runtime_editor_exports module` — delete file + edit context.lua + edit runtime_install.lua
- **Commit 2**: `test: remove dead tests for retired runtime_editor_exports` — edit gameplay_cases.lua + edit suite file
- **Commit 3**: `chore: clean guard rules and arch config for retired module` — edit dep_rules.lua + config.json + shared_support.lua + gameplay_cases.lua sandbox keys

---

## Success Criteria

### Verification Commands
```bash
grep -r "runtime_editor_exports" src/ tests/ tools/  # Expected: 0 results
grep -r "install_editor_exports" src/host/eggy/context.lua src/app/bootstrap/runtime_install.lua  # Expected: 0 results
python3 -c "import json; json.load(open('tools/quality/arch/config.json'))"  # Expected: no error
lua tests/regression.lua  # Expected: all behavior/contract/guard lanes pass
```

### Final Checklist
- [ ] All "Must Have" present
- [ ] All "Must NOT Have" absent
- [ ] All tests pass

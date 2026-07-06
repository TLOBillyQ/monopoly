# SwarmForge Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align local `swarmforge/` with upstream `unclebob/swarm-forge` structure by replacing vendored shared scripts with upstream `main` versions, removing duplicate constitution articles, and removing the deprecated `awake` handoff type.

**Architecture:** Adopt upstream's Babashka-based operational scripts (`swarmforge.bb` + thin `swarmforge.sh` wrapper), while keeping project-specific overrides (`engineering.prompt`, `project.prompt`, Lua tool constitution, Claude backend, `otty.sh` terminal adapter).

**Tech Stack:** Bash, zsh, Babashka (`bb`), git, tmux.

## Global Constraints

- Do not modify `src/`, `spec/`, `tools/` business logic, or `features/`.
- Keep agent backend as `claude` in `swarmforge/swarmforge.conf`.
- Keep Lua 5.4 / busted as the project language.
- Preserve `swarmforge/constitution/tools/` and `swarmforge/tools.lock`.
- Preserve `swarmforge/scripts/terminal-adapters/otty.sh`.
- All shared operational scripts must come from `unclebob/swarm-forge:main`.
- All runnable-branch config (`swarmforge.conf`, `constitution.prompt`, `project.prompt`, role prompts) must match upstream `unclebob/swarm-forge:four-pack` except for local overrides.
- Remove all `awake` handoff rules and references.

---

## File Structure

### After alignment

```text
swarm
swarmforge/
  README.md
  swarmforge.conf
  constitution.prompt
  handoff-protocol.md
  constitution/
    articles/
      project.prompt
      engineering.prompt        # local full override
    tools/
      mutate4lua.prompt
      dry4lua.prompt
      crap4lua.prompt
      arch_view.prompt
      acceptance4lua.prompt
  scripts/                      # installed from upstream main by ./swarm
    swarmforge.sh               # 5-line wrapper
    swarmforge.bb
    handoff_lib.bb
    handoffd.bb
    swarm_handoff.bb
    swarm_handoff.sh
    ready_for_next.sh
    ready_for_next.bb
    ready_for_next_task.sh
    ready_for_next_task.bb
    ready_for_next_batch.sh
    ready_for_next_batch.bb
    done_with_current.sh
    done_with_current.bb
    done_with_current_task.sh
    done_with_current_task.bb
    done_with_current_batch.sh
    done_with_current_batch.bb
    swarm-cleanup.sh
    swarm-terminal-adapter.sh
    swarm-window-watchdog.bb
    swarm-window-watchdog.sh
    stop_handoff_daemon.bb
    stop_handoff_daemon.sh
    handoffd.bb
    terminal-adapters/
      ghostty.sh
      iterm2.sh
      none.sh
      terminal-app.sh
      windows-terminal.sh
      otty.sh                   # local extension
```

---

## Upstream Source Reference

All upstream files come from a local clone at `/Users/billyq/Dev/ai/unclebob/swarm-forge/`. If that path is unavailable, replace commands with GitHub raw URLs, e.g.:

```text
https://raw.githubusercontent.com/unclebob/swarm-forge/main/swarmforge/scripts/swarmforge.bb
```

Set the variable once:

```bash
UPSTREAM=/Users/billyq/Dev/ai/unclebob/swarm-forge
```

---

## Task 1: Prepare Branch and Record Baseline

**Files:**
- Modify: none
- Create: `docs/superpowers/plans/baseline-files.txt` (temporary, can be deleted after)

**Interfaces:**
- Consumes: current working tree
- Produces: clean feature branch + baseline file list

- [ ] **Step 1: Create and switch to feature branch**

```bash
cd /Users/billyq/Dev/work/monopoly
git checkout -b swarmforge-alignment
```

Expected: branch created and checked out.

- [ ] **Step 2: Record baseline file list**

```bash
cd /Users/billyq/Dev/work/monopoly
find swarmforge -type f | sort > docs/superpowers/plans/baseline-files.txt
git status --short >> docs/superpowers/plans/baseline-files.txt
```

Expected: `docs/superpowers/plans/baseline-files.txt` contains all current `swarmforge/` files and a clean git status.

- [ ] **Step 3: Commit baseline marker**

```bash
cd /Users/billyq/Dev/work/monopoly
git add docs/superpowers/plans/baseline-files.txt
git commit -m "chore(swarmforge): record baseline before upstream alignment

By architect."
```

Expected: baseline commit exists.

---

## Task 2: Remove Vendored and Duplicate Files

**Files:**
- Delete: `swarmforge/scripts/shared-articles/engineering.prompt`
- Delete: `swarmforge/scripts/shared-articles/handoffs.prompt`
- Delete: `swarmforge/scripts/shared-articles/workflow.prompt`
- Delete: `swarmforge/scripts/shared-articles/` directory
- Delete: `swarmforge/constitution/articles/workflow.prompt`
- Delete: `swarmforge/constitution/articles/handoffs.prompt`

**Interfaces:**
- Consumes: baseline file tree
- Produces: `swarmforge/` tree with only project-specific overrides in `constitution/articles/`

- [ ] **Step 1: Remove vendored shared articles**

```bash
cd /Users/billyq/Dev/work/monopoly
rm -rf swarmforge/scripts/shared-articles
```

Expected: `swarmforge/scripts/shared-articles/` no longer exists.

- [ ] **Step 2: Remove duplicate constitution articles**

```bash
cd /Users/billyq/Dev/work/monopoly
rm -f swarmforge/constitution/articles/workflow.prompt
rm -f swarmforge/constitution/articles/handoffs.prompt
```

Expected: `swarmforge/constitution/articles/` contains only `project.prompt` and `engineering.prompt`.

- [ ] **Step 3: Verify remaining articles**

```bash
cd /Users/billyq/Dev/work/monopoly
ls swarmforge/constitution/articles/
```

Expected output:

```text
engineering.prompt
project.prompt
```

- [ ] **Step 4: Commit removals**

```bash
cd /Users/billyq/Dev/work/monopoly
git add -A swarmforge
git commit -m "chore(swarmforge): remove vendored shared articles and duplicate constitution files

By architect."
```

Expected: commit succeeds.

---

## Task 3: Replace Operational Scripts with Upstream Main Versions

**Files:**
- Modify: `swarmforge/scripts/swarmforge.sh`
- Modify: `swarmforge/scripts/handoffd.bb`
- Modify: `swarmforge/scripts/swarm_handoff.bb`
- Modify: `swarmforge/scripts/swarm-window-watchdog.sh`
- Create: `swarmforge/scripts/swarmforge.bb`
- Create: `swarmforge/scripts/handoff_lib.bb`
- Create: `swarmforge/scripts/stop_handoff_daemon.bb`
- Create: `swarmforge/scripts/stop_handoff_daemon.sh`
- Create: `swarmforge/scripts/terminal-adapters/iterm2.sh`
- Delete: `swarmforge/scripts/handoff-lib.sh`

**Interfaces:**
- Consumes: upstream `main` script files
- Produces: local `swarmforge/scripts/` aligned with upstream main

- [ ] **Step 1: Copy core Babashka scripts from upstream main**

```bash
cd /Users/billyq/Dev/work/monopoly
UPSTREAM=/Users/billyq/Dev/ai/unclebob/swarm-forge
git -C "$UPSTREAM" show main:swarmforge/scripts/swarmforge.sh > swarmforge/scripts/swarmforge.sh
git -C "$UPSTREAM" show main:swarmforge/scripts/swarmforge.bb > swarmforge/scripts/swarmforge.bb
git -C "$UPSTREAM" show main:swarmforge/scripts/handoff_lib.bb > swarmforge/scripts/handoff_lib.bb
git -C "$UPSTREAM" show main:swarmforge/scripts/handoffd.bb > swarmforge/scripts/handoffd.bb
git -C "$UPSTREAM" show main:swarmforge/scripts/swarm_handoff.bb > swarmforge/scripts/swarm_handoff.bb
```

Expected: files are written and non-empty.

- [ ] **Step 2: Copy handoff lifecycle scripts from upstream main**

```bash
cd /Users/billyq/Dev/work/monopoly
UPSTREAM=/Users/billyq/Dev/ai/unclebob/swarm-forge
for name in ready_for_next ready_for_next_task ready_for_next_batch done_with_current done_with_current_task done_with_current_batch; do
  git -C "$UPSTREAM" show main:swarmforge/scripts/${name}.sh > swarmforge/scripts/${name}.sh
  git -C "$UPSTREAM" show main:swarmforge/scripts/${name}.bb > swarmforge/scripts/${name}.bb
done
```

Expected: six `.sh` and six `.bb` files are updated/created.

- [ ] **Step 3: Copy swarm wrapper and helper scripts from upstream main**

```bash
cd /Users/billyq/Dev/work/monopoly
UPSTREAM=/Users/billyq/Dev/ai/unclebob/swarm-forge
git -C "$UPSTREAM" show main:swarmforge/scripts/swarm_handoff.sh > swarmforge/scripts/swarm_handoff.sh
git -C "$UPSTREAM" show main:swarmforge/scripts/swarm-cleanup.sh > swarmforge/scripts/swarm-cleanup.sh
git -C "$UPSTREAM" show main:swarmforge/scripts/swarm-terminal-adapter.sh > swarmforge/scripts/swarm-terminal-adapter.sh
git -C "$UPSTREAM" show main:swarmforge/scripts/swarm-window-watchdog.sh > swarmforge/scripts/swarm-window-watchdog.sh
git -C "$UPSTREAM" show main:swarmforge/scripts/swarm-window-watchdog.bb > swarmforge/scripts/swarm-window-watchdog.bb
git -C "$UPSTREAM" show main:swarmforge/scripts/stop_handoff_daemon.sh > swarmforge/scripts/stop_handoff_daemon.sh
git -C "$UPSTREAM" show main:swarmforge/scripts/stop_handoff_daemon.bb > swarmforge/scripts/stop_handoff_daemon.bb
```

Expected: all files updated.

- [ ] **Step 4: Delete replaced shell library**

```bash
cd /Users/billyq/Dev/work/monopoly
rm -f swarmforge/scripts/handoff-lib.sh
```

Expected: `handoff-lib.sh` no longer exists.

- [ ] **Step 5: Copy terminal adapters from upstream main, keep otty.sh**

```bash
cd /Users/billyq/Dev/work/monopoly
UPSTREAM=/Users/billyq/Dev/ai/unclebob/swarm-forge
for name in ghostty iterm2 none terminal-app windows-terminal; do
  git -C "$UPSTREAM" show main:swarmforge/scripts/terminal-adapters/${name}.sh > swarmforge/scripts/terminal-adapters/${name}.sh
done
```

Expected: `iterm2.sh` is added; `ghostty.sh`, `none.sh`, `terminal-app.sh`, `windows-terminal.sh` are updated; `otty.sh` remains untouched.

- [ ] **Step 6: Make scripts executable**

```bash
cd /Users/billyq/Dev/work/monopoly
chmod +x swarmforge/scripts/*.sh swarmforge/scripts/*.bb swarmforge/scripts/terminal-adapters/*.sh
```

Expected: all `.sh` and `.bb` files in `swarmforge/scripts/` are executable.

- [ ] **Step 7: Verify script inventory**

```bash
cd /Users/billyq/Dev/work/monopoly
UPSTREAM=/Users/billyq/Dev/ai/unclebob/swarm-forge
git -C "$UPSTREAM" ls-tree -r --name-only main | grep '^swarmforge/scripts/' | sed 's|swarmforge/scripts/||' | sort > /tmp/upstream_scripts.txt
find swarmforge/scripts -type f | sed 's|swarmforge/scripts/||' | sort > /tmp/local_scripts.txt
echo "Only in upstream:" && comm -23 /tmp/upstream_scripts.txt /tmp/local_scripts.txt
echo "Only in local:" && comm -13 /tmp/upstream_scripts.txt /tmp/local_scripts.txt
```

Expected: "Only in local" should show only `terminal-adapters/otty.sh`. "Only in upstream" should be empty.

- [ ] **Step 8: Commit script replacement**

```bash
cd /Users/billyq/Dev/work/monopoly
git add -A swarmforge/scripts
git commit -m "chore(swarmforge): replace operational scripts with upstream main versions

By architect."
```

Expected: commit succeeds.

---

## Task 4: Add Missing Protocol and Project Documentation

**Files:**
- Create: `swarmforge/handoff-protocol.md`
- Create: `swarmforge/README.md`

**Interfaces:**
- Consumes: upstream `main` handoff-protocol.md
- Produces: local SwarmForge docs

- [ ] **Step 1: Copy handoff protocol from upstream main**

```bash
cd /Users/billyq/Dev/work/monopoly
UPSTREAM=/Users/billyq/Dev/ai/unclebob/swarm-forge
git -C "$UPSTREAM" show main:swarmforge/handoff-protocol.md > swarmforge/handoff-protocol.md
```

Expected: `swarmforge/handoff-protocol.md` exists and is non-empty.

- [ ] **Step 2: Create project-specific README**

Create `swarmforge/README.md` with the following content:

```markdown
# SwarmForge Configuration

This project uses a four-pack SwarmForge workflow with Claude-backed agents.

## Layout

- `swarmforge.conf` — four roles: specifier, coder, refactorer, architect.
- `constitution.prompt` — loads articles and tool prompts.
- `constitution/articles/project.prompt` — project shape and local topology.
- `constitution/articles/engineering.prompt` — Lua 5.4 / busted specific engineering rules (full override of shared article).
- `constitution/tools/` — Lua quality tool prompts (mutate4lua, dry4lua, crap4lua, arch_view, acceptance4lua).
- `roles/*.prompt` — per-role instructions.
- `scripts/` — operational scripts, installed from `unclebob/swarm-forge/main` by `./swarm` on first run.

## Starting the swarm

```bash
./swarm
```

Shared scripts and constitution articles are downloaded from `unclebob/swarm-forge/main` if `swarmforge/scripts/` is missing.

## Local extensions

- Agent backend: `claude`.
- Terminal backend: `otty.sh` in addition to upstream adapters.
```

Expected: file is created with the content above.

- [ ] **Step 3: Commit documentation**

```bash
cd /Users/billyq/Dev/work/monopoly
git add swarmforge/handoff-protocol.md swarmforge/README.md
git commit -m "docs(swarmforge): add handoff protocol and project README

By architect."
```

Expected: commit succeeds.

---

## Task 5: Verify Clean-Directory `./swarm` Bootstrap

**Files:**
- Test: temporary clone or clean directory

**Interfaces:**
- Consumes: `swarm` wrapper + `swarmforge/` config
- Produces: confirmation that `./swarm` downloads shared scripts and installs shared articles

- [ ] **Step 1: Create a temporary clean clone**

```bash
mkdir -p /tmp/swarmforge-alignment-test
cd /tmp/swarmforge-alignment-test
git clone --branch swarmforge-alignment --single-branch /Users/billyq/Dev/work/monopoly project
cd project
```

Expected: clean clone on the feature branch.

- [ ] **Step 2: Remove any cached scripts to force bootstrap**

```bash
cd /tmp/swarmforge-alignment-test/project
rm -rf swarmforge/scripts/.swarmforge .swarmforge .worktrees
```

Expected: `swarmforge/scripts/` still exists (it is committed now), but shared-articles and runtime state are gone.

- [ ] **Step 3: Inspect `./swarm` bootstrap logic**

```bash
cd /tmp/swarmforge-alignment-test/project
head -30 swarm
```

Expected: `./swarm` checks for `swarmforge/scripts` and `swarmforge/scripts/shared-articles`, downloads from upstream if missing.

- [ ] **Step 4: Simulate bootstrap by checking download URL**

```bash
cd /tmp/swarmforge-alignment-test/project
curl -L -I "https://github.com/unclebob/swarm-forge/archive/refs/heads/main.tar.gz" 2>/dev/null | head -5
```

Expected: HTTP 302/200 response.

- [ ] **Step 5: Clean up temporary clone**

```bash
rm -rf /tmp/swarmforge-alignment-test
```

Expected: temp directory removed.

---

## Task 6: Verify Handoff Type Validation (No `awake`)

**Files:**
- Test: temporary draft handoff file

**Interfaces:**
- Consumes: `swarmforge/scripts/swarm_handoff.bb`
- Produces: confirmation that `awake` is rejected and `git_handoff` is accepted

- [ ] **Step 1: Confirm `awake` is not in allowed types**

```bash
cd /Users/billyq/Dev/work/monopoly
grep -n 'allowed-types' swarmforge/scripts/swarm_handoff.bb
```

Expected output contains only `#{"git_handoff" "note"}` (no `awake`).

- [ ] **Step 2: Create a test `awake` draft and expect rejection**

```bash
cd /Users/billyq/Dev/work/monopoly
cat > /tmp/awake-draft.txt <<'EOF'
type: awake
to: specifier
priority: 50
EOF
swarmforge/scripts/swarm_handoff.sh /tmp/awake-draft.txt 2>&1 || true
```

Expected: error output includes "Header 'type' must be one of git_handoff or note".

- [ ] **Step 3: Create a test `git_handoff` draft and expect validation**

```bash
cd /Users/billyq/Dev/work/monopoly
# Use a known commit in the repo
COMMIT=$(git rev-parse --short=10 HEAD)
cat > /tmp/git-draft.txt <<EOF
type: git_handoff
to: coder
priority: 10
task: test-alignment
commit: ${COMMIT}
EOF
swarmforge/scripts/swarm_handoff.sh /tmp/git-draft.txt 2>&1
```

Expected: validation succeeds (or complains about missing daemon/inbox, but not about type). The script may report that inboxes are missing because `.swarmforge` state is not initialized; that is acceptable for this step.

- [ ] **Step 4: Clean up draft files**

```bash
rm -f /tmp/awake-draft.txt /tmp/git-draft.txt
```

Expected: temp files removed.

---

## Task 7: Final Review and Mark Complete

**Files:**
- Review: `docs/superpowers/specs/2026-07-06-swarmforge-alignment-design.md`
- Review: full git diff on feature branch

**Interfaces:**
- Consumes: all previous task outputs
- Produces: approval-ready branch

- [ ] **Step 1: Show high-level diff stats**

```bash
cd /Users/billyq/Dev/work/monopoly
git diff --stat main -- swarmforge/ swarm
```

Expected: diff shows deletions of vendored files, additions of upstream scripts, and documentation files.

- [ ] **Step 2: Confirm no business code changed**

```bash
cd /Users/billyq/Dev/work/monopoly
git diff --name-only main -- | grep -E '^(src/|spec/|tools/|features/)' && echo "UNEXPECTED BUSINESS CODE CHANGED" || echo "No business code changed"
```

Expected: "No business code changed".

- [ ] **Step 3: Run project verification lane**

```bash
cd /Users/billyq/Dev/work/monopoly
make test
```

Expected: behavior smoke tests pass (this plan does not touch business code; failures here indicate pre-existing issues).

- [ ] **Step 4: Mark plan complete**

No file change. The branch `swarmforge-alignment` is ready for handoff to the user.

---

## Self-Review Checklist

1. **Spec coverage:**
   - Remove vendored `shared-articles/` → Task 2.
   - Remove duplicate `workflow.prompt` and `handoffs.prompt` → Task 2.
   - Replace operational scripts with upstream main versions → Task 3.
   - Add `swarmforge/handoff-protocol.md` → Task 4.
   - Add `swarmforge/README.md` → Task 4.
   - Remove `awake` support → Task 6 verification.
   - Keep `engineering.prompt`, `project.prompt`, `constitution/tools/`, `tools.lock`, `otty.sh` → preserved throughout.

2. **Placeholder scan:**
   - No "TBD", "TODO", "implement later", or vague instructions.

3. **Type consistency:**
   - Shell commands use consistent paths (`/Users/billyq/Dev/work/monopoly` and `/Users/billyq/Dev/ai/unclebob/swarm-forge`).
   - All upstream file references use `git -C "$UPSTREAM" show main:...`.

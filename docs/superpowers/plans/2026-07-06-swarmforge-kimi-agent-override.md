# SwarmForge Kimi Backend & CLI Agent Override Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Kimi as a supported SwarmForge agent backend and enable `./swarm [agent] [directory]` one-time agent override.

**Architecture:** Extend `swarmforge/scripts/swarmforge.bb` with a `kimi` branch in `launch-command`, a `kimi-prompt-injector.sh` helper, and CLI argument parsing; keep changes minimal and inline per the approved design.

**Tech Stack:** Babashka, zsh, tmux, Kimi Code CLI

## Global Constraints

- Agent whitelist: `#{"claude" "codex" "copilot" "grok" "kimi"}`.
- CLI syntax: `./swarm [agent] [directory]`; one-time override, no `swarmforge.conf` mutation.
- Kimi launch mode: interactive `kimi --yolo --add-dir <worktree>` + prompt injector.
- Do not abstract a generic agent adapter layer.
- Do not modify `swarmforge.conf`, role prompts, handoff protocol, terminal adapters, or business code.
- Follow existing `swarmforge.bb` naming and indentation style.

---

## File Structure

| File | Responsibility |
| --- | --- |
| `swarmforge/scripts/swarmforge.bb` | Parse config/CLI, build launch commands, schedule Kimi prompt injection, check dependencies. |
| `swarmforge/scripts/kimi-prompt-injector.sh` | Wait for Kimi TUI readiness, then inject `prompts/<role>.md` into the tmux pane. |
| `swarmforge/README.md` | Document new Kimi support and CLI override examples. |

---

### Task 1: Extend Agent Whitelist and Required Helpers

**Files:**
- Modify: `swarmforge/scripts/swarmforge.bb:169`
- Test: `swarmforge/scripts/swarmforge.bb` via `bb --test-parse`

**Interfaces:**
- Consumes: existing `parse-config`.
- Produces: `"kimi"` accepted as valid agent.

- [ ] **Step 1: Add `"kimi"` to the agent whitelist**

  In `swarmforge/scripts/swarmforge.bb`, locate:

  ```clojure
  (when-not (#{"claude" "codex" "copilot" "grok"} agent)
    (fail! (str red "Error:" reset " Unsupported agent '" agent "' for role '" role "'")))
  ```

  Change to:

  ```clojure
  (when-not (#{"claude" "codex" "copilot" "grok" "kimi"} agent)
    (fail! (str red "Error:" reset " Unsupported agent '" agent "' for role '" role "'")))
  ```

- [ ] **Step 2: Verify Kimi is accepted in config parsing**

  Temporarily edit `swarmforge/swarmforge.conf` so at least one line uses `kimi`, e.g.:

  ```text
  window specifier kimi master
  window coder claude coder
  window refactorer claude refactorer
  window architect claude architect batch
  ```

  Run:

  ```bash
  bb swarmforge/scripts/swarmforge.bb --test-parse
  ```

  Expected: no `Unsupported agent` error; output shows specifier row with `kimi`.

- [ ] **Step 3: Restore `swarmforge.conf`**

  Revert the temporary change so all roles use `claude` again.

- [ ] **Step 4: Commit**

  ```bash
  git add swarmforge/scripts/swarmforge.bb
  git commit -m "feat(swarmforge): accept kimi in agent whitelist"
  ```

---

### Task 2: Implement Kimi Launch Command Branch

**Files:**
- Modify: `swarmforge/scripts/swarmforge.bb:323-349` (`launch-command`)
- Test: `swarmforge/scripts/swarmforge.bb` via `bb --test-launch-command`

**Interfaces:**
- Consumes: `role-worktree`, `extra-args` from the role row; `sq` helper.
- Produces: a `"kimi"` branch in the `case` expression of `launch-command`.

- [ ] **Step 1: Add the Kimi branch to `launch-command`**

  In `swarmforge/scripts/swarmforge.bb`, locate the `case agent` expression inside `launch-command`:

  ```clojure
  (cond-> (str base
              (case agent
                "claude" (str "claude --append-system-prompt-file " ...)
                "codex"  (str "codex -C " ...)
                "copilot" (str "copilot -C " ...)
                "grok"   (str "grok --cwd " ...)))
  ```

  Insert a `"kimi"` branch before the closing `))`:

  ```clojure
  "kimi" (str "kimi --yolo --add-dir " (sq (str role-worktree))
              (when (seq (:extra-args row)) (str " " (:extra-args row))))
  ```

  The full `case` block should look like:

  ```clojure
  (case agent
    "claude" (str "claude --append-system-prompt-file " (sq (str prompt-file)) " --permission-mode acceptEdits -n " (sq (str "SwarmForge " display)) " " (extra-args-prefix row) "\"$(cat " (sq (str prompt-file)) ")\"")
    "codex" (str "codex -C " (sq (str role-worktree)) " " (extra-args-prefix row) "\"$(cat " (sq (str prompt-file)) ")\"")
    "kimi" (str "kimi --yolo --add-dir " (sq (str role-worktree))
                (when (seq (:extra-args row)) (str " " (:extra-args row))))
    "copilot" (str "copilot -C " (sq (str role-worktree)) " --name " (sq (str "SwarmForge " display)) " " (extra-args-prefix row) "-i \"$(cat " (sq (str prompt-file)) ")\"")
    "grok" (str "grok --cwd " (sq (str role-worktree)) " --permission-mode acceptEdits " (extra-args-prefix row) "--rules \"$(cat " (sq (str prompt-file)) ")\" --verbatim \"$(cat " (sq (str prompt-file)) ")\""))
  ```

- [ ] **Step 2: Verify the generated launch command**

  Run:

  ```bash
  bb swarmforge/scripts/swarmforge.bb --test-launch-command . kimi
  ```

  Expected output contains:

  ```text
  kimi --yolo --add-dir '/Users/billyq/Dev/work/monopoly'
  ```

  (The exact path depends on the current working directory.)

- [ ] **Step 3: Verify extra-args are appended**

  Run:

  ```bash
  bb swarmforge/scripts/swarmforge.bb --test-launch-command . kimi "--model k1.5"
  ```

  Expected output contains `--model k1.5` after `--add-dir ...`.

- [ ] **Step 4: Commit**

  ```bash
  git add swarmforge/scripts/swarmforge.bb
  git commit -m "feat(swarmforge): add kimi launch command branch"
  ```

---

### Task 3: Create the Kimi Prompt Injector Script

**Files:**
- Create: `swarmforge/scripts/kimi-prompt-injector.sh`
- Test: manual tmux test

**Interfaces:**
- Consumes: tmux socket path, tmux target (`session:window.pane`), prompt file path, optional delay seconds.
- Produces: injected prompt text sent as keys to the tmux pane.

- [ ] **Step 1: Create the injector script**

  Create `swarmforge/scripts/kimi-prompt-injector.sh` with content:

  ```zsh
  #!/usr/bin/env zsh
  set -euo pipefail

  TMUX_SOCKET="$1"
  TARGET="$2"
  PROMPT_FILE="$3"
  DELAY_SECONDS="${4:-3}"

  sleep "$DELAY_SECONDS"
  tmux -S "$TMUX_SOCKET" send-keys -t "$TARGET" -l -- "$(< "$PROMPT_FILE")"
  sleep 0.15
  tmux -S "$TMUX_SOCKET" send-keys -t "$TARGET" C-m
  sleep 0.05
  tmux -S "$TMUX_SOCKET" send-keys -t "$TARGET" C-j
  ```

- [ ] **Step 2: Make it executable**

  ```bash
  chmod +x swarmforge/scripts/kimi-prompt-injector.sh
  ```

- [ ] **Step 3: Manually verify the injector works**

  Open a throwaway tmux session:

  ```bash
  tmux -S /tmp/test-kimi-injector.sock new-session -d -s test-injector 'cat'
  echo "Hello from injector" > /tmp/test-prompt.md
  ./swarmforge/scripts/kimi-prompt-injector.sh /tmp/test-kimi-injector.sock test-injector:0.0 /tmp/test-prompt.md 1
  tmux -S /tmp/test-kimi-injector.sock capture-pane -t test-injector:0.0 -p | tail -5
  tmux -S /tmp/test-kimi-injector.sock kill-session -t test-injector
  rm -f /tmp/test-kimi-injector.sock /tmp/test-prompt.md
  ```

  Expected: the captured pane output contains `Hello from injector`.

- [ ] **Step 4: Commit**

  ```bash
  git add swarmforge/scripts/kimi-prompt-injector.sh
  git commit -m "feat(swarmforge): add kimi prompt injector helper"
  ```

---

### Task 4: Schedule Prompt Injection for Kimi Roles

**Files:**
- Modify: `swarmforge/scripts/swarmforge.bb:217-227` (`required-helpers`)
- Modify: `swarmforge/scripts/swarmforge.bb:341-362` (`launch-role!`)
- Test: `swarmforge/scripts/swarmforge.bb` via `bb --test-launch-command` + visual e2e

**Interfaces:**
- Consumes: `ctx` (with `:tmux-socket`, `:tmux-pane-base-index`), `index`, `row`, `prompt-file`; injector script created in Task 3.
- Produces: `kimi-prompt-injector.sh` listed as required helper; detached injector process scheduled after Kimi launch.

- [ ] **Step 0: Add injector to required helpers list**

  In `swarmforge/scripts/swarmforge.bb`, locate `def required-helpers` and append `"kimi-prompt-injector.sh"`:

  ```clojure
  (def required-helpers
    ["handoff_lib.bb" "swarm_handoff.sh" "swarm_handoff.bb"
     "ready_for_next.sh" "ready_for_next.bb"
     "done_with_current.sh" "done_with_current.bb"
     "ready_for_next_task.sh" "ready_for_next_task.bb"
     "done_with_current_task.sh" "done_with_current_task.bb"
     "ready_for_next_batch.sh" "ready_for_next_batch.bb"
     "done_with_current_batch.sh" "done_with_current_batch.bb"
     "handoffd.bb" "stop_handoff_daemon.bb" "stop_handoff_daemon.sh"
     "swarm-cleanup.sh" "swarm-window-watchdog.sh" "swarm-window-watchdog.bb"
     "swarm-terminal-adapter.sh" "swarmforge.sh" "swarmforge.bb"
     "kimi-prompt-injector.sh"])
  ```

- [ ] **Step 1: Add helper to schedule injector**

  Insert the following function immediately before `launch-role!`:

  ```clojure
  (defn send-initial-kimi-prompt! [ctx index row prompt-file]
    ;; Launch a detached shell process to inject the prompt after the TUI is ready.
    ;; We cannot use a Clojure future because the main thread exits before the
    ;; injection delay elapses, and daemon futures are terminated.
    (let [target (tmux-agent-target (:display-name row) (:tmux-pane-base-index ctx) (:session row))
          delay-seconds (inc index)
          injector (str (fs/path (:script-dir ctx) "kimi-prompt-injector.sh"))
          shell-cmd (str "nohup " (sq injector) " " (sq (:tmux-socket ctx)) " " (sq target) " " (sq (str prompt-file)) " " delay-seconds " >/dev/null 2>&1 &")]
      (process/process ["zsh" "-c" shell-cmd] {:out :inherit :err :inherit})
      (println (str "  " cyan "[" (:display-name row) "]" reset " prompt injector scheduled in " delay-seconds "s"))))
  ```

- [ ] **Step 2: Call injector from `launch-role!` for Kimi roles**

  Modify `launch-role!` so that after sending the launch command, it schedules the injector when the agent is `kimi`:

  ```clojure
  (defn launch-role! [ctx index row]
    (let [session (:session row)
          display (:display-name row)
          prompt-file (fs/path (:prompts-dir ctx) (str (:role row) ".md"))
          command (launch-command ctx index row)]
      (sh "tmux" "-S" (:tmux-socket ctx) "send-keys" "-t"
          (tmux-agent-target display (:tmux-pane-base-index ctx) session)
          command "Enter")
      (when (= "kimi" (:agent row))
        (send-initial-kimi-prompt! ctx index row prompt-file))
      (println (str "  " cyan "[" display "]" reset " started in session " session))))
  ```

- [ ] **Step 3: Verify the launch command still builds for Kimi**

  Run:

  ```bash
  bb swarmforge/scripts/swarmforge.bb --test-launch-command . kimi
  ```

  Expected: command still builds successfully.

- [ ] **Step 4: Commit**

  ```bash
  git add swarmforge/scripts/swarmforge.bb
  git commit -m "feat(swarmforge): schedule prompt injection for kimi roles"
  ```

---

### Task 5: Implement CLI Agent Override Parsing

**Files:**
- Modify: `swarmforge/scripts/swarmforge.bb:505-551` (`run-main!` signature and role override)
- Modify: `swarmforge/scripts/swarmforge.bb:579-591` (`-main`)
- Test: `swarmforge/scripts/swarmforge.bb` via `bb --test-parse` with simulated overrides

**Interfaces:**
- Consumes: CLI args; existing agent whitelist.
- Produces: `run-main!` accepts optional `agent-override`; roles have `:agent` replaced before launch.

- [ ] **Step 1: Update `run-main!` signature to accept optional agent override**

  Change:

  ```clojure
  (defn run-main! [root]
  ```

  to:

  ```clojure
  (defn run-main! [root & [agent-override]]
  ```

- [ ] **Step 2: Apply the override after parsing config**

  Inside `run-main!`, locate where `prepare-ctx` is called:

  ```clojure
    (let [ctx (-> (context root)
                  detect-tmux-base-indexes)]
      (initialize-git-repo! ctx)
      (ensure-runtime-git-excludes! ctx)
      (let [ctx (prepare-ctx ctx)]
        (check-backend-dependencies! ctx)
  ```

  Change the inner `let` to apply the override:

  ```clojure
      (let [ctx (cond-> (prepare-ctx ctx)
                  agent-override (update :roles #(map (fn [r] (assoc r :agent agent-override)) %)))]
        (check-backend-dependencies! ctx)
  ```

- [ ] **Step 3: Update `-main` to parse `[agent] [directory]`**

  Replace the existing `-main`:

  ```clojure
  (defn -main [& args]
    (case (first args)
      "--test-parse" (test-parse! (or (second args) (System/getProperty "user.dir")))
      "--test-terminal-bridge" (test-terminal-bridge! (or (second args) (System/getProperty "user.dir")) (nth args 2))
      "--test-launch-command" (apply test-launch-command!
                                     (or (second args) (System/getProperty "user.dir"))
                                     (drop 2 args))
      "--test-agent-start-delay" (println (env-long "SWARMFORGE_AGENT_START_DELAY_MS" 1500))
      "--test-sleep-inhibitor-prefix" (test-sleep-inhibitor-prefix!)
      "--test-tmux-base-indexes" (test-tmux-base-indexes! (second args))
      (run-main! (or (first args) (System/getProperty "user.dir")))))
  ```

  with:

  ```clojure
  (defn -main [& args]
    (case (first args)
      "--test-parse" (test-parse! (or (second args) (System/getProperty "user.dir")))
      "--test-terminal-bridge" (test-terminal-bridge! (or (second args) (System/getProperty "user.dir")) (nth args 2))
      "--test-launch-command" (apply test-launch-command!
                                     (or (second args) (System/getProperty "user.dir"))
                                     (drop 2 args))
      "--test-agent-start-delay" (println (env-long "SWARMFORGE_AGENT_START_DELAY_MS" 1500))
      "--test-sleep-inhibitor-prefix" (test-sleep-inhibitor-prefix!)
      "--test-tmux-base-indexes" (test-tmux-base-indexes! (second args))
      (let [known-agents #{"claude" "codex" "copilot" "grok" "kimi"}
            [agent-override root] (cond
                                    (empty? args) [nil (System/getProperty "user.dir")]
                                    (contains? known-agents (str/lower-case (first args))) [(str/lower-case (first args)) (or (second args) (System/getProperty "user.dir"))]
                                    :else [nil (first args)])]
        (run-main! root agent-override))))
  ```

- [ ] **Step 4: Verify parsing with `--test-parse` semantics**

  The `--test-parse` path does not use `run-main!`, so the override parsing does not affect it. To verify override logic, temporarily add a debug print or run a small Babashka snippet:

  ```bash
  bb -e "(require '[clojure.string :as str]) (let [known-agents #{\"claude\" \"kimi\"} args [\"kimi\" \"/tmp\"]] (cond (empty? args) [nil \".\"] (contains? known-agents (str/lower-case (first args))) [(str/lower-case (first args)) (or (second args) \".\")] :else [nil (first args)]))"
  ```

  Expected output: `["kimi" "/tmp"]`.

  Test directory-only case:

  ```bash
  bb -e "(require '[clojure.string :as str]) (let [known-agents #{\"claude\" \"kimi\"} args [\"/tmp\"]] (cond (empty? args) [nil \".\"] (contains? known-agents (str/lower-case (first args))) [(str/lower-case (first args)) (or (second args) \".\")] :else [nil (first args)]))"
  ```

  Expected output: `[nil "/tmp"]`.

- [ ] **Step 5: Commit**

  ```bash
  git add swarmforge/scripts/swarmforge.bb
  git commit -m "feat(swarmforge): support ./swarm [agent] [directory] override"
  ```

---

### Task 6: Update README Documentation

**Files:**
- Modify: `swarmforge/README.md`

**Interfaces:**
- Consumes: approved design spec.
- Produces: user-facing examples for Kimi and CLI override.

- [ ] **Step 1: Add agent backend and CLI override sections**

  Append to `swarmforge/README.md` after the existing "Local extensions" section:

  ```markdown
  ## Agent backends

  Supported agent backends:

  - `claude` (default)
  - `codex`
  - `copilot`
  - `grok`
  - `kimi`

  To use Kimi for a role, set the agent field in `swarmforge.conf`:

  ```text
  window coder kimi coder
  ```

  Kimi starts in interactive mode; the role prompt is injected as the first message after the TUI is ready.

  ## CLI agent override

  You can temporarily override the agent for all roles without editing `swarmforge.conf`:

  ```bash
  ./swarm kimi              # use Kimi for all roles in the current directory
  ./swarm claude            # use Claude for all roles in the current directory
  ./swarm kimi /path/to/prj # use Kimi for all roles in the specified project
  ```

  The override applies only to the current launch and does not modify `swarmforge.conf`.
  ```

- [ ] **Step 2: Preview the rendered README**

  Open `swarmforge/README.md` and confirm the new sections are formatted correctly and the examples match the implemented behavior.

- [ ] **Step 3: Commit**

  ```bash
  git add swarmforge/README.md
  git commit -m "docs(swarmforge): document kimi backend and cli agent override"
  ```

---

### Task 7: End-to-End Smoke Test

**Files:**
- No file changes.
- Test: manual execution.

**Interfaces:**
- Consumes: all previous tasks.
- Produces: confirmation that `./swarm` works with Kimi and CLI override.

- [ ] **Step 1: Verify no-op launch still works with Claude**

  Run:

  ```bash
  ./swarm
  ```

  Expected: existing four-pack swarm starts with Claude in each role, no errors.

  Clean up:

  ```bash
  ./swarmforge/scripts/swarm-cleanup.sh $(cat .swarmforge/tmux-socket) .swarmforge/window-ids swarmforge-specifier swarmforge-coder swarmforge-refactorer swarmforge-architect
  ```

  (Or close the cleanup window that `launch-command` creates for index 0.)

- [ ] **Step 2: Verify Kimi override**

  Run:

  ```bash
  ./swarm kimi
  ```

  Expected:

  - 4 tmux sessions start.
  - Each pane shows the Kimi TUI.
  - After 1–4 seconds, each pane receives its role prompt as the first message.

  Clean up as in Step 1.

- [ ] **Step 3: Verify directory argument with override**

  From outside the project root, run:

  ```bash
  /path/to/project/swarm kimi /path/to/project
  ```

  Expected: swarm starts in `/path/to/project` with Kimi for all roles.

- [ ] **Step 4: Verify unknown first argument is treated as a directory**

  Run:

  ```bash
  ./swarm unknown
  ```

  Expected: error `Config not found at .../unknown/swarmforge/swarmforge.conf` because an unknown first argument is interpreted as the project directory, not an agent name. This matches the approved CLI parsing rule: only known agent names are treated as agent overrides.

- [ ] **Step 5: Verify missing Kimi error (if Kimi not installed)**

  On a machine without `kimi` in PATH:

  ```bash
  ./swarm kimi
  ```

  Expected: error `'kimi' is required but not installed.`

---

## Self-Review

### Spec Coverage

| Spec Requirement | Implementing Task |
| --- | --- |
| Agent whitelist includes `kimi` | Task 1 |
| Kimi launch command uses `--yolo --add-dir <worktree>` | Task 2 |
| Prompt injector sends `prompts/<role>.md` after TUI ready | Task 3 + Task 4 |
| `launch-role!` schedules injector only for Kimi | Task 4 |
| CLI syntax `./swarm [agent] [directory]` | Task 5 |
| CLI override is one-time, no conf mutation | Task 5 |
| Dependency check for `kimi` | Task 1 (whitelist enables existing `check-backend-dependencies!`) + Task 5 |
| README updated | Task 6 |
| End-to-end verification | Task 7 |

### Placeholder Scan

- No `TBD`, `TODO`, or incomplete sections.
- No vague requirements like "handle edge cases" without concrete steps.
- Each test step includes exact command and expected output.

### Type Consistency

- `run-main!` signature changed from `[root]` to `[root & [agent-override]]` in Task 5; `-main` calls it with `(run-main! root agent-override)`.
- `send-initial-kimi-prompt!` uses `:tmux-pane-base-index` and `:session` consistently with existing `launch-role!`.
- `tmux-agent-target` signature unchanged.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-07-06-swarmforge-kimi-agent-override.md`.**

Two execution options:

1. **Subagent-Driven (recommended)** - Dispatch a fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution** - Execute tasks in this session using batch execution with checkpoints.

Which approach would you like?

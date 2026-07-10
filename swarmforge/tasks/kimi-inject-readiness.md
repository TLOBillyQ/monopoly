# Task: kimi-inject-readiness

Fix kimi role windows failing to receive their startup prompt in a mixed
claude+kimi swarm. Apply fixes #1 (poll-for-readiness) and #3 (per-line submit).

## Context

`swarmforge.conf` now runs claude (specifier, architect) and kimi (coder,
refactorer). claude receives its role prompt as a CLI argument, so it always
arrives. kimi is launched bare and the prompt is typed into its TUI afterwards
by a fire-and-forget injector. On the mixed config the kimi windows come up but
never receive their role instructions and sit idle.

## Root cause

1. `swarmforge/scripts/kimi-prompt-injector.sh` sleeps a fixed delay
   (`send-initial-kimi-prompt!` in `swarmforge.bb:355-365` passes
   `SWARMFORGE_KIMI_INJECT_DELAY_SECONDS` default 1 `+ index`, i.e. 2s/3s) and
   then blindly `send-keys`. There is no readiness check, so the keys land
   before kimi's TUI input is live and are lost.
2. The injector sends the whole two-line prompt file as one literal
   `send-keys -l -- "$(< "$PROMPT_FILE")"`. The embedded newline between line 1
   and line 2 is delivered raw (no bracketed paste), which the TUI can treat as
   a premature submit.

## Required changes

### Fix #1 — poll for readiness (replace the fixed sleep)

- Before injecting, poll the target pane until kimi's TUI input is ready, then
  inject. Use `tmux -S <socket> capture-pane -p -t <target>` and match a stable
  ready marker in kimi's prompt UI (choose a marker robust to kimi 0.23.4;
  verify against the running pane).
- Poll on a short interval with an overall timeout cap (default cap generous,
  e.g. ~30s). If the cap is hit, inject anyway as a last resort and emit a
  diagnostic to stderr so a hang is distinguishable from normal slow boot.
- Keep the existing `SWARMFORGE_KIMI_INJECT_DELAY_SECONDS` as a minimum initial
  wait, not the whole delay. Make the timeout cap and poll interval overridable
  via env vars.

### Fix #3 — submit each prompt line separately

- Send the prompt one line at a time: for each line, `send-keys -l -- "<line>"`
  then `send-keys ... C-m`. Do not send a single literal blob containing an
  embedded newline.
- Preserve the final submit so kimi actually runs the prompt.

## Constraints

- Do not change the claude launch path or any role `.prompt` files.
- Do not change `swarmforge/tools.lock`.
- Keep the injector idempotent and safe to run detached (nohup) as today.
- Files in scope: `swarmforge/scripts/kimi-prompt-injector.sh` and
  `send-initial-kimi-prompt!` in `swarmforge/scripts/swarmforge.bb`.

## Acceptance

- With the mixed claude+kimi `swarmforge.conf`, each kimi window receives its
  full two-line role prompt and begins its role loop, regardless of how long
  kimi's TUI takes to boot.
- The injected prompt is delivered as two submitted lines, not one blob with a
  raw embedded newline.
- If readiness is never detected within the cap, the injector logs a clear
  diagnostic to stderr and still attempts injection.
- claude windows are unaffected.

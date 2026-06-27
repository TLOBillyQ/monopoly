#!/usr/bin/env zsh

# Otty terminal backend (https://otty.app) — controlled via the `otty-cli`
# control surface. Unlike Ghostty/Terminal.app this backend is driven by a CLI
# rather than AppleScript: Otty exposes only the standard AppleScript verbs and
# has no scripting dictionary, so `otty-cli window …` is the supported path.
#
# Each session gets its own Otty window (window-level tracking is clean and
# closable; `otty-cli window new` does not emit the new id, so we capture it by
# diffing `window list` before/after).

_otty_cli() {
  if [[ -n "${OTTY_CLI:-}" && -x "${OTTY_CLI}" ]]; then
    echo "$OTTY_CLI"
    return 0
  fi
  local bundled="/Applications/Otty.app/Contents/MacOS/otty-cli"
  if [[ -x "$bundled" ]]; then
    echo "$bundled"
    return 0
  fi
  if command -v otty-cli >/dev/null 2>&1; then
    command -v otty-cli
    return 0
  fi
  if command -v otty >/dev/null 2>&1; then
    command -v otty
    return 0
  fi
  return 1
}

# Print one Otty window id per line from `window list --json`.
_otty_window_ids() {
  local cli="$1"
  "$cli" window list --json 2>/dev/null \
    | grep -oE '"id"[[:space:]]*:[[:space:]]*"[^"]+"' \
    | sed -E 's/.*"([^"]+)".*/\1/'
}

# Make sure the GUI app is up; `window …` commands require a running app.
_otty_ensure_running() {
  local cli="$1"
  if "$cli" window list >/dev/null 2>&1; then
    return 0
  fi
  open -a Otty >/dev/null 2>&1 || true
  local i
  for (( i = 0; i < 20; i++ )); do
    if "$cli" window list >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.5
  done
  return 1
}

terminal_backend_label() {
  echo "Otty"
}

terminal_backend_can_open_sessions() {
  _otty_cli >/dev/null 2>&1
}

terminal_backend_tracks_windows() {
  return 0
}

terminal_window_exists() {
  local window_id="$1"
  [[ -n "$window_id" ]] || return 1

  local cli
  cli="$(_otty_cli)" || return 1
  "$cli" window show "$window_id" >/dev/null 2>&1
}

terminal_open_session() {
  local session="$1"
  local title="$2"
  # $3 (sibling_id) is intentionally ignored: each session opens its own window.

  local cli
  cli="$(_otty_cli)" || return 1
  _otty_ensure_running "$cli" || return 1

  local initial_cmd="cd '$WORKING_DIR' && exec tmux -S '$TMUX_SOCKET' attach-session -t '$session'"

  local before after new_id
  before="$(_otty_window_ids "$cli")"
  "$cli" window new --cwd "$WORKING_DIR" --command "$initial_cmd" --title "$title" --quiet >/dev/null 2>&1
  after="$(_otty_window_ids "$cli")"

  new_id="$(comm -13 <(printf '%s\n' "$before" | sort -u) <(printf '%s\n' "$after" | sort -u) | head -n1)"
  echo "$new_id"
}

terminal_close_window() {
  local window_id="$1"
  [[ -n "$window_id" ]] || return 0

  local cli
  cli="$(_otty_cli)" || return 0
  "$cli" window close "$window_id" --force >/dev/null 2>&1 || true
}

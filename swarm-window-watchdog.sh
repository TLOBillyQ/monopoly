#!/usr/bin/env zsh
set -euo pipefail

KAKU_CLI="/Applications/Kaku.app/Contents/MacOS/kaku"
WINDOW_STATE_FILE="$1"
WINDOW_IDS_FILE="$2"
CLEANUP_OWNER_INDEX="$3"
WORKING_DIR="$4"
MISSING_THRESHOLD=3

typeset -A MISSING_COUNTS=()

pane_exists() {
  local pane_id="$1"
  [[ -n "$pane_id" ]] || return 1
  "$KAKU_CLI" cli list 2>/dev/null | awk -v pid="$pane_id" 'NR>1 && $3==pid {found=1} END {exit !found}'
}

reopen_kaku_pane() {
  local session="$1"
  local title="$2"
  local sibling_pane pane_id

  sibling_pane="$("$KAKU_CLI" cli list 2>/dev/null | awk 'NR==2 {print $3}')"
  if [[ -n "$sibling_pane" ]]; then
    pane_id="$("$KAKU_CLI" cli split-pane --pane-id "$sibling_pane" --bottom --cwd "$WORKING_DIR" -- tmux attach-session -t "$session")"
  else
    pane_id="$("$KAKU_CLI" cli spawn --new-window --cwd "$WORKING_DIR" -- tmux attach-session -t "$session")"
  fi

  echo "$pane_id"
}

close_kaku_pane() {
  local pane_id="$1"
  [[ -n "$pane_id" ]] || return 0
  "$KAKU_CLI" cli kill-pane --pane-id "$pane_id" 2>/dev/null || true
}

kill_all_sessions() {
  local index window_id session title

  while IFS=$'\t' read -r index window_id session title || [[ -n "${index:-}" ]]; do
    [[ -n "${session:-}" ]] || continue
    tmux kill-session -t "$session" 2>/dev/null || true
  done < "$WINDOW_STATE_FILE"

  while IFS=$'\t' read -r index window_id session title || [[ -n "${index:-}" ]]; do
    [[ -n "${window_id:-}" ]] || continue
    close_kaku_pane "$window_id"
  done < "$WINDOW_STATE_FILE"
}

rewrite_window_id() {
  local target_index="$1"
  local replacement_id="$2"
  local tmp_file="${WINDOW_STATE_FILE}.$$"
  local index window_id session title

  : > "$tmp_file"
  while IFS=$'\t' read -r index window_id session title || [[ -n "${index:-}" ]]; do
    if [[ "$index" == "$target_index" ]]; then
      window_id="$replacement_id"
    fi
    printf '%s\t%s\t%s\t%s\n' "$index" "$window_id" "$session" "$title" >> "$tmp_file"
  done < "$WINDOW_STATE_FILE"

  mv "$tmp_file" "$WINDOW_STATE_FILE"
  awk -F '\t' '{ print $2 }' "$WINDOW_STATE_FILE" > "$WINDOW_IDS_FILE"
}

while [[ -f "$WINDOW_STATE_FILE" ]]; do
  cleanup_session=""
  cleanup_window_id=""
  while IFS=$'\t' read -r index window_id session title || [[ -n "${index:-}" ]]; do
    if [[ "$index" == "$CLEANUP_OWNER_INDEX" ]]; then
      cleanup_session="$session"
      cleanup_window_id="$window_id"
      break
    fi
  done < "$WINDOW_STATE_FILE"

  if [[ -z "$cleanup_session" ]] || ! tmux has-session -t "$cleanup_session" 2>/dev/null; then
    exit 0
  fi

  if pane_exists "$cleanup_window_id"; then
    MISSING_COUNTS[$CLEANUP_OWNER_INDEX]=0
  else
    MISSING_COUNTS[$CLEANUP_OWNER_INDEX]=$(( ${MISSING_COUNTS[$CLEANUP_OWNER_INDEX]:-0} + 1 ))
    if (( MISSING_COUNTS[$CLEANUP_OWNER_INDEX] >= MISSING_THRESHOLD )); then
      kill_all_sessions
      exit 0
    fi
    sleep 2
    continue
  fi

  while IFS=$'\t' read -r index window_id session title || [[ -n "${index:-}" ]]; do
    [[ -n "${index:-}" ]] || continue
    [[ "$index" != "$CLEANUP_OWNER_INDEX" ]] || continue
    tmux has-session -t "$session" 2>/dev/null || continue

    if pane_exists "$window_id"; then
      MISSING_COUNTS[$index]=0
    else
      MISSING_COUNTS[$index]=$(( ${MISSING_COUNTS[$index]:-0} + 1 ))
      (( MISSING_COUNTS[$index] >= MISSING_THRESHOLD )) || continue
      new_pane_id="$(reopen_kaku_pane "$session" "$title")"
      rewrite_window_id "$index" "$new_pane_id"
      MISSING_COUNTS[$index]=0
    fi
  done < "$WINDOW_STATE_FILE"

  sleep 2
done

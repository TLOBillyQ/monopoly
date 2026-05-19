#!/usr/bin/env zsh
set -euo pipefail

KAKU_CLI="/Applications/Kaku.app/Contents/MacOS/kaku"

if [[ $# -lt 1 ]]; then
  echo "Usage: swarm-cleanup.sh <window-ids-file> [session ...]" >&2
  exit 1
fi

WINDOW_IDS_FILE="$1"
shift

for session in "$@"; do
  tmux kill-session -t "$session" 2>/dev/null || true
done

sleep 1

if [[ -f "$WINDOW_IDS_FILE" ]]; then
  while IFS= read -r pane_id; do
    [[ -n "$pane_id" ]] || continue
    "$KAKU_CLI" cli kill-pane --pane-id "$pane_id" 2>/dev/null || true
  done < "$WINDOW_IDS_FILE"
fi

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

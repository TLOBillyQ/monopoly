#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
DEFAULT_PROXY_URL="http://127.0.0.1:15721"
DEFAULT_T3_APP="/Applications/T3 Code (Alpha).app"

print_usage() {
  cat <<EOF
Usage:
  $SCRIPT_NAME [t3-app-or-binary] [args...]

Examples:
  $SCRIPT_NAME
  $SCRIPT_NAME /Applications/T3 Code (Alpha).app -- --port 3000
  $SCRIPT_NAME /path/to/t3-desktop-binary

Environment overrides:
  T3_CLAUDE_HOME
  T3_CLAUDE_PATH_PREFIX
  T3_CLAUDE_PROXY_URL
  T3_CLAUDE_API_KEY
  T3_CLAUDE_BIN
  T3_LAUNCHER_DRY_RUN=1
EOF
}

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

resolve_realpath() {
  local target_path="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath "$target_path"
    return
  fi
  python3 - "$target_path" <<'PY'
import os
import sys
print(os.path.realpath(sys.argv[1]))
PY
}

resolve_app_binary() {
  local app_path="$1"
  local macos_dir="$app_path/Contents/MacOS"
  local entry_count
  local entry_path

  [[ -d "$macos_dir" ]] || fail "Missing app binary directory: $macos_dir"

  entry_count="$(find "$macos_dir" -mindepth 1 -maxdepth 1 -type f | wc -l | tr -d ' ')"
  [[ "$entry_count" -ge 1 ]] || fail "No executable found under: $macos_dir"

  if [[ "$entry_count" -eq 1 ]]; then
    find "$macos_dir" -mindepth 1 -maxdepth 1 -type f | head -n 1
    return
  fi

  entry_path="$macos_dir/$(basename "$app_path" .app)"
  [[ -f "$entry_path" ]] || fail "Multiple app executables found; expected: $entry_path"
  printf '%s\n' "$entry_path"
}

normalize_launch_target() {
  local raw_target="$1"

  [[ -e "$raw_target" ]] || fail "Launch target does not exist: $raw_target"

  if [[ -d "$raw_target" && "$raw_target" == *.app ]]; then
    resolve_app_binary "$(resolve_realpath "$raw_target")"
    return
  fi

  resolve_realpath "$raw_target"
}

main() {
  local launch_target
  local target_path
  local claude_home
  local executable_path
  local -a passthrough_args=()

  if [[ "${1-}" == "--help" || "${1-}" == "-h" ]]; then
    print_usage
    exit 0
  fi

  launch_target="$DEFAULT_T3_APP"
  if [[ $# -ge 1 && "${1-}" != "--" ]]; then
    launch_target="$1"
    shift
  fi

  if [[ "${1-}" == "--" ]]; then
    shift
  fi
  passthrough_args=("$@")

  target_path="$(normalize_launch_target "$launch_target")"
  claude_home="${T3_CLAUDE_HOME:-$HOME}"
  executable_path="${T3_CLAUDE_BIN:-$claude_home/.local/bin/claude}"

  export HOME="$claude_home"
  export PATH="${T3_CLAUDE_PATH_PREFIX:-$HOME/.local/bin}:$PATH"
  export ANTHROPIC_BASE_URL="${T3_CLAUDE_PROXY_URL:-$DEFAULT_PROXY_URL}"
  export ANTHROPIC_API_KEY="${T3_CLAUDE_API_KEY:-any}"
  export CLAUDE_CODE_ENTRYPOINT="external"

  [[ -x "$executable_path" ]] || fail "Claude binary is not executable: $executable_path"

  printf 'Launching t3 with Claude proxy environment\n'
  printf 'HOME=%s\n' "$HOME"
  printf 'PATH prefix=%s\n' "${T3_CLAUDE_PATH_PREFIX:-$HOME/.local/bin}"
  printf 'ANTHROPIC_BASE_URL=%s\n' "$ANTHROPIC_BASE_URL"
  printf 'ANTHROPIC_API_KEY=%s\n' "$ANTHROPIC_API_KEY"
  printf 'claude=%s\n' "$executable_path"
  printf 'target=%s\n' "$target_path"

  if [[ "${T3_LAUNCHER_DRY_RUN:-0}" == "1" ]]; then
    printf 'Dry run enabled; target not started.\n'
    exit 0
  fi

  if [[ ${#passthrough_args[@]} -gt 0 ]]; then
    exec "$target_path" "${passthrough_args[@]}"
  fi

  exec "$target_path"
}

main "$@"

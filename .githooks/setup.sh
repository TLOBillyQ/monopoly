#!/usr/bin/env sh
#
# One-time setup: point git to the shared hooks directory.
#   Usage: sh .githooks/setup.sh

set -e

cd "$(git rev-parse --show-toplevel)"

chmod +x .githooks/pre-commit
git config core.hooksPath .githooks

echo "✔ git hooks activated (.githooks/)"
echo "  default : dep_rules + forbidden_globals (fast)"
echo "  full    : MONO_FULL=1 git commit ..."
echo "  bypass  : git commit --no-verify"

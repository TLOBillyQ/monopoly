.PHONY: verify check test acceptance e2e

verify:
	lua tools/quality/verify_full.lua

check: verify

test:
	busted --run behavior-smoke

# Operator-only e2e lane: drives test profiles against a LIVE Eggy editor via
# editor-cli. Environmentally unsuitable, so it is deliberately OUTSIDE `verify`
# -- off-Windows or with the editor down every spec pends. Start the editor (and
# set EDITOR_CLI_FORCE=1 off-Windows) before running.
e2e:
	busted --run e2e

# Acceptance suite: regenerate the gitignored generated specs from features/
# first (ADR 0015), then run them. Use this instead of a bare
# `busted --run acceptance`, which finds no specs on a fresh checkout.
acceptance:
	lua tools/acceptance/regenerate.lua
	busted --run acceptance

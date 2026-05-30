.PHONY: verify check test acceptance

verify:
	lua tools/quality/verify_full.lua

check: verify

test:
	busted --run behavior-smoke

# Acceptance suite: regenerate the gitignored generated specs from features/
# first (ADR 0015), then run them. Use this instead of a bare
# `busted --run acceptance`, which finds no specs on a fresh checkout.
acceptance:
	lua tools/acceptance/regenerate.lua
	busted --run acceptance

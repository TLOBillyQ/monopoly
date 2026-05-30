verify:
	lua tools/quality/verify_full.lua

check: verify

test:
	busted --run behavior-smoke

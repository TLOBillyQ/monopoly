---
name: verify-fast
description: Run the common fast local confidence lane for this repo: guard checks, static architecture check, and behavior regression.
---

Run this repo's common fast verification lane in this order:

1. `lua tools/quality/lint.lua` if `luacheck` is installed locally
2. `busted -c guards`
3. `lua tools/quality/arch.lua check`
4. `busted -c behavior`

Then summarize:
- which commands passed or failed
- any lane you stopped at because of a failure
- the next command the user should run if they want broader coverage

Use this skill when the user wants a quick confidence pass after normal gameplay, runtime-flow, UI, or mixed local changes.
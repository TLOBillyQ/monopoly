---
name: verify-full
description: Run the fuller Monopoly quality pass and include guidance about when the slow tooling lane is required.
---

Run the fuller repo quality pass in this order:

1. `lua tools/quality/lint.lua` if `luacheck` is installed locally
2. `lua tests/behavior.lua`
3. `lua tests/contract.lua`
4. `lua tests/guard.lua`
5. `lua tools/quality/arch.lua check`
6. `lua tools/quality/crap.lua report --lane behavior --out tmp/crap_report.json`

Only add `lua tests/tooling.lua` when the change touches one of these areas:
- `tools/quality/*`
- arch/crap/mutate viewer or export flow
- vendored quality-tool integrations such as `vendor/arch_view`, `vendor/crap4lua`, or `vendor/mutate4lua`

In the summary:
- list what ran
- list what was intentionally skipped
- state whether the slow tooling lane is recommended
- if anything was skipped, include the exact next command to run

Use this skill when the user asks for a broader verification pass, a pre-review quality check, or validation after boundary/tooling-heavy changes.
---
name: quality
description: "Run heavy quality assurance tools (arch_view, crap4lua) on the current codebase, analyze the output, and open any generated HTML reports. Use when instructed to run quality tools, check architecture, or assess CRAP score."
---

# Quality

Run heavy QA tools and open the generated reports.

1. **Architecture**: `lua tools/quality/arch.lua viewer --open` — static dependency scan + viewer.
2. **CRAP score**: `lua tools/quality/crap.lua` — complexity vs coverage; generates and opens HTML by default.
3. **Regression** (only when full quality context is requested): `busted --run regression`.

Report: architecture violations, cyclic dependencies, high-CRAP functions. State the HTML report paths and that they are open.

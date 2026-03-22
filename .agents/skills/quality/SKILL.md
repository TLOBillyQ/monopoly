---
name: quality
description: "Run heavy quality assurance tools (arch_view, crap4lua) on the current codebase, analyze the output, and open any generated HTML reports. Use when instructed to run quality tools, check architecture, or assess CRAP score."
---

# Quality Assurance Workflow

When invoked to check codebase quality, follow these steps:

1. **Architecture Dependency Check & Viewer:**
   Run the static architecture scanner and open the viewer.
   `lua tools/quality/arch.lua viewer --open`

2. **CRAP Score Report & Viewer:**
   Run the CRAP index tool to evaluate function complexity vs. test coverage and open the HTML report.
   `lua tools/quality/crap.lua` (generates and opens the viewer by default)

3. **Regression Tests:**
   If asked for full quality context, also run:
   `lua tests/regression.lua`

4. **Summarize Results:**
   Review the terminal outputs.
   Report any architecture violations, cyclic dependencies, or high-risk functions with high CRAP scores.
   Ensure the user knows where the HTML reports are located and state that they have been opened.

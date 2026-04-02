# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Read first

- Start with `Agents.md`, then follow the task-specific doc links there instead of browsing the tree broadly.
- This repo runs in the Eggy host and uses Lua 5.5; Eggy `Fixed` arguments must be float literals such as `30.0`, not Lua integers such as `30`.

## Repo rules Claude is likely to miss

- Keep names in `snake_case`; use `CamelCase` only for classes.
- In `src/`, do not use `tonumber` or `type(...) == "number"`; use `src.core.utils.number_utils` instead.
- In `tools/` and `tests/`, use the cross-platform filesystem/process helpers from `tools/shared/lib/common.lua`; do not add direct `os.execute` or `io.popen` calls.
- Use forward-slash paths and the shared path helpers; new scripts and tools must work on both Windows and macOS.
- Do not keep alias/shim compatibility files for renamed canonical modules.

## Verification by change type

- Lua static lint: run `lua tools/quality/lint.lua` after Lua code edits when `luacheck` is available locally.
- Gameplay, runtime flow, or UI behavior changes: run `lua tests/behavior.lua`.
- Port, boundary, assembly, or read-model changes: run `lua tests/contract.lua` and `lua tools/quality/arch.lua check`.
- Guardrail or banned-pattern changes: run `lua tests/guard.lua`.
- Changes under `tools/quality/*`, viewer/export flow, or vendored quality-tool integrations: also run `lua tests/tooling.lua`.

## Handoff expectations

- If you skip slower lanes, report what you ran, what you did not run, and the next recommended verification command.
- Prefer the repo docs for architecture and quality-lane guidance: `docs/architecture/boundaries.md`, `docs/architecture/layer-model.md`, `docs/architecture/quality_map.md`, `docs/architecture/arch_view.md`, and `docs/architecture/mutate4lua.md`.

## Skills already present

- Reuse `.agents/skills/clean-architecture-reviewer`, `.agents/skills/uncle-bob-reviewer`, and `.agents/skills/extract-legacy-test` when their trigger conditions match.
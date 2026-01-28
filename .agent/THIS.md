# This Project

## Project Structure & Module Organization
- `src/` holds runtime code. Core domain lives in `src/core/`, rules and turn flow in `src/gameplay/`, and platform adapters in `src/adapters/`.
- `src/config/` is generated from design spreadsheets; treat it as build output.
- `tests/` contains Lua regression and dependency checks.
- `design/` stores planning spreadsheets and docs; `assets/` holds fonts and art; `docs/` captures design and review notes.
- Entrypoints: `main.lua` for the Love2D demo and `src/game.lua` as the runtime facade.
- 遇到EggyAPI相关检索时， 不要直接读取`docs/eggy/EggyAPI.lua`，这个文件很长，先通过docs/eggy/api/确定关键词后再匹配, 注意deprecated的API不需要。
- LuaAPI及其他EggyAPI 必然存在，不写类似 `if LuaAPI and LuaAPI.call_delay_time then` 这种判断。

## Build, Test, and Development Commands
- `export_xlsx.bat` regenerates `src/config/*.lua` from `design/*.xlsx` and packages `bin/windows/Game.exe`.
- `bin/windows/Game.exe` runs the 2D demo build.
- `run_all_ai.bat` runs a headless simulation (no graphics) and writes logs to `game.log`.
- `lua tests/deps_check.lua` enforces module dependency rules.
- `lua tests/regression.lua` runs quick regression checks.

## Testing Guidelines
- Tests are plain Lua scripts; no external framework is used.
- Name new tests `tests/*_test.lua` or add to `tests/regression.lua` for smoke coverage.
- Run `lua tests/deps_check.lua` before `lua tests/regression.lua` to catch structural issues early.

## Commit & Pull Request Guidelines
- Existing history uses short, imperative messages in either Chinese or English; keep them concise and specific.
- Avoid WIP commit messages unless explicitly requested.
- PRs should include a clear summary, testing notes (commands run), and screenshots for UI changes.
- Link related issues or design docs in `docs/` when applicable.

## Configuration & Data Updates
- Update gameplay tuning via `design/*.xlsx` only, then run `export_xlsx.bat` to refresh `src/config/`.
- Treat generated configs as source-of-truth outputs; do not hand-edit them.

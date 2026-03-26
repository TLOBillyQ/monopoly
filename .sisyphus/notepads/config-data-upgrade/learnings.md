# Learnings — config-data-upgrade

## [2026-03-26] Session Context

- Project: 蛋仔派对大富翁, Lua 5.5, Windows dev environment
- xlsx_reader (`tools/shared/lib/xlsx_reader.lua`) fails on Windows with "Failed to read zip entry: xl/workbook.xml"
- `diff` on Windows is PowerShell Compare-Object (compares path objects, not content) — use Lua-based comparison
- Domain test suites must run via `lua tests/regression.lua`, NOT standalone
- `openpyxl` not installed — use xlsx skill for Excel verification
- Export tool `name_to_key` mapping only supports 5 fixed constants — do NOT extend
- `timing.pre_move_phase` field does NOT exist — only `item_phase_queue` needs updating
- Vehicle sheet indestructible header: `是否不可摧毁（免疫导弹、台风等效果）` (with parenthetical)
- Export tool timing_map at line 381-389 already has `["骰子生效前触发"] = "pre_move"` entry

## [2026-03-26] Task 0 Context

- The export tool hangs/times out when called — confirmed still broken
- Must fix `tools/shared/lib/xlsx_reader.lua` before any other task
- Likely root cause: zip decompression tool incompatibility on Windows with Chinese-character paths

## [2026-03-26] Task 0: xlsx_reader Windows fix

- Root cause: `xlsx_reader` was using repeated Windows backend probing and temp-script extraction paths, which multiplied subprocess overhead; direct `tar`/`unzip` entry reads were already the reliable path for these CJK-named xlsx files.
- Fix: cached zip readers in `xlsx_reader`, preferred `tar`/`unzip` on Windows too, and normalized workbook target entry paths with `common.simplify_path` before extraction.
- Verification: `lua tools/data/export_xlsx.lua --output-dir tmp/prereq-test` succeeded and generated 7 `.lua` files; `lua tests/regression.lua` still reports 7 pre-existing unrelated failures in gameplay/presentation suites.
- ORCHESTRATOR VERIFIED: Export tool confirmed generating 7 files in tmp/prereq-test/: chance_cards.lua, constants.lua, items.lua, market.lua, roles.lua, skins.lua, tiles.lua
- Commit: 0e2c307 — Task 0 COMPLETE

## [2026-03-26] Task 1: 道具表 offer_in_phases column added
- Added column L with header "offer_in_phases" (was 11 cols A-K, now 12 cols A-L)
- All 19 items have values; 骰子加倍卡 (2003) = "pre_move"
- 6 unique values used: post_action, pre_action, pre_move, pre_action,post_action, pass_player, tax_prompt
- Python ET library drops unused xmlns: declarations — restored r:, xr2:, xr3: namespaces manually
- xlsx_pack.py unicode print issue on Windows GBK console — fixed with $env:PYTHONUTF8="1"
- Verified via xlsx_reader.py after repack: 20 rows × 12 cols, all values correct
- Committed: chore(config): 扩展道具表xlsx，新增 offer_in_phases 列

## [2026-03-26] Tasks 3+4: pre_move config entries

- **timing.lua**: item_phase_queue = { "pre_action", "pre_move", "post_action" } (3 elements)
- **availability.lua**: phase_timing[pre_move] = { pre_move = true, turn = true }
- **phase.lua** (3 table updates):
  - phase_titles[pre_move] = "掷骰后：使用道具？"
  - phase_confirm_titles[pre_move] = "掷骰后"
  - repeatable_phases[pre_move] = true
- Verification: Lua assertions confirm is_enabled('pre_move') and is_repeatable('pre_move') both return true
- Commit: 6fb4f12 — eat(turn): 新增 pre_move 到 item_phase_queue 和 phase 配置
- Tasks 3 + 4 COMPLETE

## [2026-03-26] Tasks 6+7+8: Export tool extensions

- **Task 6 (vehicles)**: Added `vehicles_path` (蛋仔--大富翁--座驾表.xlsx), `_require_file` call, vehicles sheet reader block after skins export, and `_write_lua_table` output. Generated vehicles.lua with 12 records matching src/config/content/vehicles.lua exactly.
- **Task 7 (offer_in_phases)**: Added `_parse_phases()` helper that splits comma-separated string into Lua array. Updated items reader to read `col_map["offer_in_phases"]` and attach to each item record. Added `"offer_in_phases"` to items field_order between `"timing"` and `"usage"`. Note: `_lua_value()` already handles table type (lines 119-125) — no changes needed to serializer.
- **Task 8 (pre_move timing_map)**: Verified `timing_map["骰子生效前触发"] = "pre_move"` was already present at line 384 — no change needed.
- **_parse_phases nil handling**: Returns nil (not empty table) when value is nil or empty, so items without offer_in_phases won't emit the field. All 19 items in the xlsx have values, so all 19 emitted with offer_in_phases.
- **_lua_value table support**: Already existed in the original code at lines 119-125 — handled ipairs-style arrays as `{ "val1", "val2" }` format.
- Verification: 12 vehicles correct, all 19 items have offer_in_phases, item 2003 has pre_move.
- Commit: feat(tools): 导出工具支持 vehicles 和 offer_in_phases

## [2026-03-26] Task 5: pre_move phase handler

- Added `src/turn/phases/pre_move.lua` to mirror the item-phase wait passthrough pattern while recomputing `game.last_turn.total` from `game.last_turn.raw_total` via `dice_multiplier.apply_roll_total(...)` before entering `move`.
- Registered `pre_move` in the phase registry between `roll` and `move`, and changed the runtime roll path to return `pre_move`.
- Preserved direct `_phase_roll` caller expectations in existing regression tests by keeping a compatibility wrapper for direct invocations while routing the actual phase registry through `_phase_roll_with_pre_move`.
- Verification: `lua tests/regression.lua` still reports the same 7 pre-existing failures and no new failures.

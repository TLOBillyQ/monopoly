---
name: crap
description: 用 CRAP 分数（复杂度 + 覆盖率不足）给 src/ 函数排重构 / 补测优先级，并按 tier 聚合覆盖率。触发：CRAP、风险热点、补测优先级、覆盖率聚合。不用于：merge gate、pipeline 批量跑（走 /verify）。
---

# Crap

CRAP 分数 = `复杂度² × (1 - 覆盖率)³ + 复杂度`。给 `src/**/*.lua` 函数排"最该先重构 / 补测"。

## 何时用 / 何时不用

- 用：找补测优先级；找重构高杠杆点；与 `/mutate` 联动：先用 CRAP 找热点，再用 mutate 验测试锋利
- 不用：合并门禁（这是排序参考，不是 gate）；分支覆盖率诉求（这是行覆盖率）；评 `tests/` / `tools/` / `vendor/`（只评 `src/`）

## 决策树

1. **看热点** → `lua tools/quality/crap.lua`（无参数 = `report` → `viewer --open`）
2. **跑数据** → `lua tools/quality/crap.lua report --lane behavior --out tmp/crap_report.json --top 20`
3. **多 lane 合并** → `report --lane behavior --lane contract --out <path>`
4. **三层覆盖率聚合** → `lua tools/quality/crap.lua summary --in-json tmp/crap_report.json`
   tier：`core_logic` ≥ 75%、`host_bridge` ≥ 60%、`ui_surface` ≥ 65%（阈值在 `tools/quality/crap/coverage_tiers.lua`）
5. **门禁模式** → `summary --gate`（tier 未达阈值非零退出）
6. **重用 JSON 跳采集** → `viewer --in-json <path> --out-dir <dir>`

`tmp/` 是工具内部的逻辑目录别名，会展开到系统临时目录；写成相对路径即可，跨平台都能用。

## 红线

- **不是 merge gate**：`< 10` low / `10-30` warning / `> 30` critical 是排序色；除非显式 `summary --gate`，单跑不该挡合并。
- **行覆盖率，不是分支覆盖率**：Lua 5.1 + 零依赖约束下最稳妥的口径；不要拿它当分支覆盖证明。
- **只评 `src/`**：`tests/` / `tools/` / `vendor/` 不打分。
- **CRAP → mutate 是顺序**：先用 CRAP 找热点，再用 mutate 验锋利度；不要拿 CRAP 直接判结论。
- **viewer 和 summary 不在 pipeline**：`verify` 只跑 `report`；要 HTML 视图或 tier 聚合单独跑。

## 真源

- 工具机制、子命令、tier 阈值、公式：`docs/reports/crap.md`
- tier 配置：`tools/quality/crap/coverage_tiers.lua`
- 上游：子模块 `vendor/crap4lua/`

## 输出汇报

- 命令 + lane
- top N 高 CRAP 函数（路径:行 + complexity + coverage + crap）
- tier 状态（如跑 summary）
- 建议：哪些先 `/mutate` 验、哪些先补 spec、哪些先记一笔

## 工具链改动

动到 `tools/quality/*` 任何文件 → handoff 跑 `lua tools/quality/verify_full.lua` + `busted --run tooling` 兜底（前者跑 shell-out 端到端，后者跑工具模块单测）。

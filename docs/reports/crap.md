---
kind: report
status: generated
owner: quality
last_verified: 2026-05-22
---
# CRAP Report

`tools/quality/crap.lua` 把函数复杂度与动态测试覆盖率合成 CRAP 分数，排出"最该先重构/补测"的函数热点。它不替代 `busted --run behavior`、`busted --run contract` 或 `busted --run guards`。

当前 Monopoly 只保留兼容入口壳；核心实现位于子模块 `vendor/crap4lua/`。Monopoly 的本地兼容层位于 `tools/bridge/crap4lua/_internal/`，再通过公开 Lua runtime `crap4lua.bridge` 加载 `tools/quality/crap/config.lua` 并执行 `tools/quality/crap/adapter.lua` 收集 coverage，最后把生成的 `ReportRequest` JSON 交给上游 CLI 完成报告分析与 viewer 导出。

如果你想先看整个质量面里 `crap` 和 `behavior / contract / guard / arch_view` 的分工，先读 `docs/architecture/quality-map.md`。

## 命令

```
lua tools/quality/crap.lua
```
无参数：生成并打开静态 viewer，等价于 `viewer --out-dir tmp/crap_view --open`。

```
lua tools/quality/crap.lua report --out tmp/crap_report.json --top 20
```
生成报告。`tmp/...` 是逻辑临时目录别名，实际路径：macOS `$TMPDIR/monopoly_crap/`，Windows `%TEMP%/monopoly_crap/`。可通过 `MONOPOLY_CRAP_TMP` 覆盖。

默认：作用域 `src/**/*.lua`，lane `behavior`，测试失败仍产出报告。

```
lua tools/quality/crap.lua report --lane behavior --lane contract --out tmp/crap_report.json
```
同时统计 behavior + contract 两条 lane 的触达。

```
lua tools/quality/crap.lua report --strict-tests --out tmp/crap_report.json
```
测试 lane 失败时返回非零退出码。

```
lua tools/quality/crap.lua viewer
lua tools/quality/crap.lua viewer --out-dir tmp/crap_view [--open]
lua tools/quality/crap.lua viewer --in-json tmp/crap_report.json --out-dir tmp/crap_view
```
导出静态 viewer。命令完成后打印实际路径，打开 `index.html` 即可查看，不需要本地服务。

`viewer --in-json` 直接渲染现有 JSON，不会加载 Monopoly 配置或测试 lane；`report` 会先 collect，再通过纯 Lua `crap4lua.cli` 生成分析结果和 viewer，不需要 vendor 二进制入口。

## 分数说明

**复杂度**：`1 + decision_line_count`，用 `luac -p -l` 字节码清单统计条件/循环相关 opcode 的源码行数。

**覆盖率**：通过 `debug.sethook(..., "l")` 动态记录命中行，函数可执行行与命中行求交得到行覆盖率（0–1）。

**CRAP 公式**：

```
complexity² × (1 - coverage)³ + complexity
```

## 如何读报告

主要看三个字段：

| 字段 | 含义 |
|------|------|
| `complexity` | 函数决策密度 |
| `coverage` | 所选 lane 实际触达比例 |
| `crap` | 综合风险分数，越高越优先 |

默认三档风险色：`< 10` low，`10–30` warning，`> 30` critical。这不是合并 gate，只是排序参考。

## 边界

- 只分析 `src/**/*.lua`，不给 `tests/`、`tools/`、`vendor/` 打分
- 行覆盖率，不是分支覆盖率（Lua 5.1 + 零额外依赖约束下最稳妥的选择）

## 覆盖率聚合（summary 子命令）

`crap.lua summary` 从现有 `crap_report.json` 里提取每个函数的 `executable_line_count` 与 `hit_line_count`，按 `tools/quality/crap/coverage_tiers.lua` 定义的三个 tier 聚合输出 src/ 行覆盖率。

```
lua tools/quality/crap.lua summary [--lane behavior] [--in-json tmp/crap_report.json]
```

- 若 `--in-json` 文件不存在，自动先跑 `report` 生成
- `--gate`：任一 tier 未达阈值时以非零退出码退出（默认不开门禁）
- `--out FILE`：同时输出聚合结果 JSON
- `--top N`（默认 10）：对未达标 tier 列出未覆盖行最多的前 N 个文件

覆盖率口径与 CRAP 公式中的 `coverage` 字段同源（behavior lane + `debug.sethook("l")`），不是另一套采集。

### 三层 tier 定义（当前阈值，按需调整）

| Tier | 包含目录 | 目标阈值 |
|---|---|---|
| `core_logic` | `src/app/ src/computer/ src/config/ src/foundation/ src/player/ src/rules/ src/state/ src/turn/` | 75% |
| `host_bridge` | `src/host/` | 60% |
| `ui_surface` | `src/ui/` | 65% |

阈值写在 `tools/quality/crap/coverage_tiers.lua`，可在出完基线后按实际情况微调。

### 当前基线（2026-05-22，behavior lane）

| Tier | 文件数 | 可执行行 | 命中行 | 覆盖率 | 目标 | 状态 |
|---|---|---|---|---|---|---|
| `core_logic` | 198 | 17,730 | 13,522 | **76.3%** | 75% | PASS |
| `host_bridge` | 13 | 1,322 | 804 | **60.8%** | 60% | PASS |
| `ui_surface` | 139 | 10,883 | 7,336 | **67.4%** | 65% | PASS |

三层都过线，但 `core_logic` 仅高出阈值 1.3 个百分点，`host_bridge` 仅高出 0.8 个百分点。回归裕度薄，下一轮补测优先 `core_logic`。

`core_logic` 未覆盖行最多的文件（top 10）：

| 文件 | 命中/总行 | 覆盖率 |
|---|---|---|
| `src/turn/actions/validator.lua` | 159/221 | 71.9% |
| `src/foundation/tips.lua` | 158/217 | 72.8% |
| `src/rules/chance/handlers.lua` | 327/385 | 84.9% |
| `src/rules/items/handlers.lua` | 176/234 | 75.2% |
| `src/rules/endgame.lua` | 133/190 | 70.0% |
| `src/rules/items/strategy.lua` | 77/134 | 57.5% |
| `src/app/compose_game.lua` | 115/170 | 67.6% |
| `src/app/host_install.lua` | 0/53 | 0.0% |
| `src/rules/items/roadblock.lua` | 131/183 | 71.6% |
| `src/foundation/ports/runtime_ports.lua` | 61/112 | 54.5% |

刷新基线命令：
```sh
lua tools/quality/crap.lua report --lane behavior --out tmp/crap_report.json
lua tools/quality/crap.lua summary --in-json tmp/crap_report.json
```

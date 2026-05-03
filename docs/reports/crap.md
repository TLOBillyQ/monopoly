# CRAP Report

`tools/quality/crap.lua` 把函数复杂度与动态测试覆盖率合成 CRAP 分数，排出"最该先重构/补测"的函数热点。它不替代 `busted -c behavior`、`busted -c contract` 或 `busted -c guards`。

当前 Monopoly 只保留兼容入口壳；核心实现位于子模块 `vendor/crap4lua/`。Monopoly 的本地兼容层位于 `tools/bridge/crap4lua/_internal/`，再通过公开 Lua runtime `crap4lua.bridge` 加载 `tools/quality/crap/config.lua` 并执行 `tools/quality/crap/adapter.lua` 收集 coverage，最后把生成的 `ReportRequest` JSON 交给上游 CLI 完成报告分析与 viewer 导出。

如果你想先看整个质量面里 `crap` 和 `behavior / contract / guard / arch_view` 的分工，先读 `docs/architecture/quality_map.md`。

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

`viewer --in-json` 直接渲染现有 JSON，不会加载 Monopoly 配置或测试 lane；`report` 会先 collect 再调用上游 CLI 的 `--request-json` 模式。缺少二进制时，包装层会在本地临时生成 launcher 并构建 `vendor/crap4lua/bin/crap4lua`，不会修改子模块提交态。

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
| `core_logic` | `src/app/ src/computer/ src/config/ src/core/ src/player/ src/rules/ src/state/ src/turn/` | 90% |
| `host_bridge` | `src/host/` | 60% |
| `ui_surface` | `src/ui/` | 70% |

阈值写在 `tools/quality/crap/coverage_tiers.lua`，可在出完基线后按实际情况微调。

### 当前基线（2026-04-28，behavior lane）

| Tier | 文件数 | 可执行行 | 命中行 | 覆盖率 | 目标 | 状态 |
|---|---|---|---|---|---|---|
| `core_logic` | 198 | 12,702 | 10,089 | **79.4%** | 90% | FAIL |
| `host_bridge` | 13 | 1,297 | 942 | **72.6%** | 60% | PASS |
| `ui_surface` | 120 | 7,877 | 6,237 | **79.2%** | 70% | PASS |

`host_bridge` 与 `ui_surface` 已超标，待补测重点是 `core_logic`（差距约 10.6 个百分点）。

`core_logic` 未覆盖行最多的文件（首次基线 top 10）：

| 文件 | 命中/总行 | 覆盖率 |
|---|---|---|
| `src/turn/loop/ports.lua` | 59/124 | 47.6% |
| `src/state/landing_visual_hold.lua` | 166/231 | 71.9% |
| `src/turn/timing/session_script.lua` | 4/60 | 6.7% |
| `src/turn/actions/validator.lua` | 137/185 | 74.1% |
| `src/turn/phases/move.lua` | 41/88 | 46.6% |
| `src/rules/choice_handlers/item.lua` | 346/391 | 88.5% |
| `src/turn/output/state_adapter.lua` | 16/59 | 27.1% |
| `src/rules/items/phase.lua` | 229/270 | 84.8% |
| `src/state/runtime_state.lua` | 168/208 | 80.8% |
| `src/turn/loop/tick_clock.lua` | 75/115 | 65.2% |

刷新基线命令：
```sh
lua tools/quality/crap.lua report --lane behavior --out tmp/crap_report.json
lua tools/quality/crap.lua summary --in-json tmp/crap_report.json
```

# CRAP Report

`tools/quality/crap.lua` 把函数复杂度与动态测试覆盖率合成 CRAP 分数，排出"最该先重构/补测"的函数热点。它不替代 `tests/behavior.lua`、`tests/contract.lua` 或 `lua tests/guard.lua`。

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

# 健康信号与周检入口

每周按以下顺序跑，先判断"安全"，再看"优雅"。

如果你想先判断“该跑哪条”或查看本地耗时基线，先读 `docs/architecture/quality_map.md`。

## 周检顺序

**1. 全量回归（必跑）**

```
MONO_REGRESSION_MODE=release_trimmed lua tests/regression.lua
```

覆盖 behavior / contract / guard 三条车道。健康输出：

```
All regression checks passed (416)
All regression checks passed (62)
dep_rules ok
gameplay_loop_no_ui ok
forbidden_globals ok
arch_view_guard ok
```

失败则优先修复，不要继续看其他信号。当前 guard lane 预期为 4 条：`dep_rules`、`gameplay_loop_no_ui`、`forbidden_globals`、`arch_view_guard`。

**2. 架构与契约（必跑）**

```
lua tests/contract.lua
```

验证 `output_adapters/`、gameplay loop output、choice contract、窄 Port 注入等边界稳定性。改过这些路径就先跑这条。

**3. UI 热点回归（改过 presentation 层时跑）**

```
MONO_REGRESSION_MODE=release_trimmed lua tests/behavior.lua
```

守住市场弹窗、玩家面板、choice 路由、target picker 等 UI 行为。

**4. LOC 趋势（辅助观察，不驱动决策）**

```
lua scripts/loc.lua
```

更新 `scripts/analysis/loc_data.json`，有 gnuplot 则生成趋势图。LOC 上升但边界稳定、测试健康，不算退化；只有同时伴随边界漂移或覆盖下降才值得关注。

## CRAP 报告（按需诊断）

```
lua scripts/crap.lua report --out tmp/crap_report.json --top 20
lua scripts/crap.lua viewer --in-json tmp/crap_report.json
```

或直接：

```
lua scripts/crap.lua
```

输出在逻辑临时目录 `tmp/crap_view/index.html`（实际会展开到系统临时目录下的 `monopoly_crap/crap_view/index.html`）。用于找"复杂度高且测试触达不足"的函数，是热点雷达，不是周检 gate。默认 lane 失败也产出报告；加 `--strict-tests` 才会把测试失败升级为命令失败。

实现上，`scripts/crap.lua` 会转发到子模块 `vendor/crap4lua/`，并通过 `scripts/quality/crap_monopoly_adapter.lua` 注入 Monopoly 的测试 lane。

## `output_adapters/` 迁移条件

默认不迁。出现以下任一情况再评估：

- 文件开始承载宿主细节，不再只是 turn 本地输出桥
- 调用面扩到多个非 turn 用例，`flow` 本地桥接语义不再成立
- `runtime/*_port_adapter.lua` 与 `flow/output_adapters/*.lua` 出现稳定职责重叠
- architecture suite 无法用当前目录语义自解释

条件未出现前，优先补文档、补测试、补信号，不做目录手术。

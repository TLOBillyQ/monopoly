---
kind: report
status: generated
owner: quality
last_verified: 2026-07-02
---
# 健康信号与周检入口

每周按以下顺序跑，先判断"安全"，再看"优雅"。

如果你想先判断“该跑哪条”或查看本地耗时基线，先读 `docs/architecture/quality-map.md`。

## 周检顺序

**1. 全量回归（必跑）**

```
lua tools/quality/verify_full.lua --full
```

默认（无 flag）并行跑 contract / guards / arch / behavior / lint / encoding 六条 lane；`--full` 追加 coverage 与 crap（crap_collect → crap 分析 → crap_gate 棘轮），周检用 `--full`。tooling lane 用 `--tooling` 加跑；acceptance 由 `make acceptance` 单独驱动，不在 verify 管线内。健康输出：

```
[verify] PASS  passed=N failed=0 skipped=0  Ns
```

失败则优先修复，不要继续看其他信号。当前 guard lane 预期为 6 条：`dep_rules`、`gameplay_loop_no_ui`、`forbidden_globals`、`arch_view_guard`、`fixed_type_guard`、`repo_hygiene`。

**2. 架构与契约（必跑）**

```
~/.luarocks/bin/busted --helper=spec/helper.lua --run=contract
```

验证 `output_adapters/`、gameplay loop output、choice contract、窄 Port 注入等边界稳定性。改过这些路径就先跑这条。

**3. UI 热点回归（改过 ui 层时跑）**

```
busted --run behavior
```

守住市场弹窗、玩家面板、choice 路由、target picker 等 UI 行为。

**4. LOC 趋势（辅助观察，不驱动决策）**

```
lua tools/quality/loc.lua [--days N]
```

按天统计最近 N 天（默认 14）src/ 和 spec/ 的有效 LOC，写 `tmp/loc_data.json` + `tmp/loc_trend.svg`（双 panel 折线，浏览器直接打开）。LOC 上升但边界稳定、测试健康，不算退化；只有同时伴随边界漂移或覆盖下降才值得关注。

## CRAP 报告（按需诊断）

```
lua tools/quality/crap.lua report --out tmp/crap_report.json --top 20
lua tools/quality/crap.lua viewer --in-json tmp/crap_report.json
```

或直接：

```
lua tools/quality/crap.lua
```

输出在逻辑临时目录 `tmp/crap_view/index.html`（实际会展开到系统临时目录下的 `monopoly_crap/crap_view/index.html`）。用于找"复杂度高且测试触达不足"的函数，是热点雷达，不是周检 gate。默认 lane 失败也产出报告；加 `--strict-tests` 才会把测试失败升级为命令失败。与之独立，`verify --full` 里的 `crap_gate` 是复杂度感知棘轮，只拦超出基线（`tools/quality/crap/crap_gate_baseline.lua`）的新增违规。

实现上，`tools/quality/crap.lua` 会先通过公开 Lua bridge 加载 `tools/quality/crap/config.lua`、执行 `tools/quality/crap/adapter.lua` 收集 coverage，再委托纯 Lua `crap4lua.cli` 做分析与 viewer 导出。

## `src/turn/output/` 迁移条件

默认不迁。出现以下任一情况再评估：

- 文件开始承载宿主细节，不再只是 turn 本地输出桥
- 调用面扩到多个非 turn 用例，`turn` 本地桥接语义不再成立
- `src/ui/ports/*` 与 `src/turn/output/*` 出现稳定职责重叠
- architecture suite 无法用当前目录语义自解释

条件未出现前，优先补文档、补测试、补信号，不做目录手术。

# src/ 最近两天提交研究：代码膨胀视角（2026-03-02 更新版）

本文件是研究结论，不是执行计划。执行安排见 `.agents/plan.md`。

审查范围：
- 时间：最近两天（`git log --since='2 days ago'`）
- 路径：`src/`
- 方法：`git log --numstat` 聚合 + 提交级别净增分析 + 当前热点文件交叉检查

---

## 1. 总结结论

1. 最近两天 `src/` 共 **37 个提交**，总计 **+5962 / -4690，净增 +1272 行**，仍处于明显增长区间。
2. 增长主体集中在 `src/presentation`（净增约 +600 行）和 `src/game`（净增约 +200 行），`src/core` 增长相对收敛。
3. **R17 已落地**：4 个热点文件完成拆分，合计减少 **-204 行（-46.8%）**，新增 8 个职责聚焦的子模块。
4. 新膨胀热点正在形成：`PresentationPorts.lua`（+281）、`ActionAnimUnitOverlay.lua`（+226）成为新的净增长头部。

---

## 2. 量化统计（最近两天）

### 2.1 全量变更

| 指标 | 数值 |
|---|---:|
| 提交数（仅 `src/`） | 37 |
| 新增行 | 5962 |
| 删除行 | 4690 |
| 净增长 | **+1272** |

### 2.2 按日期分布

| 日期 | 新增 | 删除 | 净增长 |
|---|---:|---:|---:|
| 2026-02-28 | 402 | 90 | +312 |
| 2026-03-01 | 2860 | 2563 | +297 |
| 2026-03-02 | 2700 | 2037 | +663 |

观察：3/2 净增最高，但注意其中包含 R17 拆分产生的新增模块代码。

### 2.3 按目录聚合（`src/一级/二级`）

| 目录 | 新增 | 删除 | 净增长 |
|---|---:|---:|---:|
| `src/presentation/api` | 1271 | 951 | **+320** |
| `src/presentation/interaction` | 717 | 587 | **+130** |
| `src/presentation/render` | 674 | 590 | +84 |
| `src/game/flow` | 540 | 420 | +120 |
| `src/game/systems` | 263 | 252 | +11 |
| `src/core` | 224 | 128 | +96 |
| `src/app` | 175 | 123 | +52 |

---

## 3. 膨胀热点

### 3.1 净增长 Top 文件（最近两天）

| 文件 | 新增 | 删除 | 净增长 | 备注 |
|---|---:|---:|---:|:---|
| `src/presentation/api/PresentationPorts.lua` | 281 | 0 | **+281** | 🚨 新热点 |
| `src/presentation/render/ActionAnimUnitOverlay.lua` | 226 | 0 | **+226** | 🚨 新热点 |
| `src/presentation/interaction/ui_intent_dispatcher/GameActionDispatcher.lua` | 194 | 0 | **+194** | 🚨 新热点 |
| `src/game/core/runtime/Agent.lua` | 181 | 9 | **+172** | 业务增长 |
| `src/core/runtime_ports/DefaultPorts.lua` | 168 | 0 | **+168** | R17 新增模块 |
| `src/presentation/render/ActionAnimOverlayRuntime.lua` | 146 | 15 | +131 | 动画运行时 |
| `src/presentation/interaction/UIIntentDispatcher.lua` | 125 | 0 | +125 | 交互分发 |
| `src/game/systems/land/LandRentResolver.lua` | 133 | 25 | +108 | 业务规则 |
| `src/presentation/api/HostRuntimePort.lua` | 138 | 2 | +136→+80 | R17 已拆分 |
| `src/presentation/api/presentation_ports/UISyncPorts.lua` | 124 | 5 | +119→+44 | R17 已拆分 |

### 3.2 频繁改动文件（提交触达次数 Top）

| 文件 | 触达提交数 |
|---|---:|
| `src/core/RuntimePorts.lua` | 9 |
| `src/app/bootstrap/RuntimeInstall.lua` | 9 |
| `src/presentation/api/PresentationPorts.lua` | 6 |
| `src/presentation/render/MoveAnim.lua` | 6 |
| `src/presentation/render/board_runtime/placement.lua` | 6 |
| `src/presentation/interaction/UIIntentDispatcher.lua` | 5 |
| `src/presentation/interaction/ui_intent_dispatcher/ViewCommandDispatcher.lua` | 5 |

判断：`PresentationPorts.lua` 已成为新热点（净增 Top 1 + 触达 6 次），需纳入下一轮治理。

---

## 4. 对"代码膨胀"的判断

### 4.1 属于"必要显式化"的增长

- **R17 拆分产生的新增代码**：8 个新模块（331 行）是为了降低热点文件复杂度，属于结构性投资。
- **边界契约显式化**：`DefaultPorts.lua` 等模块将隐式耦合转为显式接口。
- **新功能落地**：`ActionAnimUnitOverlay.lua`、`GameActionDispatcher.lua` 等是功能新增，非重复堆砌。

### 4.2 属于"真实膨胀风险"的增长

- **新热点快速形成**：`PresentationPorts.lua` 净增 +281 行且零删除，显示纯追加模式。
- **高频文件仍集中**：`RuntimePorts.lua`、`RuntimeInstall.lua` 触达 9 次，仍是跨功能改动汇聚点。
- **交互层持续扩张**：`UIIntentDispatcher` 相关文件合计净增 +300+ 行，需关注职责边界。

---

## 5. R17 执行结果（已验证）

### 5.1 已落地改动

| 热点文件 | 改动前 | 改动后 | 变化 | 新承接模块 |
|---|---:|---:|---:|:---|
| `HostRuntimePort.lua` | 136 | 80 | **-56 (-41.2%)** | `host_runtime/*` (3 个) |
| `UISyncPorts.lua` | 119 | 44 | **-75 (-63.0%)** | `ui_sync/*` (3 个) |
| `ViewCommandDispatcher.lua` | 90 | 67 | **-23 (-25.6%)** | `RoleContext.lua` |
| `RuntimeInstall.lua` | 91 | 41 | **-50 (-54.9%)** | `RuntimePortDefaults.lua` |
| **合计** | **436** | **232** | **-204 (-46.8%)** | 8 个模块，331 行 |

### 5.2 验证结果

- `lua tests/internal/dep_rules.lua`：**dep_rules ok**
- `lua tests/regression.lua`：**All regression checks passed (213)**
- `tick ok`，`forbidden_globals ok`

结论：拆分在不改变行为的前提下完成，依赖治理未破坏。

---

## 6. 建议动作（下一轮）

1. **治理新热点 `PresentationPorts.lua`**：当前净增 +281 行且无删除，需评估是否过度承载职责。
2. **监控 `ActionAnimUnitOverlay.lua` 与 `GameActionDispatcher.lua`**：确认是功能新增还是职责漂移。
3. **继续高频文件去中心化**：`RuntimePorts.lua` 与 `RuntimeInstall.lua` 触达 9 次，仍有拆分空间。
4. **建立体量守卫机制**：对净增长 >200 行且删除 <10 行的文件在 PR 中要求附加说明。

---

## 7. 结论

最近两天 `src/` 净增 +1272 行，但 **R17 已完成 4 个热点文件的拆分，合计减少 -204 行**。当前风险已从"单点大文件膨胀"转为"新热点快速形成"——`PresentationPorts.lua` 成为新的净增长头部。

后续治理应双轨并行：
- **收敛轨**：继续拆分高频改动文件（`RuntimePorts.lua`、`RuntimeInstall.lua`）
- **预防轨**：对新形成的快速净增长文件（`PresentationPorts.lua` 等）及早介入，避免重蹈覆辙

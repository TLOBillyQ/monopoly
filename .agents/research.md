# src/ 最近两天提交研究：代码膨胀视角（2026-03-02）

本文件是研究结论，不是执行计划。执行安排见 `.agents/plan.md`。

审查范围：
- 时间：最近两天（`git log --since='2 days ago'`）
- 路径：`src/`
- 方法：`git log --numstat` 聚合 + 提交级别净增分析 + 当前文件体量交叉检查

---

## 1. 总结结论

1. 最近两天 `src/` 共 **38 个提交**，总计 **+5585 / -4334，净增 +1251 行**，存在明显体量上升。
2. 这轮增长主要集中在 `src/core` 与 `src/presentation`，但同时伴随大量替换/迁移删除，不是纯堆叠式增长。
3. “代码膨胀”风险点已出现，最突出的是跨层端口与运行时装配相关文件（`RuntimePorts.lua`、`HostRuntimePort.lua`、`ViewCommandDispatcher.lua`）。
4. `src/game` 目录整体净减少（-89），说明核心玩法逻辑并未同步膨胀，增长更多来自边界治理与接口显式化。

---

## 2. 量化统计（最近两天）

### 2.1 全量变更

| 指标 | 数值 |
|---|---:|
| 提交数（仅 `src/`） | 38 |
| 新增行 | 5585 |
| 删除行 | 4334 |
| 净增长 | **+1251** |

### 2.2 按日期分布

| 日期 | 新增 | 删除 | 净增长 |
|---|---:|---:|---:|
| 2026-02-28 | 402 | 90 | +312 |
| 2026-03-01 | 2860 | 2563 | +297 |
| 2026-03-02 | 2323 | 1681 | +642 |

观察：3/2 出现第二波增长高峰，且净增高于 3/1。

### 2.3 按目录聚合（`src/一级/二级`）

| 目录 | 新增 | 删除 | 净增长 |
|---|---:|---:|---:|
| `src/core` | 905 | 186 | **+719** |
| `src/presentation` | 2853 | 2284 | **+569** |
| `src/app` | 175 | 123 | +52 |
| `src/game` | 1652 | 1741 | **-89** |

---

## 3. 膨胀热点

### 3.1 净增长 Top 文件（最近两天）

| 文件 | 新增 | 删除 | 净增长 |
|---|---:|---:|---:|
| `src/core/RuntimePorts.lua` | 345 | 46 | **+299** |
| `src/game/core/runtime/Agent.lua` | 181 | 9 | +172 |
| `src/presentation/api/HostRuntimePort.lua` | 138 | 2 | +136 |
| `src/presentation/render/ActionAnimOverlayRuntime.lua` | 146 | 15 | +131 |
| `src/presentation/api/presentation_ports/UISyncPorts.lua` | 124 | 5 | +119 |
| `src/game/flow/turn/TickChoiceTimeout.lua` | 115 | 0 | +115 |
| `src/presentation/interaction/ui_intent_dispatcher/PreConfirmFlow.lua` | 110 | 0 | +110 |
| `src/game/systems/land/LandRentResolver.lua` | 133 | 25 | +108 |
| `src/game/flow/turn/GameplayLoopUISyncDefaults.lua` | 108 | 0 | +108 |
| `src/core/ChoiceRoutePolicy.lua` | 100 | 0 | +100 |

### 3.2 频繁改动文件（提交触达次数 Top）

| 文件 | 触达提交数 |
|---|---:|
| `src/core/RuntimePorts.lua` | 8 |
| `src/app/bootstrap/RuntimeInstall.lua` | 8 |
| `src/presentation/render/MoveAnim.lua` | 6 |
| `src/presentation/render/board_runtime/placement.lua` | 6 |
| `src/presentation/api/PresentationPorts.lua` | 6 |
| `src/core/RuntimeContext.lua` | 5 |
| `src/presentation/interaction/UIIntentDispatcher.lua` | 5 |

判断：`RuntimePorts`、`RuntimeInstall`、`PresentationPorts` 既“长得快”又“改得勤”，是当前最需要防膨胀治理的核心文件。

---

## 4. 对“代码膨胀”的判断

### 4.1 属于“必要显式化”的增长

- 边界契约显式化：大量端口/策略代码从隐式耦合转为显式接口。
- 兼容层退役成本：迁移期会并存“新接口 + 过渡适配”，短期净增正常。
- 结构替换明显：多次大提交同时出现高新增和高删除（如 `35fd46d0`、`bc2e0f81`），不是单向堆积。

### 4.2 属于“真实膨胀风险”的增长

- 运行时装配中心化过度：`RuntimePorts.lua` 已达到 299 行，接近“策略分发 + 装配 + 默认实现”多职责混合。
- presentation 端口碎片多：`HostRuntimePort.lua`、`PresentationPorts.lua`、`UISyncPorts.lua` 同时扩张，存在职责重叠概率。
- 高频改动集中在少数大文件：会拉高冲突率、回归成本和阅读门槛。

---

## 5. 关键提交（净增长视角）

| 提交 | 主题 | 新增/删除 | 净增 |
|---|---|---:|---:|
| `410b9e9a` | runtime boundaries / remove proxies | 413 / 61 | **+352** |
| `4117055b` | R8/R9 boundary hardening | 678 / 354 | **+324** |
| `492055dd` | 二级确认与等待流程 | 189 / 1 | +188 |
| `b1a46d7d` | runtime guard + tests | 142 / 29 | +113 |
| `35fd46d0` | read model split / ui dispatch | 673 / 562 | +111 |

备注：这些提交多数是架构阶段性重构，不能简单按“净增高=坏”判定，但应在阶段结束后立刻做收口压缩。

---

## 6. 建议动作（围绕膨胀收敛）

1. 对 `RuntimePorts.lua` 做二次拆分：
   - 目标拆为 `PolicyInstall`、`DefaultPorts`、`LegacyFallbackPolicy`（或等价边界）。
2. 对 presentation 端口做“单一职责盘点”：
   - 明确 `HostRuntimePort` 与 `PresentationPorts` 的边界，避免重复导出/透传。
3. 增加轻量体量守卫：
   - 对关键文件设软阈值（如 260 行）并在 PR 里提示“需解释增长理由”。
4. 以“净增 Top 文件”为对象做一次专门压缩迭代：
   - 优先：`RuntimePorts.lua`、`HostRuntimePort.lua`、`ViewCommandDispatcher.lua`。

---

## 7. 结论

最近两天 `src/` 的确发生了可观净增长（+1251 行），但主因是架构边界显式化与迁移成本，不是单纯业务重复堆砌。  
真正的风险不在“是否增长”，而在“增长是否继续集中在少数跨层大文件”。当前应从“继续加法”切换到“收口拆分”，否则会在下一轮演进中转化为维护性债务。

---

## 8. R16 执行结果（已落地）

本轮已按“降低代码膨胀”目标执行一轮可验证收缩，聚焦 `RuntimePorts` 热点文件。

### 8.1 已执行改动

- 新增 `src/core/runtime_ports/ContextPolicy.lua`，承接策略合法性与 legacy fallback 归一化。
- 新增 `src/core/runtime_ports/DefaultPorts.lua`，承接默认端口实现函数集合。
- 收缩 `src/core/RuntimePorts.lua` 为“状态 + 路由”薄层，保持对外函数签名不变。

### 8.2 收缩效果（量化）

| 文件 | 改动前 | 改动后 | 变化 |
|---|---:|---:|---:|
| `src/core/RuntimePorts.lua` | 299 行 | 119 行 | **-180 行（-60.2%）** |

说明：总代码行并未追求“绝对减少”，而是把单热点文件的多职责膨胀拆散到边界明确的子模块，降低碰撞密度与维护复杂度。

### 8.3 验证结果

- `runtime_ports_contract`：`All regression checks passed (7)`
- `lua tests/internal/dep_rules.lua`：`dep_rules ok`
- `lua tests/regression.lua`：`All regression checks passed (213)`，且 `tick ok`、`forbidden_globals ok`

结论：本轮收缩在不改变可观察行为的前提下完成，且未破坏现有依赖治理。

### 8.4 剩余膨胀风险

- `src/presentation/api/HostRuntimePort.lua`：适配职责与 fallback 协调仍混合。
- `src/presentation/interaction/ui_intent_dispatcher/ViewCommandDispatcher.lua`：intent 分发与角色解析耦合仍在。

下一轮应继续按“单热点拆分 + 契约回归验证”模式推进，避免再次形成大文件集中碰撞。

# src/ 最近两天提交研究：代码膨胀视角（重新调研版，2026-03-02）

本文件是研究结论，不是执行计划。执行安排见 `.agents/plan.md`。

审查范围：
- 时间：最近两天（`git log --since='2 days ago'`）
- 路径：`src/`
- 方法：`git log --numstat` 聚合 + 提交级别净增分析 + 当前热点文件交叉检查

---

## 1. 总结结论

1. 最近两天 `src/` 共 **38 个提交**，总计 **+5812 / -4543，净增 +1269 行**，仍处于明显增长区间。
2. 结构性增长依旧集中在 `src/core` 与 `src/presentation`，其中 `src/core` 净增 **+737**、`src/presentation` 净增 **+569**。
3. 热点形态已从“单文件绝对膨胀”转为“热点簇膨胀”：`RuntimePorts.lua` 仍高频触达，同时新增 `runtime_ports/DefaultPorts.lua` 等相关模块。
4. `src/game` 目录净变化 **-89**，说明业务规则层总体没有同步扩张，增长仍主要发生在运行时边界与接口层。

---

## 2. 量化统计（最近两天）

### 2.1 全量变更

| 指标 | 数值 |
|---|---:|
| 提交数（仅 `src/`） | 38 |
| 新增行 | 5812 |
| 删除行 | 4543 |
| 净增长 | **+1269** |

### 2.2 按日期分布

| 日期 | 新增 | 删除 | 净增长 |
|---|---:|---:|---:|
| 2026-02-28 | 402 | 90 | +312 |
| 2026-03-01 | 2860 | 2563 | +297 |
| 2026-03-02 | 2550 | 1890 | +660 |

观察：3/2 的净增最高，且高于前两天，表明当前仍在增量推进阶段。

### 2.3 按目录聚合（`src/一级/二级`）

| 目录 | 新增 | 删除 | 净增长 |
|---|---:|---:|---:|
| `src/core` | 1132 | 395 | **+737** |
| `src/presentation` | 2853 | 2284 | **+569** |
| `src/app` | 175 | 123 | +52 |
| `src/game` | 1652 | 1741 | **-89** |

---

## 3. 膨胀热点

### 3.1 净增长 Top 文件（最近两天）

| 文件 | 新增 | 删除 | 净增长 |
|---|---:|---:|---:|
| `src/game/core/runtime/Agent.lua` | 181 | 9 | **+172** |
| `src/core/runtime_ports/DefaultPorts.lua` | 168 | 0 | **+168** |
| `src/presentation/api/HostRuntimePort.lua` | 138 | 2 | +136 |
| `src/presentation/render/ActionAnimOverlayRuntime.lua` | 146 | 15 | +131 |
| `src/core/RuntimePorts.lua` | 374 | 255 | +119 |
| `src/presentation/api/presentation_ports/UISyncPorts.lua` | 124 | 5 | +119 |
| `src/game/flow/turn/TickChoiceTimeout.lua` | 115 | 0 | +115 |
| `src/presentation/interaction/ui_intent_dispatcher/PreConfirmFlow.lua` | 110 | 0 | +110 |
| `src/game/flow/turn/GameplayLoopUISyncDefaults.lua` | 108 | 0 | +108 |
| `src/game/systems/land/LandRentResolver.lua` | 133 | 25 | +108 |

### 3.2 频繁改动文件（提交触达次数 Top）

| 文件 | 触达提交数 |
|---|---:|
| `src/core/RuntimePorts.lua` | 9 |
| `src/app/bootstrap/RuntimeInstall.lua` | 8 |
| `src/presentation/api/PresentationPorts.lua` | 6 |
| `src/presentation/render/MoveAnim.lua` | 6 |
| `src/presentation/render/board_runtime/placement.lua` | 6 |
| `src/core/RuntimeContext.lua` | 5 |
| `src/presentation/api/ui_view_service/item_slots.lua` | 5 |
| `src/presentation/interaction/UIIntentDispatcher.lua` | 5 |

判断：`RuntimePorts.lua` 已从“单点膨胀”转为“高频协调中枢”，膨胀风险仍在，但主要表现为改动集中度，而非仅看行数绝对值。

---

## 4. 对“代码膨胀”的判断

### 4.1 属于“必要显式化”的增长

- 边界与契约继续显式化：运行时能力在 `core` 与 `presentation` 之间被拆成更明确端口。
- 重构伴随替换删除：多次提交出现“高新增 + 高删除”对冲，说明不是纯堆叠式加法。
- 新增模块承接职责：`runtime_ports` 子模块增加，体现从大文件向分层模块迁移。

### 4.2 属于“真实膨胀风险”的增长

- 热点仍过度集中：`RuntimePorts.lua` 触达 9 次，仍是跨功能改动汇聚点。
- presentation 端接口持续扩张：`HostRuntimePort.lua`、`PresentationPorts.lua`、`UISyncPorts.lua` 继续增长。
- 运行时与交互层双热点并行增长：后续若缺少收口，会形成“多热点同时大文件化”。

---

## 5. 关键提交（净增长视角）

| 提交 | 主题 | 新增/删除 | 净增 |
|---|---|---:|---:|
| `410b9e9a` | runtime boundaries / remove proxies | 413 / 61 | **+352** |
| `4117055b` | R8/R9 boundary hardening | 678 / 354 | **+324** |
| `492055dd` | 二级确认与等待流程 | 189 / 1 | +188 |
| `b1a46d7d` | runtime guard + tests | 142 / 29 | +113 |
| `35fd46d0` | read model split / ui dispatch | 673 / 562 | +111 |

备注：这些高净增提交多数属于架构与边界演进阶段，解读时应结合删改规模，避免把“阶段性重构增长”误判为“低质量膨胀”。

---

## 6. 建议动作（围绕膨胀收敛）

1. 把热点治理目标从“单文件降行数”升级为“高频改动去中心化”：优先降低 `RuntimePorts.lua` 与 `RuntimeInstall.lua` 的改动集中度。
2. 对 presentation 端口做职责切面图：明确 `HostRuntimePort`、`PresentationPorts`、`UISyncPorts` 的边界，减少重复透传。
3. 引入热点碰撞告警：对“近两天触达次数 >=5 且净增>0”的文件在 PR 中要求附加拆分说明。
4. 下一轮优先对象：`HostRuntimePort.lua`、`ViewCommandDispatcher.lua`、`PresentationPorts.lua`。

---

## 7. 结论

重新调研后，最近两天 `src/` 仍是净增长态势（+1269），且增长主体继续集中在 `core/presentation` 边界层。当前风险重心不是”有没有增长”，而是”增长是否持续聚集在少数高频中枢文件”。后续治理应以”去中心化改动热点 + 端口职责去重”为主线，避免从单点膨胀演化为多点并发膨胀。

---

## 8. R17 执行结果（已落地）

本轮已按”热点去中心化交易”目标执行多热点协同收敛，聚焦 `presentation` 与 `bootstrap` 边界层。

### 8.1 已执行改动

- 拆分 `HostRuntimePort.lua`：新增 `host_runtime/RoleResolver.lua`、`UnitLifecycle.lua`、`SceneUI.lua` 承接职责。
- 拆分 `UISyncPorts.lua`：新增 `ui_sync/UIModelSync.lua`、`CameraSync.lua`、`UIGateSync.lua` 承接职责。
- 拆分 `ViewCommandDispatcher.lua`：新增 `RoleContext.lua` 承接角色解析。
- 拆分 `RuntimeInstall.lua`：新增 `runtime_install/RuntimePortDefaults.lua` 承接默认端口配置。

### 8.2 收缩效果（量化）

| 文件 | 改动前 | 改动后 | 变化 |
|---|---:|---:|---:|
| `src/presentation/api/HostRuntimePort.lua` | 136 行 | 80 行 | **-56 行（-41.2%）** |
| `src/presentation/api/presentation_ports/UISyncPorts.lua` | 119 行 | 44 行 | **-75 行（-63.0%）** |
| `src/presentation/interaction/ui_intent_dispatcher/ViewCommandDispatcher.lua` | 90 行 | 67 行 | **-23 行（-25.6%）** |
| `src/app/bootstrap/RuntimeInstall.lua` | 91 行 | 41 行 | **-50 行（-54.9%）** |
| **热点文件合计** | **436 行** | **232 行** | **-204 行（-46.8%）** |

新增承接模块（8 个）：

- `host_runtime/RoleResolver.lua` (51 行)
- `host_runtime/UnitLifecycle.lua` (33 行)
- `host_runtime/SceneUI.lua` (26 行)
- `ui_sync/UIModelSync.lua` (42 行)
- `ui_sync/CameraSync.lua` (30 行)
- `ui_sync/UIGateSync.lua` (62 行)
- `RoleContext.lua` (29 行)
- `RuntimePortDefaults.lua` (58 行)

### 8.3 验证结果

- `lua tests/internal/dep_rules.lua`：`dep_rules ok`
- `lua tests/regression.lua`：`All regression checks passed (213)`，`tick ok`，`forbidden_globals ok`

结论：本轮拆分在不改变可观察行为的前提下完成，且未破坏现有依赖治理。

### 8.4 剩余膨胀风险

- `src/presentation/api/PresentationPorts.lua`：端口协调职责仍可能随需求扩张。
- `src/core/RuntimePorts.lua`：作为核心运行时中枢，需持续监控改动频次。

下一轮应继续按”单热点拆分 + 契约回归验证”模式推进，避免再次形成大文件集中碰撞。

# Monopoly 深度研究重写（基于 R10 执行结果，Clean Architecture 视角）

技能使用：`clean-architecture-reviewer`

## 1) 研究目标与输入

本次重写以 `.agents/plan.md` 的 **R10（M40-M42）实际执行结果** 为输入，关注两点：

1. R10 是否把“兼容债务”从可观测推进到可退役阶段。
2. 结构收敛后，下一阶段应优先优化哪些复杂度热点。

---

## 2) 执行事实与证据基线

本轮已完成并验证：

- `lua tests/internal/dep_rules.lua` -> `dep_rules ok`
- `lua tests/regression.lua` -> `All regression checks passed (207)`

R10 关键落地点：

- M40：`StatusOps` 不再依赖 `RuntimeCompat`，改为依赖 `RuntimePorts.resolve_vehicle_helper()`；`RuntimeInstall` 注入 vehicle helper port。
- M41：`RuntimeContext.install_runtime_helpers()` 默认 `install_globals=false`；`RuntimeInstall.install(opts)` 显式控制兼容模式。
- M42：新增 `src/game/flow/turn/GameplayLoopTickFlow.lua`，从 `GameplayLoop.lua` 迁移 tick 编排热点逻辑，对外 API 保持不变。

---

## 3) Clean Architecture 体检结论

### 3.1 Dependency Rule

- 正向改进：`src/game/core/runtime/player_state/StatusOps.lua` 已移除对 `src.core.RuntimeCompat` 的依赖。
- 新守护：`tests/internal/dep_rules.lua` 新增 rule，禁止 `src/game/core` 再次 require `RuntimeCompat`。

结论：内层策略对外层兼容桥的反向依赖已实质消除，依赖方向更符合同心圆。

### 3.2 Boundary Crossing

- 运行时 vehicle 能力由 `RuntimeInstall -> RuntimePorts.configure` 注入。
- core 只消费 `RuntimePorts` 抽象，不感知 compat/global 细节。

结论：边界穿越点更集中，可替换性增强。

### 3.3 Details Deferred

- legacy globals 写入由默认行为改为显式开关。
- 常规路径默认不写 `all_roles/vehicle_helper/camera_helper`，仅兼容模式可显式开启。

结论：默认行为已切到 context-first，兼容路径成为受控细节。

---

## 4) 热点复杂度复盘（R10 后）

- `GameplayLoop.lua`：保留 API 与装配职责。
- `GameplayLoopTickFlow.lua`：承接 tick 编排（phase sync/timeout/dirty refresh）。
- `GameplayLoopRuntime.lua`：继续承载行为工具层。

结论：R10 的拆分方式是“语义不变、职责迁移”，降低主文件认知负担且不扩大行为回归面。

---

## 5) 架构状态判断

**当前已达到“兼容退役最小闭环”。**

- 规则层：dep_rules 守护升级并通过。
- 行为层：全量回归 207 全绿。
- 结构层：反向依赖消除、默认行为收紧、热点继续瘦身。

仍需关注的残余风险：

- `RuntimeCompat` 仍在 app/presentation 若干模块中使用，短期可控，但中长期仍建议继续减面。
- `GameplayLoopRuntime.lua` 仍偏厚，后续可按“锁控制/计时器/相机同步”再分层。

---

## 6) 下一阶段建议（R11 候选）

1. 将 `RuntimeInstall.install(opts)` 的兼容开关接入明确环境配置，并补一组启动路径测试（兼容开/关）。
2. 继续拆 `GameplayLoopRuntime.lua`，优先抽离 role control lock 与 action/detained timer 纯策略段。
3. 对 presentation 层 `RuntimeCompat` 使用点建立分批替换清单（按 `roles/vehicle/camera` 三类端口化）。

---

## 7) 最终结论

R10 不是表面整理，而是完成了一轮可验证的架构收敛：

- 依赖方向更正确；
- 边界更可控；
- 默认行为更安全；
- 回归与守护规则保持全绿。

这为后续继续退役 compat 与进一步降低 turn 复杂度提供了稳定基线。

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

---

## 8) 本次复验更新（2026-03-02）

本次按执行请求重新复验：

- `lua tests/internal/dep_rules.lua` -> `dep_rules ok`
- `lua tests/regression.lua` -> `All regression checks passed (207)`（含 `tick ok`、`forbidden_globals ok`）

补充执行注意事项：`tests/suites/gameplay_core.lua` 依赖回归入口提供 package.path，直接单跑会出现 `module 'gameplay_registry' not found`；因此该套件应通过 `tests/regression.lua` 统一执行。

---

## 9) R11 执行结果更新（2026-03-02）

本次按新版 `.agents/plan.md` 完整执行 R11（M43-M45），并完成全量验收。

### 9.1 关键落地

- M43（roles 端口化）：新增 `RuntimePorts.resolve_roles()`，并将 `UIRuntimePort` / `UIBootstrap` / `GameStartup` / `player_units` / `scene` / `ViewCommandDispatcher` 从 `RuntimeCompat` 切换到 `RuntimePorts`。
- M44（vehicle/camera 端口化）：新增 `RuntimePorts.resolve_camera_helper()`；`MoveAnim` / `placement` / `UISyncPorts` 改为 `RuntimePorts` 获取 helper。
- M45（守护与收口）：`dep_rules` 新增 app/presentation 禁止依赖 `RuntimeCompat`；增加 tests 最小白名单守护（仅 `runtime_compat_contract`）；`RuntimeCompat` 标记 deprecated 且默认 `strict_context_first=true`；契约测试新增“默认 strict”断言。

### 9.2 执行中发现与修正

- 首轮替换后 `presentation_ui` 出现 2 个回归失败，原因是 `resolve_roles()` 初版没有保留 `all_roles/ALLROLES` fallback；补回后恢复通过。
- 首轮在 `RuntimeInstall` 直接 `require RuntimeCompat` 配置 strict 被 `dep_rules` 拦截；最终改为 `RuntimeCompat` 默认 strict，保持 app 层零依赖。

### 9.3 最终证据

- `lua tests/internal/dep_rules.lua` -> `dep_rules ok`
- `lua tests/regression.lua` -> `All regression checks passed (208)`
- 同次输出包含：`tick ok`、`forbidden_globals ok`

结论：R11 已把 RuntimeCompat 从业务路径收敛到“契约测试/应急兼容专用”，兼容桥进入可删除前状态，且守护规则可持续阻止回退。

---

## 10) 后续两轮里程碑判断（R12-R13）

基于 R11 收口结果，后续两轮建议如下：

### R12：优先降低 turn 复杂度（达标概率：高）

- 目标：继续降低 `GameplayLoopRuntime.lua` 认知负担，不改变对外 API 与时序语义。
- 建议里程碑：
  1. M46 抽离 action/detained timer 纯策略段；
  2. M47 抽离 role lock/camera follow 策略段；
  3. M48 补齐 `gameplay_loop` / `gameplay_runtime` 覆盖并完成回归验收。

判断：R10 已完成 `GameplayLoopTickFlow` 拆分，R11 未再扩大 turn 语义面，当前具备继续“同语义拆分”的稳定基线。

### R13：执行 compat 物理退役（达标概率：中高）

- 目标：将 `RuntimeCompat` 从“可删除前状态”推进到“可物理删除并守护稳定”。
- 建议里程碑：
  1. M49 清理 compat 残留路径并评估删除 `RuntimeCompat.lua`；
  2. M50 重构对应契约/回归覆盖，保留必要迁移说明；
  3. M51 升级 dep_rules 与回归守护，阻止任何 compat 回退。

判断：R11 已实现业务零依赖与规则守护，R13 的核心风险不在代码替换，而在测试契约重构与回退路径定义，属于可控风险。

### 执行工作流（每轮统一）

1. 基于研究文档确定下一轮里程碑与风险；
2. 在可执行计划文档拆分里程碑（范围/改动点/验证口径）；
3. 完整执行全部里程碑并完成局部 + 全量验证；
4. 更新研究文档记录落地事实、证据与偏差；
5. 提交（里程碑提交 + 轮次收口提交）。

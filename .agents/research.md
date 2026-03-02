# Monopoly 代码库清理研究（基于当前工作树）

本文件是调研结论，不是执行计划。执行细节见 `.agents/plan.md`。

更新时间：2026-03-02
审查方法：Clean Architecture Reviewer（Dependency Rule / 用例边界 / 端口适配）

---

## 1. 执行摘要

当前工作树已完成两项高价值收敛：
1. runtime legacy 兼容开关旧 API 已退役，运行时统一使用分项策略接口。
2. 载具事件接口已统一到 `emit_vehicle_*`，`forward_eca_event_*` 在 `src/tests` 检索清零。

结论：兼容层已从“历史双轨并行”进入“策略受控 + 命名统一”阶段，后续应聚焦策略层进一步瘦身，而不是再做命名迁移。

---

## 2. Clean Architecture 审查结论

### 架构结论

当前设计总体符合 Clean Architecture 的核心约束：运行时边界通过端口收敛，外层细节不再通过历史别名向内层渗透。系统仍保留受控 legacy 策略，但已不属于无边界兼容状态。

### 主要问题（P0-P3）

- P0：未发现核心业务直接被外部细节硬绑定且不可替换的阻断问题。
- P1：`context_policy = "legacy"` 仍是在役策略，说明降级路径尚未彻底退场。
- P1：`enable_legacy_helper_fallback` 仍可开启 helper 全局回退，需持续限制其使用面。
- P2：`RuntimePorts` 仍承担“策略配置 + 默认实现 + 兼容语义”多重职责，后续可继续拆薄。
- P3：测试命名与注释中仍有少量“legacy”历史语义，虽不影响行为，但增加长期认知负担。

### 重构方案（最小可落地）

1. 已完成：旧兼容开关 API 退役
- 影响范围：`src/core/RuntimePorts.lua`、`tests/suites/runtime_ports_contract.lua`
- 预期收益：删除无调用兼容 API，减少边界噪音与误用入口。
- 回归风险：低，已由回归和契约验证覆盖。

2. 已完成：forward 事件别名退役
- 影响范围：`RuntimeContext`、`StatusOps`、`MoveAnim`、`board_runtime/placement`、相关测试桩
- 预期收益：接口语义统一到 `emit_vehicle_*`，跨层沟通成本下降。
- 回归风险：低到中，已通过分阶段迁移与全量回归消化。

3. 建议下一步：legacy 策略使用面继续收口
- 影响范围：`RuntimeInstall`、调用入口与运行配置
- 预期收益：将 legacy 从“常规可选”收敛为“极少数受控场景”。
- 回归风险：中，需要入口级灰度和契约补强。

4. 建议后续：RuntimePorts 职责拆薄（可选）
- 影响范围：`RuntimePorts` 与调用方注入层
- 预期收益：降低单模块复杂度，提升可替换性与可测性。
- 回归风险：中，属于结构性优化，应分批执行。

### 测试建议

1. 用例级测试：继续使用黑盒行为验证，不对旧兼容接口名做断言。
2. 边界契约测试：保留 strict/legacy 双态契约，并追加 legacy 使用面约束断言。
3. 放行门槛：每批次保持 `lua tests/regression.lua` + `lua tests/internal/dep_rules.lua` 全绿。

### 权衡说明

短期保留 legacy 策略能降低运行环境切换风险，但会增加持续维护成本。当前代码库已完成“低风险高收益”的兼容别名退役，下一步应在风险可控前提下继续压缩 legacy 入口，而不是再扩张兼容语义。

---

## 3. 现状盘点（关键模块）

### A. Runtime 策略层

- 核心文件：
  - `src/core/RuntimePorts.lua`
  - `src/app/bootstrap/RuntimeInstall.lua`
  - `tests/suites/runtime_ports_contract.lua`
- 现状：
  - 分项策略 API 在役：`set_legacy_fallback_policy` / `legacy_fallback_policy`。
  - 旧兼容开关 API 已删除。
  - `context_policy = "legacy"` + `enable_legacy_helper_fallback` 仍保留。
- 判断：
  - 处于“可控兼容”阶段；下一步是策略入口收口而非接口命名清理。

### B. 事件发射链

- 核心文件：
  - `src/core/RuntimeContext.lua`
  - `src/game/core/runtime/player_state/StatusOps.lua`
  - `src/presentation/render/MoveAnim.lua`
  - `src/presentation/render/board_runtime/placement.lua`
- 现状：
  - `emit_vehicle_*` 统一在役。
  - `forward_eca_event_*` 已移除。
- 判断：
  - 该链路本轮清理闭环完成。

### C. 仍在役但不建议本批删除

- `src/core/RuntimeEventBridge.lua`
- `src/core/events/MonopolyEvents.lua`
- `src/presentation/shared/UIAliases.lua`

判断：这些模块仍承担稳定职责，不属于“死兼容层”，应避免与 runtime 策略收口混批改动。

---

## 4. 验证证据（当前工作树）

执行命令：
- `rg "set_legacy_global_fallback_enabled|legacy_global_fallback_enabled\(" src tests -n`
- `rg "forward_eca_event_" src tests -n`
- `rg "set_legacy_fallback_policy\(|context_policy|enable_legacy_helper_fallback" src tests -n`
- `lua tests/regression.lua`
- `lua tests/internal/dep_rules.lua`

结果摘要：
1. 旧兼容开关 API 检索清零（No matches）。
2. forward 旧事件接口检索清零（No matches）。
3. 分项策略与 legacy 策略入口仍可稳定检索（符合当前受控设计）。
4. 回归通过：`All regression checks passed (210)`，`dep_rules ok`，`tick ok`，`forbidden_globals ok`。
5. 依赖规则单测通过：`dep_rules ok`。

---

## 5. 下一阶段建议

1. 继续收口 legacy 使用面
- 把 `context_policy = "legacy"` 的实际使用场景做清单化，限制新增入口。

2. 明确 helper fallback 使用治理
- 对 `enable_legacy_helper_fallback` 增加调用审计或测试约束，避免回退路径扩散。

3. 维持放行纪律
- 每批清理必须同时满足契约测试与全量回归通过。

完成条件：
- 业务行为不变。
- strict 路径覆盖完整。
- legacy 策略入口持续收敛且可追踪。

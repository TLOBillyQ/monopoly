# Monopoly 代码清理调研（兼容层 / 遗留 / 转发）

本文件是调研与审查备忘，不是可执行计划。执行步骤与过程记录见 `.agents/plan.md`。

更新时间：2026-03-02
审查方法：Clean Architecture Reviewer（Dependency Rule / 用例边界 / 端口适配）
文档重写方式：Doc Co-authoring（以读者可验证为中心）

---

## 1. 执行摘要

本轮在“可控降级保留”的前提下，完成了两类关键收敛：
1. legacy fallback 从“总开关 + 默认全开”收敛为“分项策略 + 默认角色相关 fallback”。
2. 载具事件接口完成 `forward_eca_event_*` 到 `emit_vehicle_*` 的迁移与退役，仓库已不存在 forward 旧名调用。

对读者可见结果：
- 运行时兼容策略更可解释，默认行为更窄。
- 事件接口命名统一，减少历史命名噪音。
- 回归与依赖规则持续全绿，行为未回归。

---

## 2. Clean Architecture 审查结论

### 架构结论

当前设计满足“核心策略优先、细节后置”的演进方向。兼容层仍存在，但已从“混合职责”演进为“边界内显式策略”，变更扩散风险明显下降。

### 主要问题（P0-P3）

- P0：未发现核心业务被外部细节直接控制、且无法替换的阻断问题。
- P1：legacy fallback 仍在役，`set_legacy_global_fallback_enabled` 仍保留兼容接口，后续仍需明确退役窗口。
- P1：`enable_legacy_helper_fallback` 目前仅少量显式使用，需继续监控避免新增隐式依赖点。
- P2：运行时端口层同时承载“策略配置 + 兼容桥接”职责，仍可继续拆薄但不构成当前阻断。
- P3：文档与术语一致性已提升，但历史上下文在部分测试描述里仍需持续压缩。

### 重构方案（最小可落地步骤）

1. 已完成：legacy fallback 分项策略化
- 影响范围：`src/core/RuntimePorts.lua`、`src/app/bootstrap/RuntimeInstall.lua`、`tests/suites/runtime_ports_contract.lua`
- 预期收益：从单一总开关转为能力位控制（`roles/role/vehicle/camera`），默认更安全。
- 回归风险：低；通过契约测试覆盖默认收敛与显式放开两条路径。

2. 已完成：`forward_eca_event_*` 迁移与退役
- 影响范围：`src/core/RuntimeContext.lua`、`StatusOps`、`MoveAnim`、`placement`、相关测试桩
- 预期收益：统一事件语义为 `emit_vehicle_*`，降低边界命名历史负担。
- 回归风险：中到低；先迁移测试调用再删除兼容别名，分阶段落地。

3. 已完成：测试初始化收敛
- 影响范围：`tests/TestSupport.lua`
- 预期收益：减少对旧兼容开关 API 的默认依赖，改为显式分项策略。
- 回归风险：低；全量回归验证通过。

4. 下一步：兼容开关退役准备
- 影响范围：`RuntimePorts` 兼容 API 与契约测试
- 预期收益：进一步压缩兼容面，减少未来维护分叉。
- 回归风险：中；需要先确认仓库与外部注入路径无旧接口依赖。

### 测试建议

1. 用例级测试：继续围绕移动/停靠/状态同步做黑盒验证，不绑定旧接口名。
2. 边界契约测试：保持 strict 与 legacy 两态契约，并为退役阶段增加“旧接口清零”断言。
3. 回归门槛：每批次继续执行 `lua tests/regression.lua` + `lua tests/internal/dep_rules.lua`。

### 权衡说明

短期成本是迁移期间存在策略与契约双维护；长期收益是边界更稳定、接口更统一、细节更可替换。当前策略遵循“先迁移再删除”的低风险路径，符合持续交付约束。

---

## 3. 提交后代码库审查与清理结果

### A. 本轮关键提交

- `d8245ca`：`refactor(runtime): scope legacy fallback policy by capability`
- `42a8d7a`：`refactor(runtime): retire forward vehicle event aliases`

### B. 已落地清理

1. legacy fallback 策略分项化
- `RuntimePorts` 新增 `set_legacy_fallback_policy` / `legacy_fallback_policy`。
- `RuntimeInstall` 默认 legacy 仅开角色相关 fallback，helper fallback 需 `enable_legacy_helper_fallback = true`。

2. forward 旧接口退役
- 删除 `RuntimeContext` 的 `forward_eca_event_*` 兼容别名。
- 生产调用统一为 `emit_vehicle_*`。

3. 测试与引导收敛
- `tests/suites/gameplay.lua`、`tests/suites/presentation_ui.lua` 测试桩迁移为 `emit_vehicle_*`。
- `tests/TestSupport.lua` 改用分项策略初始化。

### C. 仍保留的兼容点（有意）

- `RuntimePorts.set_legacy_global_fallback_enabled` 与 `legacy_global_fallback_enabled` 仍保留，当前仅作兼容层 API。
- `runtime_ports_contract` 仍保留对该兼容开关的验证断言，作为退役前保护。

---

## 4. 验证证据

执行命令：
- `lua tests/regression.lua`
- `lua tests/internal/dep_rules.lua`
- `rg "forward_eca_event_" src tests -n`
- `rg "set_legacy_global_fallback_enabled|legacy_global_fallback_enabled" src tests -n`
- `rg "enable_legacy_helper_fallback|set_legacy_fallback_policy\(" src tests -n`

结果摘要：
1. 回归通过：`All regression checks passed (210)`，`dep_rules ok`，`tick ok`，`forbidden_globals ok`。
2. 依赖规则单测通过：`dep_rules ok`。
3. `forward_eca_event_*` 在 `src/tests` 检索清零。
4. legacy 兼容开关仅剩兼容 API 本体 + 契约测试断言。
5. 分项策略与 helper opt-in 在运行时安装与测试中可被稳定检索。

---

## 5. 不建议当前批次直接删除的项

1. `set_legacy_global_fallback_enabled`（兼容入口）
- 原因：仍有契约测试覆盖；需先做仓库外依赖确认再下线。

2. `RuntimeEventBridge`
- 原因：承担自定义事件的安全发射与降级保护，不应与接口清理混改。

3. `MonopolyEvents`
- 原因：事件名目录化仍有强组织价值。

4. `UIAliases`
- 原因：Canvas 迁移尚未完成，仍为在役适配层。

---

## 6. 下一阶段建议（与 plan 对齐）

1. 发起兼容开关退役预检
- 清点仓库外/启动脚本是否仍依赖 `set_legacy_global_fallback_enabled`。

2. 若预检通过，执行兼容 API 退役
- 删除 `set_legacy_global_fallback_enabled`/`legacy_global_fallback_enabled` 及对应兼容断言。

3. 保持放行标准不变
- 每批次必须通过契约测试与全量回归。

完成条件：
- 业务行为不变。
- strict 路径覆盖完整。
- legacy 兼容入口具备明确下线证据并完成移除。

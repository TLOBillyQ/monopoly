# Monopoly 代码库近期变更研究（2026-03-02）

本文件是调研结论，不是执行计划。执行细节见 `.agents/plan.md`。

更新时间：2026-03-02
审查范围：最近两天（约48小时）src/ 目录变更
审查方法：Git 历史分析 + CLOC 代码统计

---

## 1. 执行摘要

最近两天代码库经历大规模架构重构，主要成果：

1. **运行时边界收紧**：完成 R5-R14 多轮重构，RuntimeCompat 桥接层已退役，legacy 策略进入受控阶段。
2. **事件接口统一**：载具事件接口统一到 `emit_vehicle_*`，`forward_eca_event_*` 已清零。
3. **读写模型拆分**：完成读模型分离和 UI 意图分发层重构，模块职责更清晰。

结论：代码库正从"双轨兼容"向"严格分层 + 受控降级"演进，代码总量增长约 7%，但架构清晰度显著提升。

---

## 1.1 对“代码量膨胀”的回应（反思与辩护）

这个指责成立一半：从净行数看，`src/` 近期确实是增长而不是下降，我接受这个事实，也接受这会带来阅读与维护成本。

我的反思是：这轮清理优先目标是“先让边界可验证，再谈体量压降”。因此我采用了并行迁移、契约补强、规则治理三件套。它会在阶段内增加一些代码（端口策略、契约断言、治理规则），短期看像膨胀。

我的辩护是：这次增长主要是“风险显性化代码”，不是“功能重复代码”。证据是三条：
1. 历史兼容入口已真实退役：`set_legacy_global_fallback_enabled` 与 `forward_eca_event_*` 检索清零。
2. 风险从“靠人记忆”变成“靠规则阻断”：`dep_rules` 已对 legacy 扩散做硬约束。
3. 行为稳定性未退化：全量回归和依赖规则持续全绿。

我仍承认：如果后续只做治理加法，不做结构减法，就会形成新的“治理性膨胀”。所以这份辩护必须绑定后续动作：继续收口 legacy 入口，并推进 RuntimePorts 职责拆分，逐步把阶段性防护代码折叠掉。

---

## 2. 代码量变化统计

### 总体变化

| 指标 | 起始值 | 当前值 | 净变化 | 变化率 |
|------|--------|--------|--------|--------|
| **文件数** | 218 | 246 | +28 | +12.8% |
| **代码行数** | 15,691 | 16,742 | +1,051 | +6.7% |
| **空行数** | 1,937 | 2,114 | +177 | +9.1% |
| **注释行数** | 63 | 67 | +4 | +6.3% |

### 增删行数汇总

| 指标 | 数量 |
|------|------|
| 新增代码行 | 5,613 |
| 删除代码行 | 4,381 |
| **净变化** | **+1,232** |

> 注：CLOC 统计与 git diff 统计略有差异，前者统计有效代码行，后者包含空行和注释变更。

---

## 3. 主要变更分析

### 3.1 架构收敛（最大变更集）

| 提交 | 说明 | 变更行数 | 影响 |
|------|------|----------|------|
| `df73efa3` | execute architecture convergence plan | +753 / -1,073 | 核心架构整合 |
| `410b9e9a` | refactor runtime boundaries and remove core runtime proxies | +413 / -61 | 移除运行时代理层 |
| `4117055b` | complete R8/R9 boundary hardening and contracts | +678 / -354 | 边界硬化与契约 |
| `27e7916b` | execute R5 clean-architecture plan | +577 / -495 | 干净架构落地 |

**关键成果**：
- RuntimeCompat 桥接层已删除（`5a24f5ed` 移除 100 行）
- 旧兼容开关 API 已退役（`set_legacy_global_fallback_enabled` 等）
- `forward_eca_event_*` 别名已清零

### 3.2 模型层拆分

| 提交 | 说明 | 变更行数 |
|------|------|----------|
| `35fd46d0` | split read model and refactor UI intent dispatch | +673 / -562 |
| `bc2e0f81` | Refactor land rules and introduce rent resolver | +441 / -394 |
| `ea68a86c` | refactor reduce duplicated semantics in milestones m16-m18 | +132 / -166 |

**关键成果**：
- 读模型与写模型分离
- 土地规则与租金解析器解耦
- M16-M18 里程碑语义去重

### 3.3 回合与 Tick 流程

| 提交 | 说明 | 变更行数 |
|------|------|----------|
| `4973e2e5` | split tick runtime policies | +162 / -140 |
| `66eb297a` | finish step3 and plan step4 gameplay loop split | +165 / -57 |
| `afa02c79` | complete step4 tick flow split and docs backfill | +94 / -88 |

**关键成果**：
- Tick 运行时策略拆分
- 游戏循环分阶段落地

### 3.4 功能性改进

| 提交 | 说明 | 变更行数 |
|------|------|----------|
| `492055dd` | 骰子等待 0.9s + 通用二级确认拦截 | +189 / -1 |
| `d939f70a` | update item slot highlight reset logic and test | +33 / -8 |
| `b1a46d7d` | guard TriggerCustomEvent and add degradation tests | +142 / -29 |

---

## 4. 架构演进评估

### 4.1 当前架构状态

```
┌─────────────────────────────────────────┐
│  Presentation (UI / Render / Input)     │
├─────────────────────────────────────────┤
│  Runtime Ports (统一接口层)              │
├─────────────────────────────────────────┤
│  Core Domain (Game Logic / Rules)       │
└─────────────────────────────────────────┘
```

- **边界清晰度**：✅ 运行时边界已通过端口收敛
- **兼容层状态**：⚠️ 受控 legacy 策略仍在役，但不可滥用
- **事件链**：✅ 统一到 `emit_vehicle_*` 命名体系

### 4.2 技术债务变化

| 债务项 | 状态 | 说明 |
|--------|------|------|
| RuntimeCompat 桥接 | ✅ 已清理 | 完全退役 |
| forward_eca_event 别名 | ✅ 已清理 | 检索清零 |
| 旧兼容开关 API | ✅ 已清理 | 无调用入口 |
| legacy 策略入口 | ⚠️ 受控 | `context_policy` / `enable_legacy_helper_fallback` 仍在 |
| RuntimePorts 职责 | ⚠️ 待拆分 | 仍承担策略+实现+兼容多重职责 |

---

## 5. 验证状态

### 回归测试结果

- `lua tests/regression.lua`: ✅ All regression checks passed (210)
- `lua tests/internal/dep_rules.lua`: ✅ dep_rules ok
- Tick 测试: ✅ tick ok
- 全局禁用检查: ✅ forbidden_globals ok

### 代码检索验证

| 检索项 | 结果 | 说明 |
|--------|------|------|
| `set_legacy_global_fallback_enabled` | 0 matches | ✅ 已清理 |
| `forward_eca_event_` | 0 matches | ✅ 已清理 |
| `context_policy.*legacy` | 少量匹配 | ⚠️ 受控使用 |
| `enable_legacy_helper_fallback` | 少量匹配 | ⚠️ 受控使用 |

---

## 6. 下一阶段建议

### P1：legacy 策略收口（高优先级）

1. **清单化 legacy 使用场景**
   - 盘点所有 `context_policy = "legacy"` 的实际调用点
   - 建立使用审批机制，禁止新增入口

2. **helper fallback 治理**
   - 对 `enable_legacy_helper_fallback` 增加调用审计
   - 逐步替换为显式策略注入

### P2：RuntimePorts 职责拆分（中优先级）

1. **策略配置与实现分离**
   - 将策略配置抽取到独立模块
   - 默认实现通过依赖注入提供

2. **兼容语义外移**
   - legacy 兼容逻辑下沉到适配器层
   - 核心端口保持纯粹契约

### P3：测试与文档（持续）

1. **维持放行纪律**
   - 每批改动必须通过全量回归
   - 契约测试覆盖率不下降

2. **文档同步**
   - 架构变更同步更新 ADR
   - 模块职责说明更新 README

---

## 7. 结论

最近两天的变更代表了代码库从"兼容双轨"到"严格分层"的关键转折。虽然代码总量增长约 7%，但：

- 架构清晰度显著提升
- 运行时边界更加明确
- 技术债务有效收敛

**核心判断**：当前处于架构收敛的收获期，低风险高收益的清理已基本完成。下一步应在风险可控前提下继续压缩 legacy 入口，避免再次扩张兼容语义。

完成条件：
- 业务行为不变（回归全绿）
- strict 路径覆盖完整
- legacy 策略入口持续收敛且可追踪

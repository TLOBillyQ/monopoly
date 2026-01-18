# 代码审查高阶总结

## 主要发现

### [Medium] 计时规则重复
- **位置**：`item_phase.lua` (line 20) 和 `item_strategy.lua` (line 62)
- **问题**：`PHASE_TIMING` / `timing_allowed` 重复导致 AI 计时与 UI 计时不同步
- **方案**：合并到单一来源以减少代码

### [Medium] 租税流程分散
- **位置**：`land.lua` (line 67) 和 `land_actions.lua` (line 133)
- **问题**：支付流程分散且重复（owner/mountain 检查重复两次）
- **关联**：`land_choice_handler.lua` (line 11)
- **方案**：集中支付逻辑，保持选择编排分离

### [Low] DecisionEngine 为瘦代理
- **位置**：`decision_engine.lua` (line 1)
- **问题**：仅被 `item_phase.lua` (line 91) 和 `turn_manager.lua` (line 20) 使用
- **方案**：内联并删除

### [Low] landing_effects.lua 仅做列表连接
- **位置**：`landing_effects.lua` (line 1)
- **问题**：仅连接配置列表
- **关联**：`turn_land.lua` (line 1) 和 `choice_service.lua` (line 84)
- **方案**：直接在调用处组合，删除该文件

### [Low] item_strategy 中有多个转发
- **位置**：`item_strategy.lua` (line 7)
- **问题**：多个转发到 Agent
- **方案**：直接调用 Agent，仅保留 `auto_pre_action`

### [Low] "use/skip" 选择规范重复
- **位置**：`land_choice_specs.lua` (line 3)、`item_steal.lua` (line 39)、`market_service.lua` (line 130)
- **问题**：选择规范样板代码重复
- **方案**：添加小型共享 builder 来减少重复

## 问题与假设

1. **外部模块依赖**：假设无外部模块依赖 `decision_engine.lua` 或 `landing_effects.lua`
2. **choice kind 稳定性**：假设 choice kind 字符串对 UI 层在约定上保持稳定
3. **AI 计时同步**：假设 AI 计时必须与玩家计时保持同步，因此合并 `PHASE_TIMING` 可接受
4. **共享 helper 接受度**：假设小型共享 choice-spec helper 可接受（移除重复的 options/allow_cancel 字面值）

## 实施路线图

### Phase 1：移除瘦代理
- 内联并删除 `decision_engine.lua` 和 `landing_effects.lua`
- 调整相关调用点

### Phase 2：集中计时规则
- 统一 `PHASE_TIMING + timing_allowed` 到单一来源
- 在玩家和 AI 路径中复用

### Phase 3：集中租税流程
- 将支付逻辑归属于 LandActions
- Land 仅负责触发选择

### Phase 4：添加共享选择规范 helper
- 创建最小化 yes/no choice-spec helper
- 替换重复的字面值

## 测试状态

- 仅代码审查，未运行测试

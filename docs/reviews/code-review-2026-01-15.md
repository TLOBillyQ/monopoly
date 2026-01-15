# 蛋仔大富翁 (Monopoly) 代码评审报告

**评审日期**: 2026年1月15日  
**项目**: Lua 大富翁棋盘游戏 + LÖVE2D 适配层  
**评审范围**: 核心运行时组装、回合流程与状态管理

---

## 📋 总体结论

整体架构清晰、分层合理，关键流程通过 `Flow` 和 `TurnManager` 管控，状态集中在 `Store` 中，具备良好的可维护性。当前评审范围内未发现明显逻辑错误，但有两处“潜在风险点”建议确认或加固。

---

## ✅ 亮点

### 1. 统一依赖组装点
- `CompositionRoot` 将游戏对象与服务集中组装，避免了散落式依赖注入，利于追踪初始化路径与状态绑定。
- 参考: [src/gameplay/composition_root.lua](src/gameplay/composition_root.lua#L1-L156)

### 2. 回合流程状态机清晰
- `TurnManager` 使用 `Flow` 进行阶段驱动，各阶段职责单一、流程清楚。
- 参考: [src/gameplay/turn_manager.lua](src/gameplay/turn_manager.lua#L1-L147)

### 3. 状态容器保持简单
- `Store` 只包含 `get/set`，降低心智负担，利于未来可控扩展（如观察者或快照）。
- 参考: [src/core/store.lua](src/core/store.lua#L7-L33)

---

## ⚠️ 风险与建议

### 1. `Store:set()` 在路径冲突时可能引发异常
- 当前实现若中间节点已是非 `table` 类型，后续 `node[key]` 会对非表索引并触发运行时错误。该情况若发生，会导致状态写入阶段崩溃。
- 参考: [src/core/store.lua](src/core/store.lua#L25-L33)
- 建议：
  - 在写入前对中间路径进行类型断言，或
  - 明确策略：若冲突则覆盖为 `{}` / 抛错 / 记录日志。

### 2. `TurnManager:dispatch()` 对 `nil` action 的处理需确认调用约束
- 当 `choice` 存在且 `action == nil` 时，`ChoiceResolver.resolve()` 会被调用并被视为取消，从而清空选择。这在“未显式用户动作但触发 dispatch”时可能导致选择被意外取消。
- 参考: [src/gameplay/turn_manager.lua](src/gameplay/turn_manager.lua#L60-L68)
- 建议：
  - 约束调用方不传 `nil`，或
  - 在 `dispatch` 中显式保护 `action == nil` 的情况。

---

## ✅ 结论

当前代码在架构设计和流程控制方面表现稳定，具备良好可扩展性。建议优先确认 `Store:set()` 的路径冲突策略，并核实 `dispatch(nil)` 的实际调用场景，以避免潜在“静默清空选择”或运行时异常。

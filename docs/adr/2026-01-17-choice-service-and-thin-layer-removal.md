# ADR-001：choice_service 拆分与薄层删除

**日期**: 2026-01-17  
**状态**: 已采纳

## 背景
choice_service.lua 承担了过多职责，且存在多处薄包装层（如 choice.lua、landing_resolver.lua）。这导致可维护性下降、重复逻辑增加、修改成本上升。

## 决策
- 拆分 choice_service.lua 为主入口 + choice_handlers/ 子模块。
- 移除不必要的包装层，调用点直接使用核心服务。
- 保持对外行为不变，仅调整内部结构与依赖关系。

## 结果
- 选择系统逻辑按场景分离，职责更清晰。
- 重复代码减少，测试覆盖点更聚焦。
- 依赖方向保持不变，deps_check 通过。

## 影响范围
- src/gameplay/choice_service.lua
- src/gameplay/choice_handlers/
- src/gameplay/turn_land.lua
- src/gameplay/landing_resolver.lua（已删除）
- src/gameplay/choice.lua（已删除）

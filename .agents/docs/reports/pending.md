## 2025-03-04 目录重构草案（src/game）

目标：按领域/特性分包，并分阶段兼容迁移。

映射草案：
- land/ -> systems/land/
- item/ -> systems/items/
- market/ -> systems/market/
- chance/ -> systems/chance/
- vehicle/ -> systems/vehicle/
- movement/ -> systems/movement/
- board/ -> systems/board/
- effect/ -> systems/effects/
- choice/ -> systems/choices/
- player/ -> core/player/
- game/ -> core/runtime/
- turn/ -> flow/turn/
- intent/ -> flow/intent/
- commerce/ -> systems/commerce/

依赖方向规则：
- core/ 与 flow/ 可依赖 systems/* 的公开入口。
- systems/* 不得依赖 flow/ 与 core/ 的实现文件（仅允许依赖 core 的稳定接口或模型）。
- flow/ 内部不得直接引用 systems 的内部子模块，只允许入口模块。


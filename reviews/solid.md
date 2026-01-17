# SOLID 评估（覆盖 src/ 下全部 Lua）

范围：`src/` 下全部 Lua 文件（gameplay/core/util/config/adapters 以及 `src/game.lua`）。

## 总体结论
- **SRP**：核心玩法与回合驱动模块普遍承担“规则 + 状态写入 + 选择意图/AI + 日志”，职责混合明显；core/util/config 责任较清晰。
- **OCP**：多数扩展点为“表驱动 + 追加”，但新增玩法仍需修改中心文件（如 item/land/choice/turn 管线）。
- **LSP**：继承使用极少，替换性主要依赖“结构型约定”；对 `game`/`player`/`services` 的隐式协议要求很高。
- **ISP**：多处函数依赖“大上下文对象”，接口粒度偏粗；局部依赖注入存在但不统一。
- **DIP**：高层逻辑大量直接 `require` 具体模块；少数服务通过 `services` 或 `deps` 注入，但抽象层不足。

## 目录级评估
### src/config
- 仅提供静态配置（地图/道具/角色/数值等）。
- 主要是数据表，SOLID 评价点有限；依赖方向清晰，几乎无 SRP/LSP/ISP/DIP 风险。

### src/util
- `logger.lua`, `random.lua`, `tables.lua`, `convert.lua`, `intent_dispatcher.lua` 等均是单一职责工具模块。
- `intent_dispatcher.lua` 有 UI 意图与 store 写入的边界职责，稍有耦合但仍可接受。

### src/core
- `board.lua`, `dice.lua`, `rng.lua`, `inventory.lua`, `store.lua`, `tile.lua` 是较清晰的底层模型/工具。
- `player.lua` 负责角色状态、资产、道具、神明/座驾逻辑；职责偏多但仍集中在“玩家领域对象”。
- `tile.lua` 通过 `game.store` 强约束获取状态，替换性较弱（LSP/ISP）。

### src/gameplay
- 回合驱动与选择流程高度集中在 `turn_*`、`turn_manager.lua`、`effect_pipeline.lua`、`choice_service.lua`。
- `landing.lua`/`land.lua`/`item_executor.lua` 是规则实现核心，职责混合显著（SRP/DIP/ISP）。
- `composition_root.lua` 做装配，具备一定 DI 形态，但上层仍直接依赖具体模块。

### src/adapters
- `adapters/love2d/*` 负责 UI 与运行时集成，依赖配置与 runtime；UI 与状态呈现耦合度高，但与业务逻辑分层尚可。

## SRP（单一职责）
- **高风险**
  - `src/gameplay/landing.lua`：落地效果编排 + UI 选择意图 + 随机抽卡 + 服务路由 + 日志。
  - `src/gameplay/land.lua`：土地规则、道具卡处理、支付/破产逻辑混在一个模块。
  - `src/gameplay/item_executor.lua`：AI 决策、交互选择、效果执行、消耗库存混合。
  - `src/gameplay/turn_manager.lua`：流程控制 + AI/无 UI 默认决策 + choice 解析，职责跨度大。
- **中等**
  - `src/gameplay/choice_service.lua`：choice 生命周期 + 调用具体 handler，有调度与规则混合迹象。
  - `src/game.lua`：作为门面还承担 store 写入与流程驱动，尚可但偏重。
- **较好**
  - `src/gameplay/mine_effect.lua`, `src/gameplay/item_board_utils.lua`, `src/gameplay/land_pricing.lua`, `src/gameplay/board_factory.lua`。
  - `src/core/*` 与 `src/util/*` 大多职责清晰。

## OCP（开闭原则）
- **较好扩展点**
  - `src/gameplay/landing.lua` 使用 `Effect.defs` 表驱动，并可追加来自 `land.lua` 的 effects。
  - `src/gameplay/effect.lua`/`effect_pipeline.lua` 通过“效果定义 + 执行器”提供扩展入口。
  - `src/gameplay/item_post_effects.lua` 的 `TARGET_EFFECTS`/`POST_EFFECTS` 让部分道具以配置方式扩展。
- **主要不足**
  - `src/gameplay/item_executor.lua` 中 `item_handlers`/`DEMOLISH_ITEMS` 需要硬编码映射新增道具。
  - `src/gameplay/turn_manager.lua` 使用固定 PHASE 列表，新增回合阶段需改动核心文件。
  - `src/gameplay/choice_handlers/*` 与 `choice_service.lua` 对 choice kind 的处理为显式分发，扩展需改动入口。

## LSP（里氏替换）
- 项目较少使用继承/多态；替换性主要是“结构兼容”。
- 多模块假设 `game`/`player`/`services` 具备大量方法与字段（隐式协议），替换难度高：
  - `src/gameplay/landing.lua`/`land.lua`/`item_executor.lua` 对 `player`/`game` 的方法调用密集。
  - `src/core/tile.lua` 对 `game.store` 使用 `assert`，替代实现必须完全遵循接口。
- `src/adapters/love2d/*` 对 love2d 运行时 API 直接依赖，替换 UI 框架成本高。

## ISP（接口隔离）
- 多数函数依赖“全量上下文对象”，导致调用方必须提供超集字段：
  - `src/gameplay/landing.lua` 的 effect `ctx` 同时包含 `game/player/tile/move_result`。
  - `src/gameplay/item_executor.lua` 要求 `deps.inventory/strategy`，同时强依赖 `game`/`player` 结构。
  - `src/gameplay/choice_handlers/*` 通过 `helpers` 传入大量工具函数，接口肥大。
- `src/gameplay/decision_engine.lua` 有 `deps` 注入，但仍传入 `game` 全量对象。

## DIP（依赖倒置）
- 多数高层逻辑直接 `require` 具体实现：
  - 玩法层直接依赖 `logger`/`Inventory`/`Strategy`/`ItemEffects` 等具体模块。
  - `src/gameplay/turn_manager.lua` 固定绑定具体 phase 实现。
- 少量倒置点：
  - `src/gameplay/decision_engine.lua` 的 `deps` 注入。
  - `src/gameplay/landing.lua` 与 `src/gameplay/chance.lua` 通过 `services` 获取部分能力。
  - `src/gameplay/composition_root.lua` 做装配，但上层依赖具体模块名。

## 代表性文件观察（非穷尽）
- `src/gameplay/effect_pipeline.lua`：执行链清晰，但强依赖 effect 定义结构与 logger。
- `src/gameplay/choice_service.lua`：集中式分发 choice，扩展需在中心修改。
- `src/gameplay/movement_service.lua`：移动逻辑与效果触发集中，SRP 偏多但可追踪。
- `src/adapters/love2d/presenter.lua`：基于 config 构建展示数据，职责清晰。
- `src/adapters/love2d/ui_state.lua`：UI 初始态与 palette/font 管理集中。

## 小结
- 代码库整体是“过程式 + 表驱动”的游戏规则实现，SOLID 的工程化解耦并非核心目标。
- 最主要的 SOLID 偏离集中在 gameplay 规则与回合驱动层：职责混合、扩展点集中、依赖具体实现。
- core/util/config 层相对干净；adapters 层合理地依赖平台但替换性弱。

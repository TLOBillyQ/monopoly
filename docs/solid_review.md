# SOLID 原则审查报告

审查范围聚焦于 `src/` 目录的核心规则层与 Eggy 适配层实现，结合现有文档与测试脚本输出，给出按 SOLID 原则的现状评估与改进建议。

## 总体结论

- 规则层（`src/core`、`src/gameplay`、`src/game.lua`）职责划分较清晰，流程驱动集中在 `TurnManager` 与 `ChoiceService`，可维护性较好。
- 适配层（`src/adapters`）已经拆分为 `AdapterLayer`、`Presenter`、Eggy 具体实现，但 `EggyLayer` 仍承担过多 UI/交互/动画/日志职责。
- 依赖注入与扩展点主要集中在 `ChoiceService`、`EffectPipeline` 等模块，扩展性较好，但仍存在对具体实现的直接依赖。

## 单一职责原则（SRP）

**做得好的部分**

- `src/core/board.lua`、`src/core/store.lua`、`src/core/player.lua` 等聚焦单一模型职责。
- `src/gameplay/movement_service.lua` 只负责移动与路径计算；`src/gameplay/land_actions.lua` 只负责地产相关动作。
- `src/adapters/core/presenter.lua` 只负责把状态映射为视图结构。

**需要注意的部分**

- `src/game.lua` 同时负责状态写回、胜负判定、日志输出，存在职责混杂的风险。
- `src/adapters/eggy/eggy_layer.lua` 同时承担 UI 状态维护、事件分发、自动运行、动画驱动、日志与提示，后续扩展会变得困难。
- `src/adapters/core/adapter_layer.lua` 既处理 choice/timeout 状态，又处理动画完成派发，职责偏多。

**建议**

- 明确 `Game` 只处理规则状态，胜负判定可拆到独立服务（例如 `victory_service.lua`）。
- 继续拆分 Eggy 适配层的子模块（目前已有 `eggy_layer_board`/`eggy_layer_market`），可以把“自动推进/动画”单独抽出。

## 开闭原则（OCP）

**做得好的部分**

- `ChoiceService.setup` 以注册表合并处理器，新增 choice 类型不需要修改 `resolve`。
- `ItemExecutor` 以 `item_handlers` 表扩展道具逻辑，保留后续扩展点。
- `EffectPipeline` 与 `Effect.scan/execute` 使“落点效果”可以通过配置扩展。

**需要注意的部分**

- `TurnManager` 的 phases 在 `composition_root.lua` 中硬编码，新增回合阶段需要改动核心装配逻辑。
- `MarketService`、`MovementService` 仍直接引用配置与具体服务，扩展时会牵一发而动全身。

**建议**

- 把 phases 改为配置注入（例如 `CompositionRoot.assemble(opts)` 接受 `opts.phases`），提高可扩展性。
- 关键服务（市场、移动、破产）可通过参数注入或 provider 表来复用。

## 里氏替换原则（LSP）

**现状**

- 项目大多使用 Lua table + `__index` 组合，无明显继承链。规则层对“子类替换”依赖较少。
- `Game.ui_port` 作为适配层接口，`Game` 假定其拥有 `on_tile_owner_changed` 等方法；但接口未显式定义，替换适配层时容易遗漏方法。

**建议**

- 在文档或代码中明确 `ui_port` 的最小接口（方法名、参数），保持替换时行为一致。

## 接口隔离原则（ISP）

**做得好的部分**

- 规则层调用适配层仅通过 `ui_port` 少量方法，接口较小。
- `AdapterLayer` 将部分通用接口抽离，减少平台相关耦合。

**需要注意的部分**

- `EggyLayer` 对 UI 的访问集中在一个大表结构（`ui`），随着功能增加，接口会越来越宽。
- `AdapterLayer` 对外暴露 `attach/set_game/new_game/step_*` 多项方法，平台层必须理解所有细节。

**建议**

- 在平台层内部再划分“只读展示接口”“交互事件接口”等小接口，降低模块之间的强耦合。

## 依赖倒置原则（DIP）

**做得好的部分**

- `ChoiceService.setup` 通过参数注入依赖（executor/strategy/handlers），避免内部硬编码。
- `CompositionRoot` 统一装配依赖，集中配置入口。

**需要注意的部分**

- 大多数 gameplay 模块仍直接 `require` 具体实现与配置（例如 `MarketService`、`MovementService` 对 `constants`、`inventory` 的直接依赖）。
- 适配层对 UIManager / Eggy API 直接依赖，难以替换或进行单元测试。

**建议**

- 将配置与外部 API 提升为注入参数（例如 `MovementService.move` 接受 `config`），减少对具体实现的耦合。
- 为适配层提供抽象接口或包装层，以便后续切换平台或实现 mock。

## 结语

整体来看，规则层已具备较好的模块化与可维护性，但适配层与入口装配仍有职责偏大的问题。若后续需要扩展平台或玩法，建议优先优化 `Game`、`EggyLayer` 与 `CompositionRoot` 的职责边界，并明确适配接口。

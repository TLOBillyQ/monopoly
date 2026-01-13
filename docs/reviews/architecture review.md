# 架构设计评审（Hollywood 原则 / SOLID）

> 目的：用“可执行”的方式描述当前 `src/` 的架构现状、主要风险与改造路线；评审维度是 **Hollywood 原则** 与 **SOLID**。
>
> 范围：以当前分支代码为准（`src/app.lua`、`src/gameplay/app/*`、`src/gameplay/domain/*`、`src/adapters/love2d/*`、`src/config/*`）。
>
> 约束：优先对齐 `docs/蛋仔大富翁--设计案`：本评审的 P0/P1 建议都以“结构与稳定性”为目标，不引入新玩法。

---

## 1. 结论摘要

- **回合与交互链条更清晰**：`usecases/turn_usecase.lua`/`action_usecase.lua` 包装 `turn_manager` + `Flow`（`start → roll → move → landing → post → end_turn`），Choice/Intent 将 UI 决策写入 Store 统一调度。
- **状态同步改善但依赖仍松散**：`src/app.lua` 用 `_store_set`、`set_tile_owner/level/reset`、`OverlayService` 将 Tile/overlays 与 Store 对齐，`GameState.tile_state` 只读 Store。
- **Hollywood/DIP 仍有破口**：多数 effect/道具已返回 intent，由上层 `intent_dispatcher` 触发，但 `item_monster.lua`、`item_roadblock.lua`、`app/services/market_service.lua` 仍直接 `UI.push_popup`；domain 依旧依赖 `util/services.lua` 定位服务。
- **SOLID：部分拆分完成**：道具拆为 Inventory/Strategy/Executor，回合流程抽成 usecase；`src/app.lua` 与 `src/adapters/love2d/love_layer.lua` 仍承担装配+状态同步+输入+自动化等多重职责。
- **主要风险**：UI 副作用散落在 domain/app service；服务依赖隐式且缺少契约；`game` 结构被下层感知（store/board/players/services），替换/测试成本高。

## 2. 现状速览（结构与数据流）

- **入口/装配**：`main.lua` 以 `App.new` + `LoveLayer` 启动；`src/app.lua` 创建 board/players/rng/store，注入 tile/chance/movement/item/market/status/bankruptcy/overlay 服务并校验必需服务。
- **回合编排**：`usecases/turn_usecase.lua` 驱动 `services/turn_manager.lua`，后者用 `Flow` 组织 `start → roll → move → landing → post_action → end_turn`，在需要选择时切到 `wait_choice`。
- **交互机制**：`app/choice.lua` 在 Store 记录 pending choice；`app/choice_resolver.lua` + `intent_dispatcher.lua` 处理选择/弹窗 intent；`LoveLayer` 轮询 Store 生成 modal。
- **规则落地**：`app/landing_resolver.lua` 用 `domain/effect.lua` 扫描 `domain/landing.lua`（合并 `domain/land.lua` 地产 effect）；机会卡在 `domain/chance.lua`，道具在 `domain/item_*`（Strategy/Executor/Inventory 拆分）。
- **状态与投影**：`Store`（`infra/store.lua`）为唯一权威存储；`GameState.tile_state` 读 Store；`OverlayService` 与 `App:set_*` 把 runtime 写回 Store；`adapters/love2d/presenter.lua` 将 Store 视图化。
- **端口/外设**：`ports/ui_port.lua` 仍是 Love 适配层入口，但 domain/app service 中仍直接使用 UI。

## 3. Hollywood 原则审查（Don’t call us, we’ll call you）

### 符合点
- **回合驱动清晰**：`TurnUsecase`/`TurnManager` 控制流程，Flow 统一状态跳转，effect 返回 intent 或 `waiting/resume`（`landing_resolver.lua`）。
- **意图化交互**：大部分道具/落地效果通过 intent（`need_choice`/`push_popup`）交由上层调度，AI 通过 `ai/agent.lua` 自动生成 choice action。

### 偏离点
- **domain 仍直接触发 UI**：`domain/item_monster.lua`、`domain/item_roadblock.lua`、`app/services/market_service.lua` 直接 `UI.push_popup`，未经过 intent/Choice。
- **下层主动拉取服务**：`domain/chance.lua`、`domain/land.lua` 等依赖 `util/services.lua` 直接调用 service，形成反向依赖。

### 影响
- 某些场景仍是“下层调用上层”，headless/无 UI port 时行为分叉或静默失败，削弱可替换性与可测性。

## 4. 依赖倒置（DIP）审查

### 已有的正向实践
- **服务清单校验**：`src/app.lua` 构造时校验 movement/tile/chance/item/market/status/bankruptcy/overlay 是否存在，避免明显缺失。
- **适配层隔离**：UI 通过 `ui_port.lua` 注入，Love2D 实现局限在 `adapters/love2d/*`。
- **效果/意图解耦**：Effect + intent 让 domain 逻辑与 UI 呈现之间有明确的桥接层。

### 主要问题
- **服务定位器依旧核心**：`util/services.lua` 仍是 domain 获取依赖的主要方式，缺乏接口契约与显式注入。
- **对 `game` 形状的硬依赖**：多数模块假定 `game.store/board/players/services` 存在（如 `domain/land.lua`、`app/services/movement_service.lua`），替换/测试需构造完整对象。
- **UI 端口旁路**：直接 `UI.push_popup`/`UI.is_available` 绑定端口存在性，削弱“上层驱动”。

## 5. SOLID 审查

### S（单一职责）
- `src/app.lua` 仍负责 Bootstrapping + 状态写入 + 玩家/棋盘管理 + 胜负判定。
- `src/adapters/love2d/love_layer.lua` 集 Love 生命周期、UI 布局/渲染、输入、自动运行、choice modal 于一体。
- `src/gameplay/app/services/tile_service.lua` 同时处理 tile 规则、市场弹窗/UI 与 overlay 检测，耦合 UI/领域。
- 道具部分已拆分（Inventory/Strategy/Executor/Post/Target），单一职责明显改善。

### O（开放封闭）
- Effect + landing_defs 便于扩展落地行为，机会卡/道具逻辑集中在对应文件。
- UI 选择流程仍需在 ChoiceResolver/Executor/AI 同步改动，扩展点分散。

### L（里氏替换）
- 服务依赖仍是 duck typing，`game.services.*` 缺少契约，mock/替换需复刻全部方法。

### I（接口隔离）
- UI port 很薄，但 `game` 暴露面大；domain 频繁读取 store/board/players/services，无法仅注入最小接口。

### D（依赖倒置）
- 与第 4 节一致：缺少显式接口/注入，仍依赖全局服务表。

## 6. 主要风险点

- **UI 副作用散落在下层**：`domain/item_monster.lua`、`domain/item_roadblock.lua`、`app/services/market_service.lua` 直接调 UI，破坏统一的 intent → app → UI 流，并导致 headless 模式行为不同。
- **服务依赖隐式且缺少契约**：大量逻辑通过 `util/services.lua` 直接拉服务，缺少接口约束与启动期 shape 校验，缺失方法时仅 warn/报错，替换/测试风险高。
- **巨型 orchestrator 难以替换**：`LoveLayer`/`app.lua` 集成装配、状态镜像、输入/AI/自动化，任何变更都需跨模块理解，阻碍拆分和测试。
- **Overlay/Store 旁路写入的潜在缝隙**：`game.overlays` 直接引用 Store 内部表，若有模块绕过 `OverlayService` 修改该表，会绕开 `_store_set` 的一致性控制与日志。

## 7. 改造路线图（M1：不改玩法语义）

### P0（稳定性优先）
1) **统一 UI 触发路径**  
   方案：将 `item_monster.lua`、`item_roadblock.lua`、`app/services/market_service.lua` 的弹窗改为返回 intent，由 `intent_dispatcher`/`choice` 触发；app 层兜底 UI 是否可用。  
   影响文件：`src/gameplay/domain/item_monster.lua`、`src/gameplay/domain/item_roadblock.lua`、`src/gameplay/app/services/market_service.lua`、`src/gameplay/app/intent_dispatcher.lua`。

2) **显式依赖注入/契约**  
   方案：为核心服务定义最小接口（movement/status/overlay/market），app 层校验 shape；domain 通过 ctx 显式接收 services/ports，减少 `util/services.lua`。  
   影响文件：`src/app.lua`、`src/gameplay/domain/*`、`src/util/services.lua`。

### P1（Hollywood/DIP 对齐）
3) **拆分巨型 orchestrator**  
   方案：把 `LoveLayer` 拆为 Love 绑定（生命周期/输入）+ UI 渲染 + 自动运行/回合控制 adapter，降低耦合；同时缩减 `app.lua` 的状态写入/玩家管理到专职服务。  
   影响文件：`src/adapters/love2d/love_layer.lua`、`src/app.lua`、`src/adapters/love2d/*`。

### P2（SOLID 落地与可维护性）
4) **补齐扩展点一致性**  
   方案：为新增道具/机会卡整理“定义位置 → Executor/Resolver → ChoiceResolver/AI”的脚手架/模板，减少横向散落的改动点。  
   影响文件：`docs/`（流程说明）、`src/gameplay/app/choice_resolver.lua`、`src/gameplay/domain/item_*`。

## 8. 验收建议（可操作）

- 交互统一：`UI.push_popup` 仅由 intent dispatcher/app 层调用；monster/roadblock/market 等场景通过 intent 触发。
- 依赖显式：核心 domain 通过 ctx/入参声明所需 services，最小化 `util/services.lua`；缺服务在启动期即可失败。
- 替换验证：使用 stub UI/服务跑一遍完整回合（含 market/monster/roadblock/steal 选择）仍能运行，证明 Hollywood/DIP 达成。

# 架构设计评审（Hollywood 原则 / DIP / SOLID）

> 目的：用“可执行”的方式描述当前 `src/` 的架构现状、主要风险与改造路线；评审维度是 **Hollywood 原则**、**依赖倒置（DIP）** 与 **SOLID**。
>
> 范围：以当前分支代码为准（`src/app.lua`、`src/core/*`、`src/gameplay/*`、`src/adapters/love2d/*`、`src/config/*`、`scripts/regression.lua`）。
>
> 约束：优先对齐 `docs/backlog.md` 的 **M1（不改玩法）**：本评审的 P0/P1 建议都以“结构与稳定性”为目标，不引入新玩法。

---

## 1. 结论摘要

- **主流程清晰但职责混杂**：`src/gameplay/app/services/turn_manager.lua` 与 `src/gameplay/app/turn/*` 负责编排回合，`src/gameplay/domain/effect.lua` + `src/gameplay/domain/landing.lua` 用 Effect 机制表达落地规则，但 UI/状态/服务调用散落在 domain 与 app 中。
- **Hollywood 原则“部分成立”**：回合流程是“上层驱动、下层被调用”，但 domain 仍直接触发 UI 与服务副作用（如 `src/gameplay/domain/item_post_effects.lua`、`src/gameplay/domain/item_missile.lua`、`src/gameplay/domain/land.lua`）。
- **DIP 落地不彻底**：有 `src/gameplay/ports/ui_port.lua` 与 `game.services` 的注入，但 `src/util/services.lua` 服务定位器让依赖隐式化，domain 依赖 `game:set_*` 的具体实现，接口不清晰。
- **SOLID 最大问题集中在“单一职责”**：`src/app.lua`、`src/gameplay/domain/item.lua`、`src/adapters/love2d/love_layer.lua` 承担过多职责，影响可测性与演进速度。
- **结构风险点**：Tile 运行态 vs Store 快照存在并行状态源（`src/gameplay/domain/core/tile.lua` vs `src/gameplay/infra/store.lua`），加上 overlays 直接写入，容易产生“状态不一致/难回溯”的隐性 bug。

## 2. 现状速览（结构与数据流）

- **入口**：`main.lua` 组合 `src/app.lua` 与 `src/adapters/love2d/love_layer.lua`，LoveLayer 挂接 LÖVE 生命周期并持有 game 实例。
- **回合编排**：`src/gameplay/app/services/turn_manager.lua` + `src/gameplay/app/flow.lua` 组织 `start → roll → move → landing → end_turn`。
- **规则落地**：`src/gameplay/app/landing_resolver.lua` 通过 `src/gameplay/domain/effect.lua` 扫描 `src/gameplay/domain/landing.lua`（含 land/tile/chance/item 等 effect）。
- **领域规则**：机会卡与道具分别在 `src/gameplay/domain/chance.lua`、`src/gameplay/domain/item*.lua`；地块/税务在 `src/gameplay/domain/land.lua`。
- **状态与投影**：核心状态保存在 `src/gameplay/infra/store.lua`；`src/adapters/love2d/presenter.lua` 将 store 投影为 UI 数据。
- **端口**：`src/gameplay/ports/ui_port.lua` 作为 UI 交互入口，但 domain 仍有直接调用端口的副作用逻辑。

## 3. Hollywood 原则审查（Don’t call us, we’ll call you）

### 符合点
- **回合驱动清晰**：上层 `TurnManager` 统一驱动流程，下层 effect 仅返回结果或 “waiting/resume” 意图（如 `src/gameplay/app/landing_resolver.lua`）。
- **Choice 机制提供“回调点”**：`src/gameplay/app/choice.lua` + `src/gameplay/app/choice_resolver.lua` 让 UI 行为在特定节点被动触发。

### 偏离点
- **domain 直接触发 UI**：如 `src/gameplay/domain/item_post_effects.lua`、`src/gameplay/domain/item_missile.lua`、`src/gameplay/domain/item_steal.lua` 中直接 `UI.push_popup`，下层主动“打断”流程。
- **domain 直接触发 app 服务**：`src/gameplay/domain/land.lua`、`src/gameplay/domain/chance.lua` 通过 `src/util/services.lua` 调用 Status/Bankruptcy/Market。

### 影响
- 下层逻辑知道“谁会被调用”，削弱 Hollywood 的反向控制；UI/服务不可用时只能降级告警，难以保证一致行为或可测性。

## 4. 依赖倒置（DIP）审查

### 已有的正向实践
- **UI 端口**：`src/gameplay/ports/ui_port.lua` 作为 adapter 的抽象层，Love2D 实现仅在 `src/adapters/love2d/*`。
- **服务注入**：`src/app.lua` 通过 `game.services` 注入 Movement/Chance/Market 等服务。

### 主要问题
- **服务定位器让依赖“隐式化”**：`src/util/services.lua` 使 domain 无需显式传参，但也失去可见依赖边界。
- **domain 依赖 App 具体实现**：大量逻辑依赖 `game:set_*`、`game.store` 具体结构（如 `src/gameplay/domain/land.lua`）。
- **基础设施与状态耦合**：`src/gameplay/infra/rng.lua` 通过 `_store` 回写状态，infra 与 app 绑定过紧。

## 5. SOLID 审查

### S（单一职责）
- `src/app.lua` 同时承担组装、状态写入、玩家/棋盘管理与胜负判定。
- `src/gameplay/domain/item.lua` 同时处理道具库存、选择逻辑、AI 自动使用、效果分发。
- `src/adapters/love2d/love_layer.lua` 同时负责 UI、输入、自动执行、游戏生命周期控制。

### O（开放封闭）
- Effect 机制（`src/gameplay/domain/effect.lua`）使“落地行为”扩展更平滑。
- 但道具/机会卡新增需要在多个文件中同步修改（`src/gameplay/domain/item.lua`、`src/gameplay/domain/item_post_effects.lua`、`src/gameplay/domain/item_target_effects.lua` 等）。

### L（里氏替换）
- 多数模块采用 duck typing（如 `game.services.*`），替换成本高，缺少“最小可用接口”定义。

### I（接口隔离）
- UI port 相对小，但 `game` 对象暴露面极大（含 store/board/players/services 等），domain 依赖范围过广。

### D（依赖倒置）
- 与第 4 节重复，不再展开；核心问题是“依赖边界不显式”。

## 6. 主要风险点

1) **状态源不唯一**  
   Tile 结构自带 `owner_id/level`（`src/gameplay/domain/core/tile.lua`），但实际权威状态在 Store（`src/gameplay/infra/store.lua`）。`Player:net_worth` 读 Tile 状态会返回错误值（`src/gameplay/domain/core/player.lua`）。

2) **状态写路径混乱**  
   `game.overlays` 直接引用 store 内部表（`src/app.lua`），而其他写入走 `store:set`。未来如果切换存储策略，会出现“部分状态不受控”的问题。

3) **UI 副作用散落在 domain**  
   UI 行为在多个 domain 文件中直接触发（道具/怪兽/导弹等），阻碍 headless 回归与测试替换。

4) **隐式依赖导致运行时失败**  
   通过服务定位器的依赖在缺失时只能告警，缺少明确的编译/启动期检查。

## 7. 改造路线图（M1：不改玩法语义）

### P0（稳定性优先）
1) **明确“唯一状态源”**  
   方案：将 Tile 的 owner/level 完全视为 Store 状态，统一通过 `GameState.tile_state` 读取；或在 `game:set_tile_owner/level` 同步写回 Tile。  
   影响文件：`src/app.lua`、`src/gameplay/domain/core/player.lua`、`src/gameplay/domain/core/tile.lua`、`src/util/game_state.lua`。

2) **收敛 overlays 的写入入口**  
   方案：新增 `OverlayService` 或 App 方法（如 `game:set_overlay`）统一修改 roadblock/mine，并在这里集中记录/同步。  
   影响文件：`src/gameplay/domain/item_post_effects.lua`、`src/gameplay/app/services/movement_service.lua`、`src/gameplay/app/services/tile_service.lua`。

3) **启动期服务检查**  
   方案：`App.new` 启动时校验 `game.services` 必备能力，避免运行时缺服务。  
   影响文件：`src/app.lua`。

### P1（Hollywood/DIP 对齐）
4) **统一“intent → app 处理”的交互模式**  
   方案：domain 只返回 intent（choice/popup），由 app 层统一触发 `Choice.open` 与 `UI.push_popup`。  
   影响文件：`src/gameplay/domain/item_post_effects.lua`、`src/gameplay/domain/item_missile.lua`、`src/gameplay/domain/item_steal.lua`、`src/gameplay/app/choice_resolver.lua`。

5) **显式依赖注入**  
   方案：在 ctx 中传入 `services` 或 `ports`，逐步减少 `src/util/services.lua` 的使用。  
   影响文件：`src/gameplay/domain/*`、`src/gameplay/app/landing_resolver.lua`。

### P2（SOLID 落地与可维护性）
6) **拆分 ItemEffects 的职责**  
   方案：拆成 inventory 操作、选择/策略、效果执行三层，减少 `item.lua` 的上帝模块属性。  
   影响文件：`src/gameplay/domain/item.lua`、`src/gameplay/domain/item_post_effects.lua`。

7) **抽出 Usecase 层**  
   方案：对 UI 暴露 `TurnUsecase`/`ActionUsecase`，把 `TurnManager` 和 `Flow` 收敛为内部实现。  
   影响文件：`src/gameplay/app/services/turn_manager.lua`、`src/adapters/love2d/love_layer.lua`。

## 8. 验收建议（可操作）

- State 一致性：任意改地块 owner/level 后，Store 与 runtime 读取一致（通过 `GameState.tile_state` 校验）。
- 交互统一：所有 UI 弹窗/选择都从 app 层触发，domain 不直接调用 `UI.push_popup`。
- 服务注入：移除或显著减少 `src/util/services.lua` 的使用，并能通过 stub 服务完成 `scripts/regression.lua`。

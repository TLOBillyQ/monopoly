# SecretOfEscaper / Monopoly 架构研究笔记（完成初版）

本笔记用于后续重构准备，已补齐 Monopoly 主要调用链与 SecretOfEscaper Library/Manager 对照，后续仍需补充更细粒度数据与验证点。

## 入口与初始化

### SecretOfEscaper

- `docs/SecretOfEscaper/main.lua` 延迟一帧执行 `require "init"`，随后 `MapManager.init_level(LevelData.current_level)`。
- `docs/SecretOfEscaper/init.lua` 依次加载 `Globals` 封装、`Library.Utils`/`ClassUtils`、`UIManager`（`UIManager.Builder:new(require "Data.UIManagerNodes")`）、`Bincore`、`Behavior` 与各 `Manager`，并初始化 `LevelData`。

### Monopoly

- `main.lua` → `init.lua` → `Globals.__init`、`Manager.__init`，调用 `Manager.GameManager.Entry.install()`。
- `Entry.install` 通过 `Runtime.install` 启动运行时；`Runtime.install_game_init` 在 `EVENT.GAME_INIT` 中构建 UI、加载 `Globals.ECA`、初始化全局 `G` 并绑定 `UIEventRouter`。

## 目录职责

### SecretOfEscaper

- `docs/SecretOfEscaper/Components`：基础系统（生命、背包、仓库等）。
- `docs/SecretOfEscaper/Config`：玩法与地图配置（含行为树配置与地图列表）。
- `docs/SecretOfEscaper/Data`：静态数据（UI 节点、Prefab、剧情等）。
- `docs/SecretOfEscaper/Globals`：引擎 API 的全局封装与 Canvas 入口。
- `docs/SecretOfEscaper/Library`：通用库（Utils/Class/Behavior/NavMesh/UIManager/Bincore）。
- `docs/SecretOfEscaper/Manager`：玩法与系统模块（玩家、地图、模式、实体、商店、道具）。

### Monopoly

- `Config/Generated`：由表格导出的规则常量、道具、卡牌、载具等。
- `Components`：棋盘、玩家、库存、状态树（`Store`）等核心对象。
- `Manager`：运行时、回合、移动、落地、市场、道具、效果等系统。
- `Library`：通用工具、UIManager 以及 Monopoly 特有 Logger/IntentDispatcher。

## SecretOfEscaper：典型调用链

- 地图/模式加载：`MapManager.init_level` → `Manager.MapManager.<namespace>.__init` → `Manager.ModeManager.<mode>.__init`（如 `LootEscaper` 初始化 NavMesh、怪物与 GUI）。
- 玩家与存档：`PlayerManager` 为所有 Role 构造 `Player`，`Player:load_data` 通过 `Bincore` 读取存档，`MapManager.leave_level` 触发 `save_data`。
- AI 行为：`EntityManager/AIComp` 使用 `Behavior.build_tree` 构建行为树，`SetFrameOut` 驱动 tick；怪物实例（如 `VengefulClown`）在 Mode 初始化时注入 NavMesh/Path。

## Monopoly：Choice/Item 调用链

### 触发入口

回合阶段触发道具选择：

- `Manager/TurnManager/Turn/TurnStart.lua` 调用 `ItemPhase.run(..., "pre_action", ...)`。
- `Manager/TurnManager/Turn/TurnRoll.lua` 调用 `ItemPhase.run(..., "pre_move", ...)`。
- `Manager/TurnManager/Turn/TurnPost.lua` 调用 `ItemPhase.run(..., "post_action", ...)`。

道具在其它流程触发选择：

- `Manager/ItemManager/Item/ItemSteal.lua` 的 `Steal.handle_pass_players(...)` 在经过玩家时返回 `{ waiting = true, intent = { kind = "need_choice", ... } }`。
- `Manager/ItemManager/Item/ItemDemolish.lua` 的 `Demolish.use(...)` 在非 AI 使用时返回 demolish 目标选择。

### Choice 生成与派发

`Manager/ItemManager/Item/ItemPhase.lua` 会根据背包与时机生成 `item_phase_choice`：

- `ItemPhase.build_choice_spec(...)` 过滤可用道具，生成 `choice_spec`（kind=`item_phase_choice`），并在可丢弃时追加 `discard_item` 选项。
- `ItemPhase.run(...)` 调用 `IntentDispatcher.dispatch(game, { kind = "need_choice", choice_spec = spec })`。
- `Library/Monopoly/IntentDispatcher.lua` 负责写入 `game.store`：递增 `turn.choice_seq`，设置 `turn.pending_choice`，并广播 `need_choice` 事件。

### UI 展示与输入回传

- `Manager/System/Runtime.lua` 监听 `IntentDispatcher.on("need_choice", ...)`，将 `pending_choice` 绑定到 runtime，并调用 `RuntimeUI.open_choice_modal`。
- `Manager/System/GUI/RuntimeUI.lua` 转交给 `Manager/TurnManager/GUI/MainView.open_choice_modal` 渲染。
- `Manager/TurnManager/GUI/UIEventRouter.lua` 监听 UI 按钮，点击后调用 `RuntimeLoop.dispatch_action`。
- `Manager/System/GUI/RuntimeLoop.lua` 特殊处理 `item_slot_N`：仅在 `choice.kind == "item_phase_choice"` 时，将道具槽映射为 `choice_select` 并回传到游戏。

### Choice 解析与道具执行

- `Manager/System/GUI/RuntimeLoop.lua` 将 `choice_select/choice_cancel` 交给 `game:dispatch_action`。
- `Manager/TurnManager/Turn/TurnManager.lua` 在 `wait_choice` 状态通过 `ChoiceService.resolve(...)` 处理。
- `Manager/ChoiceManager/Choice/ChoiceService.lua` 将 `choice.kind` 映射到 `ChoiceRegistry`，并调用 `ItemChoiceHandler`。

`item_phase_choice` 的处理逻辑在 `Manager/ChoiceManager/Choice/ChoiceHandlers/ItemChoiceHandler.lua`：

- 选择 `discard_item`：打开 `discard_item` 子选择，并在丢弃完成后重新打开 `item_phase_choice`。
- 选择具体道具：调用 `ChoiceService.use_item` → `ItemExecutor.use_item(...)`。

`ItemExecutor` 与 `ItemRegistry` 决定是否需要后续选择：

- `Manager/ItemManager/Item/ItemExecutor.lua`：优先查 `ItemRegistry`，否则直接消耗并走 `ItemPostEffects.apply_post`。
- `Manager/ItemManager/Item/ItemRegistry.lua` 的 `run_item_choice_flow(...)` 生成目标选择：
  - `item_target_player`（目标玩家）
  - `remote_dice_value`（遥控骰子点数）
  - `roadblock_target`（路障位置）
  - `demolish_target`（怪兽/导弹目标）

### Choice 子流程（道具目标）

以下 choice 由 `ItemChoiceHandler` 继续处理并回到道具逻辑：

- `item_target_player` → `use_item` 传入 `target_id`，触发 `ItemPostEffects` 的定向效果。
- `remote_dice_value` → `RemoteDice.apply(...)`。
- `roadblock_target` → `Roadblock.apply(...)`。
- `demolish_target` → `Demolish.apply(...)`。
- `steal_prompt` → 打开 `steal_item` 选择；`steal_item` → `Steal.steal_item_at_index(...)`。
- `discard_item` → `Inventory.remove_by_index(...)`，结束后重开道具阶段。

当子流程结束时会调用 `finish_choice` 与 `finish_item_phase` 清理：

- `ChoiceService.finish_choice` 清除 `turn.pending_choice`。
- `ItemPhase.finish` 设置 `turn.item_phase.<phase>.done = true` 并清理 `turn.item_phase_active`。

### 自动与兜底决策

- `Manager/GameManager/Agent.lua` 的 `auto_action_for_choice` 为 AI 或超时兜底生成 `choice_select/choice_cancel`。
- `Manager/System/GUI/RuntimeLoop.lua` 的 `step_choice_timeout` 会在超时后触发自动选择。


## Monopoly：Land/Market Choice 调用链

### Land：租金/税务选择

入口来自落地效果：

- `Manager/TurnManager/Turn/TurnLand.lua` 调用 `EffectPipeline.run(...)` 执行 `Config/LandingEffects.lua`。
- `Manager/LandManager/Land/Land.lua` 的 `pay_rent` 与 `tax` 执行器在满足条件时返回 `{ waiting = true, intent = { kind = "need_choice", choice_spec = ... } }`。

choice_spec 的构建：

- `Manager/LandManager/Land/LandChoiceSpecs.lua` 统一生成 `rent_card_prompt` 与 `tax_card_prompt`，选项固定为 `use/skip`。
- `pay_rent` 会优先尝试强征卡（`strong`），其次是免租卡（`free_rent`），再走正常收租。
- `tax` 在可用免税卡时生成 `tax_card_prompt`，否则直接缴税。

choice 处理与落地：

- `Manager/ChoiceManager/Choice/ChoiceHandlers/LandChoiceHandler.lua` 处理 `rent_card_prompt` 与 `tax_card_prompt`。
- `rent_card_prompt`：
  - 选择 use + strong → `LandActions.execute_strong_card(...)`。
  - 选择 use + free → `LandActions.execute_free_card(...)`。
  - 选择 skip 或不可用 → 若玩家仍有免租卡会再次派发 `free` 选择，否则执行 `LandActions.execute_pay_rent(...)`。
- `tax_card_prompt`：
  - use → `LandActions.execute_tax_free_card(...)`，否则 `LandActions.execute_pay_tax(...)`。

结算实现：

- `Manager/LandManager/Land/LandActions.lua` 负责扣款、转移资产、破产处理与事件上报，最终通过 `ChoiceService.finish_choice` 清理 `turn.pending_choice`。

### Market：黑市购买与座驾替换

入口来自两条路径：

- `Manager/TurnManager/Turn/TurnMove.lua` 在 `market_interrupt` 时调用 `MarketService.build_choice_spec(...)`，有可买项则派发 `market_buy` 选择，并在 `wait_choice` 等待。
- `Manager/LandManager/Land/Landing.lua` 的 `market` 执行器在落地时调用 `MarketService.build_choice_spec(...)`，逻辑一致。

choice_spec 与后续选择：

- `Manager/MarketManager/Market/MarketService.lua` 生成 `market_buy` 选择，选项为可购买商品。
- `MarketChoiceHandler.market_buy` 调用 `MarketService.buy(...)`：
  - 购买商品成功直接结束。
  - 若购买座驾且已有座驾，会返回 `{ intent = { kind = "need_choice", choice_spec = ... } }`，触发 `market_vehicle_replace`（是否更换座驾）。
- `market_vehicle_replace` 由 `LandChoiceSpecs.build_use_skip(...)` 生成 `use/skip` 选项，`MarketChoiceHandler.handle_vehicle_replace` 处理后调用 `MarketService.buy_with_opts(..., { skip_vehicle_prompt = true })`。

UI 回传：

- `Manager/TurnManager/GUI/UIEventRouter.lua` 使用 `MarketUI.item_buttons`、`MarketUI.confirm_button`，把选项点击映射为 `choice_select`。
- 运行时通过 `RuntimeLoop.dispatch_action` 将选择回传给 `TurnManager` → `ChoiceService.resolve`。


## Monopoly：EffectPipeline 与可选落地效果 Choice 链条

### EffectPipeline 扫描与执行

入口与执行顺序：

- `Manager/TurnManager/Turn/TurnLand.lua` 调用 `resolve_landing(...)` → `EffectPipeline.run(...)`。
- `EffectPipeline.run` 使用 `Effect.scan` 扫描 `Config/LandingEffects.lua`，并按 `mandatory` 拆分为强制与可选效果。
- `Effect.execute` 的执行器来自 `Manager/EffectManager/Effect/Effect.lua`，它将 `Landing.executors` 与 `Land.executors` 合并为统一表，构建 `ctx` 后执行。

强制效果路径：

- 每个 mandatory effect 执行后，若返回 payload，则通过 `IntentDispatcher.dispatch` 写入 `turn.pending_choice` 或推送弹窗。
- 如果执行结果包含 `{ waiting = true }`，`EffectPipeline.run` 返回等待状态，并携带 `resume_state/resume_args`，供 `TurnManager.wait_choice` 恢复流程。

### 可选效果 Choice 生成

当存在 optional effects 时：

- `EffectPipeline.build_optional_choice(...)` 生成 choice_spec：
  - `kind` 由 `TurnLand` 传入，默认 `landing_optional_effect`。
  - `options` 来自 optional effect 列表的 id/label。
  - `meta` 包含 `effect_ids`、`player_id`、`tile_id`、`move_result`。
- 该 choice 通过 `IntentDispatcher.dispatch` 进入 `turn.pending_choice`，`TurnManager` 进入 `wait_choice`。

`TurnLand` 调用时的关键参数：

- `optional_choice_kind = "landing_optional_effect"`
- `optional_allow_cancel = true`，`optional_cancel_label = "跳过"`
- `resume_state = "post_action"` 与 `resume_args = { player = player }`

### OptionalEffectHandler 的选择处理

- `ChoiceService` 的 `get_container_defs_by_choice_kind` 将 `landing_optional_effect` 映射到 `Config/LandingEffects.lua`。
- `OptionalEffectHandler.handle_optional_landing_effect` 校验 `effect_id` 是否在 `meta.effect_ids`，再调用 `Effect.execute` 执行目标效果。
- 执行结果通过 `IntentDispatcher.dispatch` 继续派发（如弹窗/后续流程）。
- 最后调用 `finish_choice` 清理 `turn.pending_choice`，`TurnManager` 回到 `resume_state`。

说明：当前 `Config/LandingEffects.lua` 中非 mandatory 的效果是 `buy_land` 与 `upgrade_land`，因此可选效果选择主要用于土地购买/升级场景。


## SecretOfEscaper：Library/Manager 架构与 Monopoly 对照

### Library 对照

基础工具：

- SecretOfEscaper：`docs/SecretOfEscaper/Library/Utils.lua`、`docs/SecretOfEscaper/Library/ClassUtils.lua`，提供 `SetFrameOut`、`Utils.choice/choice_list`、`Utils.deep_copy` 与 Class/继承工具。
- Monopoly：`Library/Utils.lua`、`Library/ClassUtils.lua` 类似，结合 `Components.Store` 与 `GameState` 用于状态快照与复制。

序列化：

- SecretOfEscaper：`docs/SecretOfEscaper/Library/Bincore.lua` 在 `Player:load_data/save_data` 中作为存档协议（`Manager/PlayerManager/Player.lua`）。
- Monopoly：保留 `Library/Bincore.lua`，但当前主链路未使用，状态由 `Components/Store` 保存内存树。

行为树：

- SecretOfEscaper：`docs/SecretOfEscaper/Library/Behavior/*` 构建行为树，`Manager/EntityManager/AIComp.lua` 以 `SetFrameOut` tick 行为树，`Monster/VengefulClown` 绑定 `Behavior.build_tree`。
- Monopoly：当前未使用行为树，AI 走 `Manager/GameManager/Agent.lua` 的规则逻辑。

导航网格：

- SecretOfEscaper：`docs/SecretOfEscaper/Library/NavMesh/*` 支持编辑/渲染/构建，`ModeManager/LootEscaper/__init.lua` 通过 `NavMesh.build(mesh_data)` 与 `Path` 供怪物行为树路径计算。
- Monopoly：当前未使用 NavMesh，移动依赖 `Components/Board` 与 `MovementManager`。

UI 管理：

- SecretOfEscaper：`docs/SecretOfEscaper/Library/UIManager/*` 提供节点构建、查询与事件监听，`init.lua` 中 `UIManager.Builder:new(...)` 初始化 UI。
- Monopoly：复用同套 UIManager，初始化在 `Manager/System/Runtime.install_game_init` 中；Choice/Market UI 由 `Manager/TurnManager/GUI` 和 `Manager/MarketManager/GUI` 驱动。

### Manager 对照

入口与装配：

- SecretOfEscaper：`docs/SecretOfEscaper/main.lua` → `docs/SecretOfEscaper/init.lua` → `MapManager.init_level(...)`，随后由 `MapManager` 加载地图与 Mode。
- Monopoly：`main.lua` → `init.lua` → `Manager.GameManager.Entry.install()`，由 `Runtime.install` 启动运行时与回合循环。

核心管理器：

- SecretOfEscaper：
  - `Manager/PlayerManager` 管理 Role 到 Player 的映射与存档。
  - `Manager/EntityManager` 管理怪物与行为树（AIComp/Monster）。
  - `Manager/MapManager` 负责关卡加载与 Mode 初始化。
  - `Manager/ModeManager` 负责玩法模式（如 LootEscaper），组合 NavMesh、MonsterManager、GUI。
  - `Manager/ItemManager` 负责道具与装备实例化。
  - `Manager/ShopManager` 负责商店与 GUI。

- Monopoly：
  - `Manager/System` 与 `Manager/GameManager` 负责运行时与游戏装配。
  - `Manager/TurnManager` 负责回合阶段与 Choice 中枢。
  - `Manager/BoardManager/MovementManager/LandManager/MarketManager/ItemManager` 负责棋盘、移动、落地、黑市与道具规则。

关键差异总结：

- SecretOfEscaper 以 “地图/模式/实体” 组织玩法，强调行为树与 NavMesh；Monopoly 以 “回合/状态树/规则服务” 组织玩法。
- SecretOfEscaper 存档走 Bincore；Monopoly 状态走 Store 内存树并通过 `GameState` 同步。
- UI 管理器一致，但 Monopoly 更多绑定在 `Runtime/TurnManager/GUI`，SecretOfEscaper 更偏玩法侧组件与地图 GUI。


### EffectPipeline 重构切入点（基于执行点扫描）

- 执行器注册中心拆分：`Manager/EffectManager/Effect/Effect.lua` 目前直接合并 `Landing.executors` 与 `Land.executors`，可抽出 `EffectRegistry` 以支持多模式复用与测试替换。
- 结果处理抽层：`EffectPipeline.run` 内部的 `IntentDispatcher.dispatch` + wait_choice 判断可以拆为独立处理器，便于复用到非落地流程。
- Optional choice 生成器独立化：`build_optional_choice` 可下沉为公共构建器，减少 `TurnLand` 依赖细节。
- 上下文构建收敛：`Effect.build_game_ctx` 在 `TurnLand` 与 `OptionalEffectHandler` 分散使用，可统一封装，减少参数差异。
- Effect 列表与执行器解耦：`Config/LandingEffects.lua` 当前只覆盖落地，若后续扩展模式，可让 effect 列表随模式注入。

## 待验证问题

- SecretOfEscaper 的 `Config.MapConfig` 与 `LevelData` 的生命周期是否存在跨地图残留状态。
- SecretOfEscaper 行为树配置的热加载或重建时机是否有额外入口。
- Monopoly 若引入 Bincore 存档是否需要与 `Components.Store` 双写或迁移流程。


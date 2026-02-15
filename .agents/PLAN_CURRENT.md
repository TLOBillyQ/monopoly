# Uncle Bob 代码重构：SOLID 合规性改进

本可执行计划是活文档。实施过程中必须持续更新"进度"、"意外与发现"、"决策日志"、"结果与复盘"。

参照 `.agents/PLANS.md` 维护。

## 目的 / 全局视角

当前大富翁游戏代码库存在多处 SOLID 原则违规，导致扩展困难、测试成本高。完成本计划后，开发者将能够：在不修改现有核心代码的前提下添加新物品类型、新选择处理器和新意图类型；单元测试可以独立 mock 各层依赖；代码变更的影响范围将被限制在单一模块内。

验证方式：运行 `.agents/tests/suites/*.lua` 测试套件，所有测试通过；新增扩展点时无需修改 `ItemExecutor.lua`、`Agent.lua`、`IntentDispatcher.lua` 等核心文件。

## 进度

- [ ] 里程碑 1：ItemExecutor 解耦，引入 ItemHandlerChain 接口
- [ ] 里程碑 2：GameState 瘦身，移除函数混入
- [ ] 里程碑 3：Agent 策略化，消除 if-else 链
- [ ] 里程碑 4：ItemHandlers 拆分，按物品类型独立
- [ ] 里程碑 5：IntentDispatcher 策略化
- [ ] 里程碑 6：TurnFlow 中间件化
- [ ] 里程碑 7：GameView 抽象层
- [ ] 里程碑 8：代码整洁度修复

## 意外与发现

（实施过程中记录）

## 决策日志

（实施过程中记录）

## 结果与复盘

（完成后总结）

## 背景与导读

本仓库是一个 Lua 编写的大富翁游戏逻辑层。核心目录结构：

    src/core/              -- 基础设施（Flow 状态机、Logger、DirtyTracker）
    src/game/core/         -- 游戏核心（Game、Player、Agent、状态管理）
    src/game/systems/      -- 游戏子系统（items、land、choices、effects、chance）
    src/game/flow/         -- 流程控制（turn 流程、intent 分发）
    src/presentation/      -- 表现层（UI 状态、渲染、交互）

关键文件说明：

- `src/game/core/runtime/Game.lua` -- 游戏主类，组装各子系统
- `src/game/core/runtime/GameState.lua` -- 状态管理上帝类，当前混杂玩家/地块/回合三类职责
- `src/game/systems/items/ItemExecutor.lua` -- 物品执行器，直接访问 registry 和 effects 的具体实现
- `src/game/systems/items/ItemHandlers.lua` -- 物品处理器集合，239 行处理 5 种物品类型
- `src/game/core/runtime/Agent.lua` -- AI 决策逻辑，包含 15+ 种选择类型的硬编码 if-else 链
- `src/game/flow/intent/IntentDispatcher.lua` -- 意图分发器，硬编码分支处理 need_choice/push_popup
- `src/game/flow/turn/TurnFlow.lua` -- 回合流程控制，状态机构建与副作用混杂
- `src/presentation/state/UIModelProjection.lua` -- 表现层直接穿透访问 game.board 内部

术语解释：

- "SRP 违规" -- 单一职责原则违规，一个模块有多个变化原因
- "DIP 违规" -- 依赖倒置原则违规，高层模块依赖低层具体实现而非抽象
- "OCP 违规" -- 开闭原则违规，扩展功能需要修改现有代码
- "函数混入" -- 通过 `for key, fn in pairs(module) do target[key] = fn end` 批量复制函数
- "穿透访问" -- 上层代码直接访问下层模块的内部结构而非通过公开接口

## 工作计划

本计划分 8 个里程碑，每个里程碑独立完成一个可验证的重构目标。每个里程碑结束后运行测试套件确保不破坏现有功能。

### 里程碑 1：ItemExecutor 解耦

当前 `ItemExecutor.lua` 直接依赖 `item_registry.handlers` 表和 `item_effects.apply_post` 函数。新增物品类型时，需要修改 ItemExecutor 的分支逻辑，这违反了开闭原则。

目标是引入 `ItemHandlerChain` 抽象。定义 `ItemHandler` 接口，包含 `can_handle(item_id)` 和 `execute(game, player, item_id, context)` 两个方法。创建 `ItemHandlerChain` 类，按优先级维护 handler 列表，依次调用直到有 handler 返回成功。将 `item_registry` 改造为 `ItemHandler` 实现，将 `item_effects` 改造为 fallback handler。ItemExecutor 只依赖 `ItemHandlerChain` 抽象。

### 里程碑 2：GameState 瘦身

当前 `GameState.lua` 通过 `pairs` 循环将 `game_state_players`、`game_state_tiles`、`game_state_turn` 的方法批量混入自身，形成上帝类。这导致任何子系统变更都可能影响 GameState，且难以独立测试。

目标是移除函数混入。修改调用方直接使用 `game_state_players`、`game_state_tiles`、`game_state_turn` 模块。保留 `GameState` 作为 facade，但只暴露聚合查询方法（如 `current_player()`），不暴露子系统具体操作（如 `set_player_cash()`）。将子系统作为独立依赖注入，而非通过 mixin 合并。

### 里程碑 3：Agent 策略化

当前 `Agent.lua` 的 `auto_action_for_choice` 函数包含 15+ 种选择类型的 if-else 链，硬编码 "buy_land"、"upgrade_land" 等业务规则。新增选择类型需要修改 Agent 核心代码。

目标是引入策略模式。定义 `ChoiceStrategy` 接口，包含 `can_handle(kind)` 和 `decide(game, choice, actor)` 方法。为每种 choice kind 创建独立策略对象（RemoteDiceStrategy、RoadblockStrategy 等）。创建 `AgentStrategyRegistry`，支持动态注册策略。Agent 遍历 registry 找到匹配策略并委托决策。

### 里程碑 4：ItemHandlers 拆分

当前 `ItemHandlers.lua` 239 行处理 5 种物品类型，依赖 7 个外部模块。不同物品的 candidate/ai_select/choice_spec 逻辑混杂。

目标是按物品类型拆分。创建 `handlers/` 子目录，每种物品一个文件（RemoteDiceHandler.lua、RoadblockHandler.lua、DemolishHandler.lua 等）。每个 handler 实现统一接口 `{ handle(game, player, context), build_choice_spec(...) }`。创建 `ItemHandlerFactory` 根据 item_id 返回对应 handler。

### 里程碑 5：IntentDispatcher 策略化

当前 `IntentDispatcher.lua` 的 `dispatch` 方法包含硬编码分支：

    if intent.kind == "need_choice" then ... end
    if intent.kind == "push_popup" then ... end

新增 intent 类型需要继续添加 if 分支。

目标是策略化。定义 `IntentHandler` 接口，包含 `can_handle(kind)` 和 `handle(game, intent, opts)` 方法。创建 `IntentRegistry`，支持注册 handler。将 `open_choice` 和 `push_popup` 拆分为独立 handler。dispatch 方法改为查找 registry 并委托。

### 里程碑 6：TurnFlow 中间件化

当前 `TurnFlow.lua` 的 `_build_flow` 函数既构建状态机，又包装每个 phase 的副作用（日志、脏标记）。`run_until_wait` 同时处理流转逻辑和等待检测。

目标是引入中间件模式。将 phase 副作用提取为 `PhaseMiddleware`（日志中间件、脏标记中间件）。创建 `StateMachineBuilder`，支持链式配置状态和中间件。wait_states 改为可配置，支持注册新的等待类型。

### 里程碑 7：GameView 抽象层

当前 `UIModelProjection.lua` 直接访问 `game.board:get_overlays()`，presentation 层穿透访问 game 层内部。

目标是引入抽象层。在 game 层定义 `GameView` 接口，暴露 presentation 需要的数据（玩家位置、地块状态、覆盖物等）。UIModelProjection 只依赖 `GameView` 接口。`GameView` 实现包装 Game 实例，限制访问范围。

### 里程碑 8：代码整洁度修复

修复延迟 require 和魔法字符串问题。将 `LandChoiceHandler.lua` 函数内的 require 移到文件顶部。在 `Config/Constants.lua` 或各模块定义 choice option id 常量（"buy_land"、"upgrade_land"、"use"、"skip" 等）。

## 具体步骤

（每个里程碑实施时详细填写）

### 里程碑 1 步骤示例

工作目录：仓库根目录

步骤 1：创建 `src/game/systems/items/ItemHandlerChain.lua`

步骤 2：修改 `src/game/systems/items/ItemExecutor.lua`，移除对 `item_registry.handlers` 的直接访问

步骤 3：修改 `src/game/systems/items/ItemRegistry.lua`，实现 ItemHandler 接口

步骤 4：运行测试

    cd .agents/tests && lua run.lua suites/item.lua

预期输出：所有 6 个测试通过

## 验证与验收

每个里程碑完成后必须验证：

1. 运行完整测试套件：

    cd .agents/tests && lua run.lua

   预期：所有测试通过，数量不少于重构前。

2. 验证扩展点可用性：
   - 里程碑 1 后：新增一个测试 handler，验证无需修改 ItemExecutor
   - 里程碑 3 后：新增一个测试策略，验证无需修改 Agent
   - 里程碑 5 后：新增一个测试 intent handler，验证无需修改 IntentDispatcher

3. 代码度量：
   - 里程碑 2 后：GameState.lua 行数降至 50 行以内
   - 里程碑 4 后：每个 handler 文件小于 80 行

## 可重复性与恢复

每个里程碑独立可交付，可随时暂停。若某里程碑引入回归：

1. 使用 git 回退到里程碑开始前的状态
2. 修复问题后重新实施

不修改任何测试逻辑（除非测试本身有 bug），确保测试作为回归防护网有效。

## 产物与备注

（实施过程中记录关键 diff 和输出）

## 接口与依赖

里程碑 1 结束后必须存在：

在 `src/game/systems/items/ItemHandlerChain.lua` 中定义：

    local ItemHandlerChain = {}

    function ItemHandlerChain:new()
      -- 返回 { handlers = {} }
    end

    function ItemHandlerChain:register(handler, priority)
      -- handler 必须实现 can_handle(item_id) 和 execute(game, player, item_id, context)
    end

    function ItemHandlerChain:execute(game, player, item_id, context)
      -- 依次尝试 handlers，返回第一个成功的结果
    end

里程碑 3 结束后必须存在：

在 `src/game/core/runtime/agent/ChoiceStrategy.lua` 中定义：

    local ChoiceStrategy = {}

    function ChoiceStrategy.can_handle(kind)
      -- 返回 boolean
    end

    function ChoiceStrategy.decide(game, choice, actor)
      -- 返回 action 或 nil
    end

里程碑 5 结束后必须存在：

在 `src/game/flow/intent/IntentRegistry.lua` 中定义：

    local IntentRegistry = {}

    function IntentRegistry:register(handler)
      -- handler 必须实现 can_handle(kind) 和 handle(game, intent, opts)
    end

    function IntentRegistry:dispatch(game, intent, opts)
      -- 查找并委托给匹配的 handler
    end

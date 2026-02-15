# Uncle Bob 代码审查报告与可执行重构计划

本可执行计划是活文档。实施过程中必须持续更新"进度"、"意外与发现"、"决策日志"、"结果与复盘"。

遵循 `.github/PLANS.md` 的规范。

## 目的 / 全局视角

本计划旨在解决大富翁游戏代码库中的结构性技术债，通过重构提升代码可维护性、可测试性，并降低新功能接入成本。重构完成后，开发者应能更容易地理解系统边界、编写单元测试、以及安全地修改游戏逻辑。

## 摘要

代码库整体结构清晰，模块划分合理，但存在若干违反 SOLID 原则的设计问题。核心风险在于：GameState 类膨胀且职责混杂、Effect 系统依赖方向倒置、以及 UI 与业务逻辑耦合。这些问题虽不阻碍当前功能运行，但会增加后续修改的认知负担和回归风险。

## 进度

- [ ] (2025-02-16) 里程碑1：提取 GameState 查询接口
- [ ] (2025-02-16) 里程碑2：重构 Effect 系统依赖方向
- [ ] (2025-02-16) 里程碑3：解耦 UI 事件与业务逻辑
- [ ] (2025-02-16) 里程碑4：合并 Land 与 Landing 模块
- [ ] (2025-02-16) 里程碑5：清理全局注册表状态

## 意外与发现

- 观察：Effect 系统使用全局 executors 表进行分发，导致模块间存在隐式依赖
  证据：`src/game/systems/effects/Effect.lua:6-13` 直接引用 landing.executors 和 land.executors

- 观察：GameState 通过元方法将方法分派到三个子模块（players/tiles/turn），但接口不统一
  证据：`src/game/core/runtime/GameState.lua:23-88` 大量重复的转发方法

- 观察：ItemRegistry 使用全局状态 defaults_registered 防止重复注册
  证据：`src/game/systems/items/ItemRegistry.lua:7-8` 这种全局标记使测试隔离困难

## 决策日志

- 决策：优先重构 GameState 查询接口，而非一次性拆分整个类
  理由：GameState 被多处依赖，激进拆分风险过高；提取接口可在不破坏现有代码的情况下改善依赖关系
  日期/作者：2025-02-16

- 决策：保留 Effect 系统的全局注册机制，但增加接口抽象层
  理由：完全重构 Effect 系统改动面过大；通过抽象层隔离依赖可满足 DIP 且风险可控
  日期/作者：2025-02-16

## 结果与复盘

（待里程碑完成后填写）

---

## 主要问题（P0-P3）

### P1：GameState 类违反单一职责原则（SRP）

**位置**：`src/game/core/runtime/GameState.lua`

**问题描述**：
GameState 同时承担三个不同变化原因的角色：
1. 玩家状态管理（Player 相关操作）
2. 地块状态管理（Tile 相关操作）
3. 回合状态管理（Turn 相关操作）

此外，它还负责对象组装（通过 CompositionRoot）和脏数据追踪。这种混杂导致类体积膨胀（200+行），修改任一功能域都可能影响其他域。

**原则依据**：SRP - "一个类应该只有一个引起变化的原因"

**影响**：
- 理解成本高：开发者需要阅读无关代码才能理解特定功能
- 测试困难：难以单独测试某一职责而不涉及其他
- 回归风险：修改玩家逻辑可能意外破坏地块逻辑

**重构步骤**：
1. 提取 GameState 查询接口（只读方法）到一个独立模块 `GameStateQueries`
2. 将 GameStatePlayers/GameStateTiles/GameStateTurn 提升为一级公民，通过组合而非继承方式使用
3. 移除 GameState 中的转发方法，调用方直接使用子模块

**验证手段**：
- 运行 `.github/tests/regression.lua`，确保所有测试通过
- 检查 GameState 行数是否降至 100 行以内

---

### P1：Effect 系统违反依赖倒置原则（DIP）

**位置**：`src/game/systems/effects/Effect.lua`

**问题描述**：
Effect 模块（高层抽象）直接依赖 Land 和 Landing 模块的具体实现（低层细节）。executors 表的构建在模块加载时完成，通过直接引用 `landing.executors` 和 `land.executors`。

**代码片段**：
    local executors = {}
    local landing_execs = assert(landing.executors, "missing Landing.executors")
    for id, exec in pairs(landing_execs) do
      executors[id] = exec
    end
    local land_execs = assert(land.executors, "missing Land.executors")
    for id, exec in pairs(land_execs) do
      executors[id] = exec
    end

**原则依据**：DIP - "高层模块不应该依赖低层模块，两者都应该依赖抽象"

**影响**：
- 循环依赖风险：Effect 依赖 Land，Land 可能通过其他路径依赖 Effect
- 测试困难：无法在不加载 Land/Landing 模块的情况下测试 Effect
- 扩展成本高：新增效果类型需要修改 Effect 模块

**重构步骤**：
1. 定义 EffectExecutor 接口（含 can_apply 和 apply 方法）
2. 创建 EffectRegistry 模块，提供 register_executor(id, executor) 方法
3. Land 和 Landing 模块在初始化时向 Registry 注册自己的 executor
4. Effect 模块从 Registry 获取 executor，而非直接引用

**验证手段**：
- 编写测试：在不加载 Land/Landing 的情况下测试 Effect 扫描和执行
- 运行回归测试确保行为不变

---

### P2：Land 与 Landing 模块职责重叠

**位置**：`src/game/systems/land/Land.lua` 与 `src/game/systems/land/Landing.lua`

**问题描述**：
两个模块都定义了 executors 表，分别处理地块相关的不同效果。Land 处理购买、升级、付租、交税；Landing 处理落地区域效果。这种分割没有清晰的领域边界，导致：
1. 开发者难以判断新效果应该放在哪个模块
2. 存在代码重复（如都依赖 LandActions、LandRules）
3. 需要 Effect 模块同时依赖两者

**原则依据**：SRP - "同一原因变化的代码应该聚合"

**影响**：
- 认知负担：需要同时理解两个模块才能修改地块逻辑
- 重复代码：两个模块都定义了类似的 can_apply/apply 模式

**重构步骤**：
1. 将 Landing.lua 的内容合并到 Land.lua
2. 统一使用 Land.executors 作为唯一入口
3. 删除 Landing.lua，更新所有引用

**验证手段**：
- 全局搜索 `require("src.game.systems.land.Landing")`，确保无残留引用
- 运行土地相关测试套件

---

### P2：全局注册表使用可变全局状态

**位置**：`src/game/systems/items/ItemRegistry.lua`、`src/game/systems/choices/ChoiceRegistry.lua`、`src/game/systems/chance/ChanceRegistry.lua`

**问题描述**：
三个注册表模块都使用类似的模式：
- 模块级变量存储 handlers 表
- 布尔标志位防止重复注册
- register_defaults 函数在应用启动时调用

这种模式导致：
1. 测试隔离困难：一个测试的注册可能影响另一个测试
2. 隐式依赖：代码行为依赖于全局状态的初始化顺序
3. 难以追踪：谁在何时注册了什么 handler 不透明

**原则依据**：DIP + 可测试性原则

**重构步骤**：
1. 将注册表改为显式实例化模式（Registry.new()）
2. 通过依赖注入将注册表实例传递给需要它的组件
3. Bootstrap 负责创建和配置注册表实例

**验证手段**：
- 编写测试验证可以创建独立的注册表实例
- 确保并行测试不会互相干扰

---

### P2：UI 与业务逻辑耦合

**位置**：`src/game/systems/land/Land.lua:76-90`

**问题描述**：
Land 模块（业务逻辑）直接访问 `ctx.game.ui_port` 并调用 UI 方法：
    local ui_port = assert(ctx.game.ui_port, "missing ui_port")
    assert(ui_port.on_tile_upgraded ~= nil, "missing ui_port.OnTileUpgraded")
    ui_port:on_tile_upgraded(tile.id, new_level)

这违反了分层架构原则，业务层不应知道表示层的存在。

**原则依据**：DIP - "高层策略不应该依赖低层细节"

**重构步骤**：
1. 定义 TileUpgradeEvent 数据结构
2. 业务逻辑只负责生成事件，不直接调用 UI
3. UI 层订阅事件并执行相应操作
4. 通过事件总线或观察者模式解耦

**验证手段**：
- 检查 Land.lua 不再引用 ui_port
- 验证升级时 UI 仍能正确更新

---

### P3：Player 类初始化逻辑过于复杂

**位置**：`src/game/core/player/Player.lua:9-49`

**问题描述**：
init 函数包含大量字段初始化和验证逻辑，且对 balances 表进行了特殊处理（提取金币到 cash 字段）。这种复杂性表明 Player 可能承载了过多职责。

**重构步骤**：
1. 提取 Player 工厂函数，将复杂初始化逻辑移出构造函数
2. 考虑将 balances 管理提取到独立模块（Wallet）

---

### P3：TurnFlow 状态机硬编码等待状态

**位置**：`src/game/flow/turn/TurnFlow.lua:9-14`

**问题描述**：
wait_states 表硬编码了四种等待状态，这种设计限制了状态机的可扩展性。新增等待状态需要修改 TurnFlow 模块。

**重构步骤**：
1. 让状态自身声明是否为等待状态（通过元数据或接口）
2. 或使用配置对象传入等待状态集合

---

## 重构方案（按优先级排序）

### 里程碑1：提取 GameState 查询接口

**目标**：将 GameState 的查询方法（只读）提取到独立模块，减少 GameState 的体积和职责。

**涉及文件**：
- `src/game/core/runtime/GameState.lua`
- `src/game/core/runtime/GameStateQueries.lua`（新建）

**具体步骤**：

1. 创建 `src/game/core/runtime/GameStateQueries.lua`：

    local game_state_queries = {}

    function game_state_queries.player_balance(game, player, currency)
      return game.balances[player.id] and game.balances[player.id][currency] or 0
    end

    function game_state_queries.current_player(game)
      return game.players[game.turn.current_player_index]
    end

    function game_state_queries.find_player_by_id(game, player_id)
      return game.player_by_id[player_id]
    end

    return game_state_queries

2. 修改 GameState，移除已提取的方法，改为引用 GameStateQueries

3. 更新调用方（如有直接调用），改为使用 GameStateQueries

**验收标准**：
- GameState.lua 行数从 204 行降至 150 行以内
- 所有回归测试通过

---

### 里程碑2：重构 Effect 系统依赖方向

**目标**：消除 Effect 模块对 Land/Landing 的直接依赖，实现依赖倒置。

**涉及文件**：
- `src/game/systems/effects/EffectRegistry.lua`（新建）
- `src/game/systems/effects/Effect.lua`
- `src/game/systems/land/Land.lua`
- `src/game/systems/land/Landing.lua`

**具体步骤**：

1. 创建 `src/game/systems/effects/EffectRegistry.lua`：

    local effect_registry = {}
    local executors = {}

    function effect_registry.register(id, executor)
      assert(executor.can_apply ~= nil, "executor missing can_apply: " .. id)
      assert(executor.apply ~= nil, "executor missing apply: " .. id)
      executors[id] = executor
    end

    function effect_registry.get_executor(id)
      return executors[id]
    end

    function effect_registry.clear()
      for k in pairs(executors) do
        executors[k] = nil
      end
    end

    return effect_registry

2. 修改 `Effect.lua`，从 Registry 获取 executor：

    -- 移除：local executors = {} 和手动填充逻辑
    -- 改为：
    local effect_registry = require("src.game.systems.effects.EffectRegistry")

    local function _can_apply(effect, ctx)
      local exec = effect_registry.get_executor(effect.id)
      if not exec then
        error("missing executor: " .. tostring(effect.id))
      end
      -- ...
    end

3. 修改 `Land.lua` 和 `Landing.lua`，在模块末尾注册 executor：

    local effect_registry = require("src.game.systems.effects.EffectRegistry")
    for id, exec in pairs(executors) do
      effect_registry.register(id, exec)
    end

**验收标准**：
- Effect.lua 不再直接 require Land 或 Landing
- 可以编写不依赖 Land/Landing 的 Effect 单元测试
- 回归测试通过

---

### 里程碑3：合并 Land 与 Landing 模块

**目标**：消除职责重叠，简化 Effect 系统依赖。

**涉及文件**：
- `src/game/systems/land/Land.lua`
- `src/game/systems/land/Landing.lua`
- `src/game/systems/effects/Effect.lua`

**具体步骤**：

1. 将 `Landing.lua` 的 executors 合并到 `Land.lua`
2. 更新 `Land.lua` 的注册逻辑，包含 Landing 的效果
3. 删除 `Landing.lua`
4. 更新所有 `require("src.game.systems.land.Landing")` 的引用

**验收标准**：
- Landing.lua 文件已删除
- 全局搜索无残留引用
- 土地相关功能正常

---

### 里程碑4：解耦 UI 与业务逻辑

**目标**：消除 Land 模块对 ui_port 的直接依赖。

**涉及文件**：
- `src/game/systems/land/Land.lua`
- `src/game/core/runtime/MonopolyEvents.lua`
- `src/app/init.lua`

**具体步骤**：

1. 在 `MonopolyEvents.lua` 中定义新事件类型：

    tile_upgraded = "TILE_UPGRADED",

2. 修改 `Land.lua`，发送事件而非直接调用 UI：

    -- 替换 ui_port:on_tile_upgraded 调用
    _emit_event(monopoly_event.gameplay.tile_upgraded, {
      tile_id = tile.id,
      level = new_level,
    })

3. 在 `init.lua` 中订阅事件并调用 UI：

    RegisterCustomEvent(monopoly_event.gameplay.tile_upgraded, function(_, _, data)
      if state.ui_port then
        state.ui_port:on_tile_upgraded(data.tile_id, data.level)
      end
    end)

**验收标准**：
- Land.lua 不再引用 ui_port
- 升级地块时 UI 正确更新

---

### 里程碑5：重构全局注册表

**目标**：将全局注册表改为实例化模式，提高可测试性。

**涉及文件**：
- `src/game/systems/items/ItemRegistry.lua`
- `src/game/systems/choices/ChoiceRegistry.lua`
- `src/game/systems/chance/ChanceRegistry.lua`
- `src/game/core/runtime/Bootstrap.lua`
- `src/game/core/runtime/CompositionRoot.lua`

**具体步骤**：

1. 修改 `ItemRegistry.lua`，支持实例化：

    local function new_registry()
      local registry = {}
      local handlers = {}
      registry.handlers = handlers

      function registry.register(item_id, handler)
        handlers[item_id] = handler
      end

      return registry
    end

    return { new = new_registry }

2. 修改 `Bootstrap.lua`，创建注册表实例：

    function bootstrap.create_registries()
      return {
        items = require("src.game.systems.items.ItemRegistry").new(),
        choices = require("src.game.systems.choices.ChoiceRegistry").new(),
        chances = require("src.game.systems.chance.ChanceRegistry").new(),
      }
    end

3. 修改 `CompositionRoot.lua`，通过依赖注入传递注册表

**验收标准**：
- 可以创建独立的注册表实例
- 测试可以隔离运行，互不干扰

---

## 验证与验收

### 测试命令

运行完整回归测试：

    lua .github/tests/regression.lua

预期结果：所有测试通过，无错误输出。

### 关键测试用例

1. **GameState 查询**：验证 player_balance、current_player 等方法正常工作
2. **Effect 执行**：验证购买、升级、付租等效果正常触发
3. **UI 更新**：验证地块升级后 UI 正确显示
4. **游戏流程**：验证完整回合流程无异常

---

## 风险/权衡

### 风险1：重构引入回归缺陷
- **缓解**：每个里程碑都有独立的验证步骤，小步快跑
- **权衡**：重构期间代码会有临时不一致状态，需要快速完成

### 风险2：Effect 系统重构影响性能
- **缓解**：Registry 使用本地表查找，与原始实现性能相当
- **权衡**：略微增加函数调用开销，可忽略

### 风险3：UI 解耦增加复杂度
- **缓解**：事件系统已存在（MonopolyEvents），复用现有机制
- **权衡**：需要理解事件机制，增加了一层间接

### 可接受的折中
- 不一次性拆分 GameState，只提取查询接口：改动风险可控，收益明显
- 保留全局注册表的静态访问方式作为兼容层：降低迁移成本

---

## 背景与导读

### 项目结构

本仓库是一个基于蛋仔编辑器（Eggy）的大富翁游戏 Lua 实现。

关键目录：
- `src/game/core/runtime/`：游戏核心运行时（Game、GameState、Player）
- `src/game/systems/`：游戏子系统（地块、道具、机会、移动等）
- `src/game/flow/`：回合流程控制（TurnFlow、各个阶段）
- `src/presentation/`：UI 和表现层
- `.github/tests/`：测试套件

### 关键文件关系

    main.lua
      └── src/app/init.lua          -- 应用初始化，组装依赖
            └── Game.lua              -- 游戏外观类
                  └── GameState.lua   -- 状态管理（问题集中地）
                        └── GameStatePlayers/Tiles/Turn.lua
                  └── TurnFlow.lua    -- 回合流程控制
                        └── PhaseRegistry.lua
                  └── CompositionRoot.lua -- 依赖组装

    Effect.lua                      -- 效果执行系统
      └── 依赖 Land.lua, Landing.lua -- 需要解耦

### 术语解释

- **Effect**：游戏中的效果，如购买地块、支付租金、触发机会卡等
- **Executor**：效果的执行器，包含 can_apply（能否执行）和 apply（执行）两个方法
- **Phase**：回合的一个阶段，如 start、roll、move、landing、end_turn
- **Choice**：需要玩家做出选择的情况，如选择道具使用目标
- **Registry**：处理器注册表，用于根据 ID 查找对应的处理器
- **ui_port**：UI 层的接口对象，业务逻辑通过它与 UI 通信（当前直接耦合）

---

## 工作计划（按优先级）

1. **里程碑1**：提取 GameState 查询接口
   - 新建 GameStateQueries.lua
   - 迁移查询方法
   - 更新调用方

2. **里程碑2**：重构 Effect 系统
   - 新建 EffectRegistry.lua
   - 修改 Effect.lua 使用 Registry
   - 修改 Land/Landing 注册 executor

3. **里程碑3**：合并 Land/Landing
   - 合并 executors
   - 删除 Landing.lua
   - 更新引用

4. **里程碑4**：UI 解耦
   - 添加事件类型
   - 修改 Land 发送事件
   - 修改 init.lua 订阅事件

5. **里程碑5**：注册表实例化
   - 修改三个 Registry 支持 new()
   - 修改 Bootstrap 创建实例
   - 修改 CompositionRoot 注入依赖

---

## 具体步骤（里程碑1示例）

**工作目录**：`/Users/billyq/Dev/Github/Lua/monopoly`

**步骤1**：创建 GameStateQueries.lua

    mkdir -p src/game/core/runtime/
    cat > src/game/core/runtime/GameStateQueries.lua << 'EOF'
    local game_state_queries = {}

    function game_state_queries.player_balance(game, player, currency)
      -- 实现
    end

    return game_state_queries
    EOF

**步骤2**：迁移方法

从 GameState.lua 复制查询方法到 GameStateQueries.lua，确保行为一致。

**步骤3**：验证

    lua .github/tests/regression.lua

预期输出：
    [PASS] GameState queries work correctly
    All tests passed: X/Y

---

## 可重复性与恢复

每个里程碑都是独立的，可以：
- 单独执行和验证
- 回滚（通过 git checkout）
- 在完成后安全地删除临时文件

如果某一步骤失败：
1. 记录错误信息到"意外与发现"
2. 回滚到上一个稳定状态
3. 调整方案后重试

---

## 产物与备注

本计划生成以下产物：
- REFACTOR_PLAN.md（本文件）
- 里程碑完成后更新的代码文件
- 可能的临时测试文件（用于验证中间状态）

---

## 接口与依赖

### 新增接口

**GameStateQueries**（里程碑1）：

    -- src/game/core/runtime/GameStateQueries.lua
    function player_balance(game, player, currency) -> number
    function current_player(game) -> Player
    function find_player_by_id(game, player_id) -> Player|nil
    function alive_players(game) -> table

**EffectRegistry**（里程碑2）：

    -- src/game/systems/effects/EffectRegistry.lua
    function register(id, executor)
    function get_executor(id) -> executor|nil
    function clear()

### 修改的接口

**Effect.lua**：
- 移除：直接引用 land.executors 和 landing.executors
- 新增：依赖 EffectRegistry

**Land.lua**：
- 新增：模块加载时向 EffectRegistry 注册 executors

---

*计划创建时间：2025-02-16*
*遵循 .github/PLANS.md 规范*

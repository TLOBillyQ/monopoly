# 启动序列


## 目的

描述从 `main.lua` 到首帧 tick 的完整启动流程，帮助开发者理解模块何时被创建与连接。


## 五阶段启动时序图

```mermaid
sequenceDiagram
    participant Main as main.lua
    participant Init as src/app/init.lua
    participant RI as RuntimeInstall
    participant GS as GameStartup
    participant EB as GameStartupEventBridge
    participant UB as UIBootstrap
    participant GRB as GameRuntimeBootstrap

    Main->>Init: require("src.app.init")

    rect rgb(230,245,255)
    Note over Init: 阶段 1 — 运行时安装
    Init->>RI: install()
    RI->>RI: 创建 RuntimeContext（策略 + 环境）
    RI->>RI: 注册 RuntimePorts（RNG / 调度 / 角色 / 时钟）
    RI->>RI: require 核心模块（Bankruptcy, Agent, GameVictory, CompositionRoot）
    end

    rect rgb(230,255,230)
    Note over Init: 阶段 2 — 构建应用状态
    Init->>GS: build_state(get_current_game)
    GS->>GS: 创建 ui_state（UIViewService）
    GS->>GS: 注册 game_factory
    GS->>GS: 创建 auto_runner
    end

    rect rgb(255,245,230)
    Note over Init: 阶段 3 — 事件桥接
    Init->>EB: install(state)
    EB->>EB: 监听 tile_upgraded → 刷新棋盘
    EB->>EB: 监听 need_choice → 打开选择模态
    end

    rect rgb(245,230,255)
    Note over Init: 阶段 4 — UI 启动
    Init->>UB: install(state, start_runtime)
    UB->>UB: 注册 GAME_INIT 触发事件
    Note over UB: 事件触发后：
    UB->>UB: 构建 UIManager
    UB->>UB: 初始化棋盘场景 & 玩家颜色
    UB->>UB: 显示 Loading → 1s 后切换到 Base
    UB->>GRB: start_runtime 回调
    end

    rect rgb(255,230,230)
    Note over Init: 阶段 5 — 游戏运行时启动
    GRB->>GRB: GameplayLoop.new_game(state)
    GRB->>GRB: 配置回合动作端口
    GRB->>GRB: 启动 30 FPS tick 循环
    end
```


## 对象生命周期

```mermaid
graph TD
    subgraph "阶段 1: RuntimeInstall"
        RC[RuntimeContext] --> RP[RuntimePorts]
    end

    subgraph "阶段 2: GameStartup"
        state[state 对象]
        state --> ui_state[ui_state]
        state --> game_factory[game_factory]
        state --> auto_runner[auto_runner]
    end

    subgraph "阶段 4-5: UIBootstrap + GameRuntimeBootstrap"
        UIM[UIManager] --> Canvases[Canvas 节点树]
        game_factory --> Game[Game 实例]
        Game --> Board[Board]
        Game --> Players[Players]
        Game --> TurnEngine[TurnEngine]
        TurnEngine --> Scheduler[Scheduler]
    end

    state --> Game
    RC --> Game
    RP --> Game
```


## 关键设计决策

**单元素数组引用传递**：`current_game_ref[1]` 模式允许 GameStartup 在创建 state 时尚未拥有 Game 实例，而在 GameRuntimeBootstrap 阶段回填引用。

**事件驱动延迟初始化**：UIBootstrap 注册 `GAME_INIT` 事件，UI 节点树就绪后才触发 GameRuntimeBootstrap，确保渲染管线在游戏逻辑之前完成初始化。

# 模块依赖关系


## 目的

描述各层与核心模块之间的依赖关系、依赖规则（dep_rules）以及端口适配器模式如何实现解耦。


## 层间依赖规则

```mermaid
graph TD
    P["展示层<br/>src/presentation/"] -->|允许| A["应用层<br/>src/app/"]
    A -->|允许| G["游戏逻辑层<br/>src/game/"]
    G -->|允许| C["基础设施层<br/>src/core/"]
    G -->|允许| Cfg["配置层<br/>Config/"]
    C -->|允许| Cfg

    P -.->|禁止| G
    P -.->|禁止| C
    A -.->|禁止| P
    C -.->|禁止| G
    C -.->|禁止| A

    style P fill:#e1f5fe
    style A fill:#e8f5e9
    style G fill:#fff3e0
    style C fill:#fce4ec
    style Cfg fill:#f3e5f5
```

**注意**：展示层不直接 require 游戏系统模块，而是通过端口接口（PresentationPorts）间接访问游戏状态。


## dep_rules 强制规则

`tests/internal/dep_rules.lua` 扫描源码中的 require 语句，强制执行以下约束：

```mermaid
graph LR
    subgraph "被保护边界"
        R1["interaction/ ✗→ src.game.*"]
        R2["systems/ ✗→ ui_port.wait_action_anim"]
        R3["presentation/ ✗→ src.game.systems.*"]
        R4["core/runtime/ ✗→ src.game.flow.*"]
        R5["core/runtime/ ✗→ GameAPI / GlobalAPI"]
    end
```

| 规则 | 含义 |
|------|------|
| interaction ✗→ game | 交互层不能直接依赖游戏逻辑，只能通过 intent 分发 |
| systems ✗→ ui_port | 游戏系统不能直接调用 UI 等待，保持纯逻辑 |
| presentation ✗→ game.systems | 展示层不能直接引用游戏子系统 |
| core/runtime ✗→ game.flow | 基础设施不能依赖上层流程 |
| core/runtime ✗→ GameAPI | 核心运行时不能依赖平台全局 API |


## 端口适配器模式

```mermaid
graph TB
    subgraph "游戏逻辑层（内环）"
        GameCore["Game · TurnEngine · Systems"]
        GP["GamePorts（定义）<br/>rng · schedule · mark_role_lose"]
    end

    subgraph "应用层（适配器）"
        RI["RuntimeInstall"]
        RI -->|注入实现| GP
    end

    subgraph "展示层"
        PP["PresentationPorts（定义）<br/>modal · anim · ui_sync · debug"]
        UIB["UIBootstrap"]
        UIB -->|注入实现| PP
    end

    subgraph "外部平台"
        GameAPI["GameAPI<br/>Eggy 引擎"]
        LuaAPI["LuaAPI<br/>Lua 运行时"]
    end

    RI --> GameAPI
    RI --> LuaAPI
    UIB --> GameAPI

    GameCore --> GP
    GameCore -.->|不直接依赖| GameAPI
```


## RuntimePorts 详细接口

```mermaid
classDiagram
    class RuntimePorts {
        +rng_next_int(min, max) : number
        +schedule(delay, fn) : void
        +resolve_role(player_id) : Role
        +resolve_roles() : Role[]
        +mark_role_lose(role) : void
        +resolve_vehicle_helper() : VehicleHelper
        +resolve_camera_helper() : CameraHelper
        +emit_event(name, payload) : void
        +wall_now_seconds() : number
        +wall_diff_seconds(t0) : number
        +cpu_now_seconds() : number
        +cpu_diff_seconds(t0) : number
    }

    class PresentationPorts {
        +modal.show_choice(data)
        +modal.close_choice()
        +anim.play_action(type, opts)
        +anim.play_move(role, path)
        +ui_sync.refresh_panel(model)
        +ui_sync.refresh_items(model)
        +debug.log(msg)
        +clock.now() : number
        +state.get_ui() : UIState
    }

    RuntimePorts <.. RuntimeInstall : 注入
    PresentationPorts <.. UIBootstrap : 注入
```


## 核心模块依赖图

```mermaid
graph TD
    main["main.lua"] --> init["app/init"]

    init --> RI["RuntimeInstall"]
    init --> GS["GameStartup"]
    init --> EB["EventBridge"]
    init --> UB["UIBootstrap"]
    init --> GRB["RuntimeBootstrap"]

    RI --> RC["RuntimeContext"]
    RI --> RP["RuntimePorts"]

    GS --> UIVS["UIViewService"]
    GS --> GF["GameFactory"]

    GRB --> GL["GameplayLoop"]
    GL --> GLTF["GameplayLoopTickFlow"]
    GL --> TE["TurnEngine"]

    TE --> Sched["Scheduler"]
    TE --> Sess["Session"]
    TE --> TS["TurnScript"]
    TE --> PR["PhaseRegistry"]

    PR --> TStart["TurnStart"]
    PR --> TRoll["TurnRoll"]
    PR --> TMove["TurnMove"]
    PR --> TLand["TurnLand"]

    TRoll --> Movement["Movement"]
    TRoll --> ItemPhase["ItemPhase"]
    TMove --> Movement
    TLand --> LandActions["LandActions"]
    TLand --> ChanceResolver["ChanceResolver"]
    TLand --> MarketService["MarketService"]
    TLand --> EffectPipeline["EffectPipeline"]

    UB --> CReg["CanvasRegistry"]
    CReg --> CER["CanvasEventRouter"]
    CER --> UID["UIIntentDispatcher"]

    GLTF --> DirtyTracker["DirtyTracker"]
    GLTF --> UIModel["UIModel"]
    UIModel --> BoardSlice["BoardSlice"]
    UIModel --> PanelSlice["PanelSlice"]
    UIModel --> ItemSlice["ItemSlice"]
    UIModel --> ChoiceSlice["ChoiceSlice"]
```


## 测试如何守护依赖

回归测试（`lua tests/regression.lua`）在所有功能测试通过后，额外运行：

1. **dep_rules** — 扫描 `src/` 下所有 `.lua` 文件的 require 语句，检查是否违反层间依赖规则
2. **forbidden_globals** — 扫描 `src/` 下所有 `.lua` 文件，确保不使用运行时沙箱中不存在的全局函数（如 `tonumber`）

任何违反会导致回归测试失败，防止架构退化。

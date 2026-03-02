# 全局架构总览


## 目的

本文档描述 Monopoly 项目的整体分层架构与核心组件关系，为后续各专题文档提供导航索引。


## 分层架构

项目采用 **分层 + 端口适配器** 的混合架构。自底向上共五层，每一层只允许依赖同层或更下层的模块。

```mermaid
graph TB
    subgraph Presentation ["展示层 Presentation (src/presentation/)"]
        Canvas["Canvas UI<br/>10+ 独立画布"]
        CanvasRuntime["Canvas Runtime<br/>画布编排"]
        Interaction["Interaction<br/>输入分发"]
        Render["Render<br/>动画与渲染"]
        UIState["State<br/>UI 状态切片"]
    end

    subgraph App ["应用层 App (src/app/)"]
        Bootstrap["Bootstrap<br/>五阶段启动"]
    end

    subgraph GameLogic ["游戏逻辑层 Game (src/game/)"]
        GameCore["Core / Runtime<br/>Game·CompositionRoot·TurnEngine"]
        Flow["Flow / Turn<br/>GameplayLoop·回合管线"]
        Systems["Systems<br/>land·chance·items·market·effects·movement"]
    end

    subgraph Core ["基础设施层 Core (src/core/)"]
        RuntimeCtx["RuntimeContext"]
        RuntimePorts["RuntimePorts<br/>端口注入"]
        Events["MonopolyEvents<br/>事件常量"]
        Logger["Logger"]
        RuntimeState["RuntimeState<br/>域级状态"]
    end

    subgraph Config ["配置层 Config/"]
        Generated["Generated/<br/>Tiles·Roles·Items·Vehicles·ChanceCards·Market·Constants"]
        Rules["GameplayRules<br/>LandingEffects<br/>RuntimeConstants"]
        Maps["Maps/<br/>DefaultMap"]
    end

    Presentation --> App
    App --> GameLogic
    GameLogic --> Core
    GameLogic --> Config
    Core --> Config
```


## 组件关系图

```mermaid
graph LR
    main["main.lua"] --> init["src/app/init.lua"]
    init --> RI["RuntimeInstall"]
    init --> GS["GameStartup"]
    init --> EB["GameStartupEventBridge"]
    init --> UB["UIBootstrap"]
    init --> GRB["GameRuntimeBootstrap"]

    GRB --> GL["GameplayLoop"]
    GL --> TE["TurnEngine"]
    TE --> Sched["Scheduler"]
    TE --> Sess["Session"]
    TE --> TS["TurnScript"]

    TS --> PR["PhaseRegistry"]
    PR --> phases["start·roll·move·landing·post_action·end_turn"]

    phases --> Sys["Systems"]
    Sys --> Land["LandSystem"]
    Sys --> Chance["ChanceSystem"]
    Sys --> Items["ItemSystem"]
    Sys --> Market["MarketService"]
    Sys --> Effects["EffectPipeline"]
    Sys --> Movement["Movement"]

    UB --> CR["CanvasRegistry"]
    CR --> CER["CanvasEventRouter"]
    CER --> UID["UIIntentDispatcher"]
    UID --> GL
```


## 目录索引

| 文档 | 主题 |
|------|------|
| [bootstrap.md](bootstrap.md) | 启动序列时序图 |
| [turn-engine.md](turn-engine.md) | 回合引擎状态机与协程流程 |
| [game-systems.md](game-systems.md) | 游戏子系统组件图 |
| [presentation.md](presentation.md) | 展示层 Canvas 架构与交互流 |
| [data-flow.md](data-flow.md) | 端到端数据流图 |
| [dependencies.md](dependencies.md) | 模块依赖关系图 |
| [config-data.md](config-data.md) | 配置与数据模型图 |

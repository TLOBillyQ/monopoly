# 数据流


## 目的

描述从用户输入到游戏状态变更、再到 UI 渲染的端到端数据流。帮助开发者理解一个操作如何穿越所有层。


## 端到端数据流总览

```mermaid
flowchart LR
    subgraph Input ["输入"]
        Click["用户点击"]
        Frame["帧 tick"]
        AI["AI 自动操作"]
    end

    subgraph Dispatch ["分发"]
        CER["CanvasEventRouter"]
        UID["UIIntentDispatcher"]
        TD["TurnDispatch"]
    end

    subgraph Engine ["引擎"]
        GL["GameplayLoop"]
        TE["TurnEngine"]
        Sched["Scheduler"]
        TS["TurnScript"]
    end

    subgraph Systems ["系统"]
        Phase["PhaseHandler"]
        Sys["Land/Chance/Item/Market/Effect"]
    end

    subgraph State ["状态"]
        GS["Game State"]
        Dirty["DirtyTracker"]
    end

    subgraph Render ["渲染"]
        UIM["UIModel"]
        Pres["Presenter"]
        Screen["屏幕输出"]
    end

    Click --> CER --> UID --> TD --> GL
    Frame --> GL
    AI --> TD

    GL --> TE --> Sched --> TS
    TS --> Phase --> Sys --> GS
    GS --> Dirty --> UIM --> Pres --> Screen
```


## 用户操作：完整流转示例

以"玩家点击购买地产"为例：

```mermaid
sequenceDiagram
    participant User as 用户
    participant CER as CanvasEventRouter
    participant UID as UIIntentDispatcher
    participant GL as GameplayLoop
    participant Sched as Scheduler
    participant TS as TurnScript
    participant Land as LandActions
    participant GS as Game State
    participant Dirty as DirtyTracker
    participant UIM as UIModel
    participant UI as Presenter

    User->>CER: 点击"购买"按钮
    CER->>UID: intent = { type: "choice_select", option: "buy_land" }
    UID->>GL: dispatch_game_action(action)
    GL->>Sched: dispatch(session, action_signal)
    Sched->>TS: coroutine.resume(action)
    TS->>Land: buy_land(game, player, tile)
    Land->>GS: 设置格子所有者 / 扣除金钱
    GS->>Dirty: mark_dirty("players", "tiles")
    TS-->>Sched: yield() 或 继续下一阶段

    Note over GL: 下一帧 tick
    GL->>Dirty: consume_dirty()
    GL->>UIM: update(prev, game, dirty)
    UIM->>UI: render(state, ui_model)
    UI->>User: 格子变色 / 金钱刷新
```


## 帧 tick 数据流

每帧（30 FPS）GameplayLoop 执行以下流程：

```mermaid
flowchart TD
    Tick["GameplayLoop.tick(dt)"] --> SyncInput["同步输入锁定<br/>（按阶段阻止/放行）"]
    SyncInput --> AutoRunner["AutoRunner<br/>（AI 玩家自动决策）"]
    AutoRunner --> Timeout["处理超时<br/>（掉线/AI 接管）"]
    Timeout --> StepEngine["Scheduler.step()<br/>（推进协程）"]
    StepEngine --> CheckDirty["检查 DirtyTracker"]

    CheckDirty -->|有脏域| Refresh["UIModel.update() → Presenter.render()"]
    CheckDirty -->|无脏域| Skip["跳过渲染"]

    Refresh --> TouchSync["同步触控策略<br/>（按阶段启用/禁用按钮）"]
```


## 事件流

游戏内部通过 MonopolyEvents 发送领域事件，事件桥接器转发到 UI 层：

```mermaid
flowchart LR
    subgraph "游戏逻辑层"
        Action["游戏动作"] --> Bridge["RuntimeEventBridge.emit()"]
    end

    Bridge --> ME["MonopolyEvents"]

    subgraph "事件类型"
        ME --> mov["movement.*<br/>moved · passed_start · roadblock_hit"]
        ME --> land["land.*<br/>rent_paid · tile_upgraded · tax_paid"]
        ME --> mkt["market.*<br/>bought_item · bought_vehicle"]
        ME --> ch["chance.*<br/>applied"]
        ME --> gm["game.*<br/>finished"]
        ME --> intent["intent.*<br/>need_choice · push_popup"]
    end

    subgraph "展示层响应"
        mov --> MoveAnim["MoveAnim<br/>播放移动动画"]
        land --> BoardRT["BoardRuntime<br/>刷新格子"]
        mkt --> MarketP["MarketPresenter<br/>刷新市场屏"]
        intent --> Modal["打开选择模态"]
        gm --> Victory["显示胜利画面"]
    end
```


## 状态同步策略

```mermaid
graph LR
    subgraph "增量更新"
        Full["UIModel.build()<br/>首次全量构建"]
        Inc["UIModel.update(prev, game, dirty)<br/>按脏域增量更新"]
    end

    subgraph "脏域标记"
        DP["dirty.players"]
        DT["dirty.tiles"]
        DTurn["dirty.turn"]
        DChoice["dirty.choice"]
    end

    DP --> PanelSlice["PanelSlice 刷新"]
    DP --> ItemSlice["ItemSlice 刷新"]
    DT --> BoardSlice["BoardSlice 刷新"]
    DTurn --> BoardSlice
    DChoice --> ChoiceSlice["ChoiceSlice 刷新"]

    Full -->|游戏开始| Inc
    Inc -->|每帧| Inc
```

增量更新是性能关键：每帧只重算被标记为脏的切片，避免全量重建 UI 模型。

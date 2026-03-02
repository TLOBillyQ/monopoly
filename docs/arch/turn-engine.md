# 回合引擎


## 目的

描述回合引擎的状态机、协程调度模型以及阶段流转逻辑。回合引擎是游戏的核心运行时——每个玩家的回合由 Lua 协程驱动，在需要等待（玩家输入、动画播放）时挂起，收到信号后恢复。


## 协程调度模型

```mermaid
graph TD
    GL["GameplayLoop.tick()"] -->|每帧| Sched["Scheduler.step(session, dt)"]
    Sched -->|确保协程存在| TS["TurnScript（协程）"]
    Sched -->|处理队列信号| Queue["信号队列"]
    Queue -->|action / tick| Sched
    Sched -->|coroutine.resume| TS

    TS -->|coroutine.yield| WS["等待状态<br/>wait_choice / wait_move_anim / wait_action_anim / detained"]
    WS -->|用户操作或动画完成| Queue

    subgraph "外部输入"
        UserAction["用户点击"] -->|dispatch_action| AR["ActionRouter"]
        AR -->|from_action| Queue
        Frame["帧 tick"] -->|ActionRouter.tick| Queue
    end
```


## 回合阶段状态机

PhaseRegistry 定义了六个主阶段，TurnScript 按顺序执行它们。每个阶段可以转入等待状态，也可以直接转入下一阶段。

```mermaid
stateDiagram-v2
    [*] --> start
    start --> roll : 初始化回合 / 检查拘留
    start --> detained_wait : 玩家被拘留

    roll --> move : 掷骰 + 道具前置阶段
    roll --> wait_choice : 需要选择道具

    move --> landing : 移动完成
    move --> wait_move_anim : 播放移动动画

    landing --> post_action : 结算着陆效果
    landing --> wait_choice : 需要选择（购地/升级/市场）
    landing --> wait_action_anim : 播放动作动画

    post_action --> end_turn : 道具后置阶段完成
    post_action --> wait_choice : 需要选择道具

    end_turn --> [*] : 切换到下一位玩家

    detained_wait --> end_turn : 拘留回合结束
    wait_choice --> roll : 回到掷骰（道具选择后）
    wait_choice --> landing : 回到着陆（购地选择后）
    wait_choice --> post_action : 回到后置（道具选择后）
    wait_move_anim --> landing : 动画播放完毕
    wait_action_anim --> landing : 动画播放完毕
    wait_action_anim --> post_action : 动画播放完毕
```


## 协程与 Session 交互

```mermaid
sequenceDiagram
    participant GL as GameplayLoop
    participant Sched as Scheduler
    participant Sess as Session
    participant TS as TurnScript（协程）
    participant Phase as PhaseHandler

    GL->>Sched: step(session, dt)
    Sched->>TS: coroutine.resume(signal)
    TS->>Sess: mark_phase("start")
    TS->>Phase: TurnStart.execute(game, player)
    Phase-->>TS: next_state="roll", args={...}
    TS->>Sess: mark_phase("roll")
    TS->>Phase: TurnRoll.execute(game, player)
    Phase-->>TS: next_state="wait_choice", args={...}
    TS->>Sess: set_wait("wait_choice")
    TS-->>Sched: coroutine.yield()

    Note over GL: 等待用户输入...

    GL->>Sched: dispatch(session, action_signal)
    Sched->>Sess: take_pending_action()
    Sched->>TS: coroutine.resume(action)
    TS->>Phase: 继续处理选择结果
    Phase-->>TS: next_state="move"
```


## TurnEngine 内部结构

```mermaid
classDiagram
    class TurnEngine {
        -game
        -phases : PhaseRegistry
        -session : Session
        +run_turn()
        +dispatch(action)
    }

    class Scheduler {
        -queue : Signal[]
        +step(session, dt) : WaitState
        +dispatch(session, signal)
    }

    class Session {
        +current_state : string
        +current_args : table
        +pending_action : Action?
        +wait_state : string?
        +mark_phase(name)
        +set_pending_action(a)
        +take_pending_action() : Action?
    }

    class TurnScript {
        +create(session, phases) : coroutine
    }

    class ActionRouter {
        +from_action(action) : Signal
        +tick(dt) : Signal
    }

    class PhaseRegistry {
        +start : TurnStart
        +roll : TurnRoll
        +move : TurnMove
        +landing : TurnLand
        +post_action : fn
        +end_turn : fn
    }

    TurnEngine --> Scheduler
    TurnEngine --> Session
    TurnEngine --> PhaseRegistry
    Scheduler --> TurnScript
    Scheduler --> ActionRouter
    TurnScript --> Session
    TurnScript --> PhaseRegistry
```


## 关键设计特征

**协程即状态机**：传统状态机需要手动维护状态变量与转移表；此处用 Lua 协程的 yield/resume 天然表达等待与恢复，代码以线性流程书写，读起来像同步代码。

**信号队列解耦**：用户操作与帧 tick 统一进入 Scheduler 队列，TurnScript 无需区分信号来源。

**阶段可插拔**：PhaseRegistry 返回的是普通函数表，新增阶段只需实现 `execute(game, player)` 并注册即可。

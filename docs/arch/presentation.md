# 展示层架构


## 目的

描述 `src/presentation/` 的 Canvas-First 架构、交互分发流程与渲染管线。展示层负责将游戏状态映射到 UI 节点树，并将用户输入转化为游戏动作。


## Canvas-First 架构

每个 UI 屏幕（Canvas）是自包含的模块，包含节点定义、数据契约、交互意图、呈现逻辑和触控策略。画布之间不直接引用，所有跨画布编排通过 `canvas_runtime/` 完成。

```mermaid
graph TB
    subgraph "canvas_runtime/ （编排层）"
        CReg["CanvasRegistry<br/>注册所有画布"]
        CState["CanvasState<br/>画布状态存储"]
        CER["CanvasEventRouter<br/>事件路由"]
        CStore["CanvasStore<br/>脏标记追踪"]
        Coord["CanvasCoordinator<br/>屏幕切换"]
        LAR["LocalActorResolver<br/>本地角色解析"]
    end

    subgraph "canvas/ （10+ 独立画布）"
        base["base/<br/>主界面"]
        always["always_show/<br/>常驻 UI"]
        popup["popup/<br/>模态弹窗"]
        dice["dice/<br/>掷骰屏"]
        market["market/<br/>黑市屏"]
        pc["player_choice/<br/>玩家选择"]
        tc["target_choice/<br/>目标选择"]
        rc["remote_choice/<br/>远程选择"]
        sc["secondary_confirm/<br/>二次确认"]
        bankr["bankruptcy/<br/>破产屏"]
        loading["loading/<br/>加载屏"]
    end

    CReg --> base
    CReg --> always
    CReg --> popup
    CReg --> dice
    CReg --> market
    CReg --> pc
    CReg --> tc
    CReg --> rc
    CReg --> sc
    CReg --> bankr
    CReg --> loading

    CER --> CReg
    Coord --> CStore
```


## 单个画布结构

```text
src/presentation/canvas/<canvas_key>/
  nodes.lua          — UI 节点名称常量
  contract.lua       — 数据契约（画布需要的输入数据）
  intents.lua        — 交互意图（点击事件 → intent 对象）
  presenter.lua      — 呈现逻辑（open / close / render）
  touch_policy.lua   — 触控启用/禁用策略
```

```mermaid
classDiagram
    class CanvasModule {
        +nodes : table
        +contract : table
        +intents : table
        +presenter : table
        +touch_policy : table
    }

    class nodes {
        +NODE_NAMES : string[]
    }

    class contract {
        +build(game_state) : view_data
    }

    class intents {
        +build(state) : route_spec[]
    }

    class presenter {
        +open(state, view_data)
        +close(state)
        +render(state, view_data)
    }

    class touch_policy {
        +enable(state)
        +disable(state)
    }

    CanvasModule --> nodes
    CanvasModule --> contract
    CanvasModule --> intents
    CanvasModule --> presenter
    CanvasModule --> touch_policy
```


## 交互分发流程

```mermaid
sequenceDiagram
    participant User as 用户
    participant Node as UI 节点
    participant CER as CanvasEventRouter
    participant LAR as LocalActorResolver
    participant UID as UIIntentDispatcher
    participant AP as ActionPort

    User->>Node: 点击
    Node->>CER: click 事件 + payload
    CER->>LAR: 解析当前角色 ID
    CER->>CER: 查找 route_spec → 构建 intent
    CER->>UID: dispatch(state, game, intent)

    alt 视图命令（toggle_action_log 等）
        UID->>UID: dispatch_view_command()
    else 游戏动作
        UID->>AP: check_blocked()
        alt 未锁定
            UID->>AP: dispatch_game_action()
            AP->>AP: TurnActionPort → 转发到 GameplayLoop
        else 已锁定
            UID-->>User: 操作被阻止
        end
    end
```


## 输入锁定策略

```mermaid
stateDiagram-v2
    [*] --> Unlocked

    Unlocked --> InputLocked : 动画播放中
    InputLocked --> Unlocked : 动画完成

    Unlocked --> RoleControlLocked : 非当前玩家操作
    RoleControlLocked --> Unlocked : 轮到该玩家

    Unlocked --> ChoiceLocked : 选择模态打开
    ChoiceLocked --> Unlocked : 选择完成
```


## 渲染管线

```mermaid
flowchart TD
    GameState["游戏状态变更"] --> Dirty["DirtyTracker<br/>标记脏域"]
    Dirty --> UIModel["UIModel.update()<br/>增量计算 UI 模型"]
    UIModel --> Slices["状态切片"]

    Slices --> BS["BoardSlice<br/>棋盘 · 格子 · 位置"]
    Slices --> PS["PanelSlice<br/>玩家面板"]
    Slices --> IS["ItemSlice<br/>道具槽"]
    Slices --> CS["ChoiceSlice<br/>选择 · 市场"]

    BS --> BoardRT["BoardRuntime.refresh()<br/>同步格子与玩家单位"]
    PS --> BaseP["base/presenter<br/>刷新面板"]
    IS --> ItemP["item_slots/presenter<br/>刷新道具槽"]
    CS --> ChoiceP["choice/presenter<br/>刷新选择屏"]

    BoardRT --> Render["最终渲染到屏幕"]
    BaseP --> Render
    ItemP --> Render
    ChoiceP --> Render
```


## 动画系统

```mermaid
classDiagram
    class ActionAnim {
        +play(state, anim_type, opts) : duration
    }

    class ActionAnimRegistry {
        +register(type, handler)
        +resolve(type) : handler
    }

    class MoveAnim {
        +step_duration(mode) : seconds
        +one_step(state, role, from, to, mode)
        +play_sequence(state, role, path, mode)
    }

    class BoardRuntime {
        +refresh(state, ui_model)
        +sync_positions()
    }

    ActionAnim --> ActionAnimRegistry
    ActionAnim ..> MoveAnim : 移动类动画委托
    MoveAnim --> BoardRuntime : 更新位置
```

动画类型包括：`roll`（掷骰）、`roadblock`（路障）、`mine`（地雷）、`missile`（导弹）、`clear_obstacles`（清除障碍）。


## 展示层目录结构

```text
src/presentation/
├── api/                  — 服务 API（UIViewService · PresentationPorts）
│   ├── presentation_ports/  — 端口接口定义
│   └── ui_view_service/     — 视图命令实现
├── canvas/               — 10+ 独立画布模块
├── canvas_runtime/       — 画布编排（Registry · State · EventRouter · Store）
├── interaction/          — 输入处理（IntentDispatcher · TouchPolicy · ChoiceRoute）
├── render/               — 渲染（ActionAnim · MoveAnim · BoardRuntime · TileRenderer）
├── state/                — UI 状态（UIModel + 4 个切片）
├── read_model/           — 只读游戏状态查询
├── shared/               — 常量与工具（UIAliases · PlayerColors · UIEvents）
└── ui/                   — UI 组件（面板 · 模态 · 效果）
```

# 游戏子系统


## 目的

描述 `src/game/systems/` 下各子系统的职责、接口与协作关系。这些子系统实现大富翁的核心游戏机制，由回合阶段（PhaseRegistry）在适当时机调用。


## 子系统总览

```mermaid
graph TB
    subgraph "src/game/systems/"
        Board["board/<br/>Board · Tile<br/>棋盘结构"]
        Movement["movement/<br/>Movement<br/>移动计算"]
        Land["land/<br/>LandActions · LandRules<br/>LandRentResolver<br/>LandingEffectExecutors<br/>地产系统"]
        Chance["chance/<br/>ChanceResolver<br/>ChanceHandlers<br/>机会卡系统"]
        Items["items/<br/>ItemPhase · ItemExecutor<br/>ItemRegistry<br/>道具系统"]
        Market["market/<br/>MarketService<br/>黑市系统"]
        Effects["effects/<br/>EffectRegistry · EffectExecutor<br/>EffectPipeline<br/>效果管线"]
        Vehicle["vehicle/<br/>VehicleFeature<br/>载具系统"]
        Choices["choices/<br/>ChoiceRegistry · ChoiceResolver<br/>选择解析"]
        Commerce["commerce/<br/>PaidCurrencyBridge<br/>付费货币"]
    end

    Movement --> Board
    Land --> Board
    Land --> Effects
    Chance --> Effects
    Items --> Effects
    Items --> Choices
    Market --> Choices
    Market --> Commerce
    Land --> Choices
```


## 地产系统（Land）

```mermaid
classDiagram
    class LandActions {
        +buy_land(game, player, tile)
        +upgrade_land(game, player, tile)
        +pay_rent(game, payer, tile)
    }

    class LandRules {
        +can_buy(player, tile) : bool
        +can_upgrade(player, tile) : bool
        +upgrade_cost(tile) : number
        +is_owned(tile) : bool
    }

    class LandRentResolver {
        +resolve_rent(game, payer, tile) : number
        +apply_modifiers(base, game, payer, tile) : number
    }

    class LandingEffectExecutors {
        +pass_players()
        +start_reward()
        +pay_rent()
        +tax()
        +hospital()
        +mountain()
        +mine()
        +buy_land()
        +upgrade_land()
    }

    LandActions --> LandRules
    LandActions --> LandRentResolver
    LandingEffectExecutors --> LandActions
    LandingEffectExecutors --> LandRules
```


## 机会卡系统（Chance）

```mermaid
flowchart LR
    Draw["抽取机会卡"] --> Resolve["ChanceResolver.resolve()"]
    Resolve --> Handlers["ChanceHandlers\n（按卡类型分发）"]
    Handlers --> E1["移动效果"]
    Handlers --> E2["金钱效果"]
    Handlers --> E3["道具效果"]
    Handlers --> E4["状态效果"]
    Handlers --> EP["EffectPipeline"]
```


## 道具系统（Items）

道具在回合的三个时机执行：掷骰前（pre_action）、移动前（pre_move）、着陆后（post_action）。

```mermaid
flowchart TD
    IP["ItemPhase"] -->|当前阶段| IC["检查可用道具"]
    IC -->|有可用道具| Choice["弹出选择界面"]
    Choice -->|玩家选择| IE["ItemExecutor.execute()"]
    IE --> IR["ItemRegistry\n按道具类型分发"]

    IR --> free_rent["免租卡"]
    IR --> remote_dice["遥控骰子"]
    IR --> roadblock["路障"]
    IR --> steal["偷窃"]
    IR --> missile["导弹"]
    IR --> demolish["拆除"]
    IR --> angel["守护天使"]
    IR --> others["...共 19 种"]

    IE -->|效果| EP["EffectPipeline"]
```


## 市场系统（Market）

```mermaid
sequenceDiagram
    participant Player
    participant MS as MarketService
    participant Elig as Eligibility
    participant Choice as ChoiceResolver
    participant Commerce as PaidCurrencyBridge

    Player->>MS: 触发市场（着陆市场格）
    MS->>Elig: check_eligibility(player)
    Elig-->>MS: 可购买商品列表
    MS->>Choice: 弹出购买选择
    Choice-->>MS: 玩家选择商品

    alt 金币支付
        MS->>MS: deduct_gold(player, price)
    else 付费货币
        MS->>Commerce: purchase(player, product_id)
        Commerce-->>MS: 支付结果
    end

    MS->>Player: 发放道具/载具
```


## 效果管线（Effects）

```mermaid
flowchart LR
    Source["触发源<br/>Land / Chance / Item"] --> Pipeline["EffectPipeline"]
    Pipeline --> Registry["EffectRegistry<br/>按效果类型查找处理器"]
    Registry --> Executor["EffectExecutor<br/>执行效果"]
    Executor --> State["更新游戏状态<br/>（余额 / 位置 / 状态 / 道具）"]
    Executor --> Event["发送 MonopolyEvent"]
```


## 移动系统（Movement）

```mermaid
flowchart TD
    Roll["掷骰结果<br/>dice_count × dice_value"] --> Calc["Movement.calculate()"]
    Calc --> Path["计算路径<br/>（线性 / 分支）"]
    Path --> Check["检查路障 / 偷窃 / 市场中断"]

    Check -->|无障碍| Arrive["到达目标格"]
    Check -->|路障| Stop["停在路障处"]
    Check -->|偷窃| Steal["触发偷窃效果后继续"]
    Check -->|市场中断| MarketInt["打开市场后继续"]

    Arrive --> Landing["触发着陆效果"]
```


## 子系统协作全景

```mermaid
graph TD
    Turn["回合阶段<br/>PhaseRegistry"] --> |start| TurnStart["TurnStart<br/>初始化 / 拘留"]
    Turn --> |roll| TurnRoll["TurnRoll<br/>掷骰 + 道具前置"]
    Turn --> |move| TurnMove["TurnMove<br/>移动 + 路障检测"]
    Turn --> |landing| TurnLand["TurnLand<br/>着陆效果"]
    Turn --> |post_action| PostAction["PostAction<br/>道具后置"]
    Turn --> |end_turn| EndTurn["EndTurn<br/>清理 / 下一人"]

    TurnRoll --> Items
    TurnRoll --> Movement
    TurnMove --> Movement
    TurnMove --> Board
    TurnLand --> Land
    TurnLand --> Chance
    TurnLand --> Market
    TurnLand --> Effects
    PostAction --> Items

    Items["道具系统"]
    Movement["移动系统"]
    Board["棋盘"]
    Land["地产系统"]
    Chance["机会卡系统"]
    Market["市场系统"]
    Effects["效果管线"]
```

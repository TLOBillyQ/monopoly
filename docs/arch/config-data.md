# 配置与数据模型


## 目的

描述内容配置（`Config/`）与运行时策略配置（`src/*/config`）的结构，帮助开发者理解游戏数据如何驱动运行时行为。


## 配置层结构

```text
Config/
├── Generated/            — 由设计表生成的游戏数据
│   ├── Tiles.lua         — 45 块格子定义
│   ├── Roles.lua         — 3 个角色定义
│   ├── Items.lua         — 19 种道具定义
│   ├── Vehicles.lua      — 12 种载具定义（4 档）
│   ├── ChanceCards.lua   — 机会卡牌池
│   ├── Constants.lua     — 数值常量（初始资金、过路费、税率等）
│   └── Market.lua        — 31 个商店商品
├── Maps/                 — 地图配置
│   ├── DefaultMap.lua    — 默认 10×10 棋盘
│   └── RingMapBuilder.lua — 地图构建器
└── RuntimeRefs.lua       — 运行时引用（资源映射）

src/
├── core/config/GameplayRules.lua                     — 游戏规则与调试开关
├── game/systems/land/config/LandingEffects.lua       — 13 种着陆效果定义
├── game/systems/commerce/config/RuntimePaidGoods.lua — 付费商品配置
├── app/testing/config/TestProfiles.lua               — 测试场景预设
└── core/config/RuntimeConstants.lua                  — 运动向量、速度、FPS
```


## 格子数据模型（Tiles）

```mermaid
erDiagram
    TILE {
        number id PK
        string name
        string type "land / start / hospital / mountain / tax / market / chance / item"
        number price "购买价格（仅 land）"
        number[] upgrade_costs "升级费用数组（仅 land）"
        number[] rents "各级租金数组（仅 land）"
        number x "棋盘坐标"
        number y "棋盘坐标"
    }

    BOARD {
        number width
        number height
        table neighbors "邻居关系表"
        table direction_routing "方向路由表"
    }

    BOARD ||--o{ TILE : contains
```

棋盘共 45 格：24 块可购买地产、1 个起点、1 个医院、1 座山、1 个税务局、1 个市场、4 个机会卡格、2 个道具格，以及若干路径格。


## 道具数据模型（Items）

```mermaid
classDiagram
    class Item {
        +number id
        +string name
        +string type
        +number tier
        +table shop_prices
        +string effect_type
    }

    class ShopPrice {
        +number gold "金币"
        +number park_coin "乐园币"
        +number golden_bean "金豆"
    }

    Item --> ShopPrice

    note for Item "19 种道具，分 3 档\nTier 1: 基础（免租/骰子控制）\nTier 2: 中级（路障/偷窃/导弹）\nTier 3: 高级（拆除/天使守护）"
```

| 道具阶段 | 时机 | 示例 |
|----------|------|------|
| pre_action | 掷骰前 | 遥控骰子 |
| pre_move | 移动前 | 路障放置 |
| post_action | 着陆后 | 偷窃、导弹 |


## 载具数据模型（Vehicles）

```mermaid
graph LR
    subgraph "Tier 1 (基础)"
        V1["滑板<br/>2 骰"]
        V2["自行车<br/>2 骰"]
        V3["摩托车<br/>2 骰"]
    end

    subgraph "Tier 2 (中级)"
        V4["跑车<br/>2 骰"]
        V5["赛车<br/>3 骰"]
        V6["法拉利<br/>3 骰"]
    end

    subgraph "Tier 3 (高级)"
        V7["恐龙 A<br/>3 骰"]
        V8["恐龙 B<br/>3 骰"]
        V9["恐龙 C<br/>3 骰"]
    end

    subgraph "Tier 4 (传奇)"
        V10["坦克<br/>3 骰 不可摧毁"]
        V11["无人机<br/>3 骰 不可摧毁"]
        V12["UFO<br/>3 骰 不可摧毁"]
    end

    V1 --> V4 --> V7 --> V10
```


## 着陆效果定义（LandingEffects）

```mermaid
flowchart TD
    Arrive["玩家到达格子"] --> Check["按格子类型<br/>查找着陆效果"]

    Check --> pass["pass_players<br/>擦肩（对手格）"]
    Check --> start["start_reward<br/>起点奖励"]
    Check --> item["item_draw_and_give<br/>抽取道具"]
    Check --> chance["chance_draw_and_resolve<br/>抽取机会卡"]
    Check --> hospital["hospital<br/>住院（扣费 + 拘留）"]
    Check --> mountain["mountain<br/>翻山（跳过）"]
    Check --> market["market<br/>黑市购物"]
    Check --> rent["pay_rent<br/>缴纳租金"]
    Check --> tax["tax<br/>缴纳税款"]
    Check --> mine["mine<br/>触发地雷"]
    Check --> buy["buy_land<br/>购买空地"]
    Check --> upgrade["upgrade_land<br/>升级地产"]
```


## 游戏规则（GameplayRules）

```mermaid
mindmap
  root((GameplayRules))
    调试
      log_max_lines: 50
      test_profile
    AI
      ai_turn_interval: 0.4s
      force_non_p1_ai
    道具
      19 种类型
      3 个使用阶段
    掉线
      reconnect_grace: 20s
      offline_takeover: 90s
      max_replay_events: 400
    载具
      vehicle_disabled
    角色控制
      role_control_locked
```


## 数值常量（Constants）

```mermaid
graph TD
    subgraph "经济参数"
        Cash["初始资金: 100,000"]
        Pass["过路奖励: 2,000"]
        Hospital["住院费: 5,000"]
        HospStay["住院拘留: 2 回合"]
        Tax["税率: 50%"]
    end

    subgraph "游戏参数"
        Inv["道具槽: 5 个"]
        Deity["天使守护: 5 回合"]
    end
```


## 地图结构（DefaultMap）

```mermaid
graph TD
    subgraph "10×10 棋盘"
        direction TB
        Start["起点 (9,9)"] --> Outer["外圈路径<br/>（顺时针 36 格）"]
        Outer --> Inner["内十字路径"]
        Inner --> Center["市场中心 (5,5)"]
    end

    subgraph "路径类型"
        OuterPath["外圈：地产 + 特殊格"]
        InnerPath["内十字：连接 4 个入口到市场"]
    end
```

棋盘为 10×10 网格。外圈构成主路径，玩家沿此路径移动。中心有十字形内部路径连接到黑市。方向路由表定义了在每个交叉点的行进方向。


## 数据驱动设计

配置数据与代码逻辑完全分离。`Config/Generated/` 下的文件由 `docs/design/` 中的 Excel 设计表导出：

```text
docs/design/
├── 格子.xlsx        → Config/Generated/Tiles.lua
├── 道具.xlsx        → Config/Generated/Items.lua
├── 载具.xlsx        → Config/Generated/Vehicles.lua
├── 机会卡.xlsx      → Config/Generated/ChanceCards.lua
├── 角色.xlsx        → Config/Generated/Roles.lua
├── 常量.xlsx        → Config/Generated/Constants.lua
└── 商店.xlsx        → Config/Generated/Market.lua
```

修改游戏数值只需更新设计表并重新生成，无需修改代码逻辑。

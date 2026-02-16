# 彻底重构方案（参考 deepfuture）

参考 cloudwu/deepfuture 的游戏项目结构，采用直白功能命名。

## 设计原则

1. **直白命名** - 用 `game/` `visual/` `turn/` 替代抽象术语
2. **无 lib/ 前缀** - 直接放在项目根目录
3. **小写命名** - 目录和文件全小写，snake_case
4. **适度 init.lua** - 按需使用，不强求
5. **最大深度 3 层** - 消除深层嵌套
6. **合并碎片化** - <300行合并，>500行保留子目录

## 命名对照（旧 → 新）

| 原命名 | 新命名 | 理由 |
|--------|--------|------|
| `world/` | `game/` | 直白，游戏核心 |
| `flow/` | `turn/` | 具体，表示回合流程 |
| `ui/` | `visual/` | deepfuture 风格 |
| `policy/` | `rule/` | 直白，游戏规则 |
| `effect/` | `effect/` | 保留，已够简洁 |
| `input/` | `control/` | 操控层 |

## 目录映射（旧 → 新）

```
src/                                    → 删除
├── app/init.lua                        → app.lua
├── core/                               → core/
│   ├── Logger.lua                      → logger.lua
│   ├── Flow.lua                        → flow.lua
│   ├── DirtyTracker.lua                → dirty.lua
│   ├── NumberUtils.lua                 → math.lua
│   ├── RuntimeContext.lua              → context.lua
│   ├── RuntimeEnvBindings.lua          → env.lua
│   └── RuntimeEditorExports.lua        → editor.lua
├── game/core/runtime/                  → game/
│   ├── Game.lua                        → init.lua (门面)
│   ├── GameFactory.lua                 → factory.lua
│   ├── bootstrap/CompositionRoot.lua   → bootstrap.lua
│   ├── state/                          → state.lua (合并)
│   ├── policies/                       → rule/
│   └── events/MonopolyEvents.lua       → event.lua
├── game/core/player/                   → game/
│   ├── Player.lua                      → player.lua
│   └── Inventory.lua                   → bag.lua (背包)
├── game/systems/                       → game/
│   ├── board/                          → board.lua + tile.lua
│   ├── land/                           → land/
│   ├── items/                          → item/
│   ├── effects/                        → effect/
│   ├── chance/                         → chance.lua
│   ├── choices/                        → choice/
│   ├── market/Market.lua               → shop.lua (商店)
│   └── movement/Movement.lua           → move.lua
├── game/flow/                          → turn/ (回合流程)
│   ├── turn/GameplayLoop.lua           → init.lua
│   ├── turn/GameplayLoopRuntime.lua    → runtime.lua
│   ├── turn/TurnDispatch.lua           → dispatch.lua
│   ├── turn/TurnFlow.lua               → phase.lua
│   ├── intent/IntentDispatcher.lua     → intent.lua
│   └── turn/Turn*.lua                  → step/*.lua
└── presentation/                       → visual/
    ├── api/                            → 合并到 init.lua
    ├── state/                          → model.lua
    ├── render/                         → render/
    ├── interaction/                    → control/
    └── ui/                             → widget/
```

## 新目录结构

```
.
├── core/                   -- 基础设施层
│   ├── logger.lua
│   ├── flow.lua
│   ├── dirty.lua
│   ├── math.lua
│   ├── context.lua
│   ├── env.lua
│   └── editor.lua
├── game/                   -- 游戏核心层
│   ├── init.lua            -- 游戏门面 (原 Game.lua)
│   ├── player.lua
│   ├── bag.lua             -- 背包系统 (原 Inventory)
│   ├── factory.lua
│   ├── bootstrap.lua
│   ├── event.lua
│   ├── state.lua           -- 聚合 state
│   ├── board.lua
│   ├── tile.lua
│   ├── shop.lua            -- 商店 (原 Market)
│   ├── move.lua
│   ├── rule/               -- 游戏规则
│   │   ├── agent.lua
│   │   ├── target.lua
│   │   ├── bankrupt.lua
│   │   └── win.lua         -- 胜利条件
│   ├── land/               -- 土地系统
│   │   ├── init.lua
│   │   ├── rule.lua
│   │   ├── price.lua
│   │   ├── action.lua
│   │   └── effect.lua
│   ├── item/               -- 道具系统
│   │   ├── init.lua
│   │   ├── registry.lua
│   │   ├── executor.lua
│   │   ├── strategy.lua
│   │   ├── phase.lua
│   │   ├── post.lua
│   │   └── handler/
│   │       ├── init.lua
│   │       ├── demolish.lua
│   │       ├── steal.lua
│   │       ├── roadblock.lua
│   │       └── dice.lua    -- 遥控骰子
│   └── effect/             -- 效果系统
│       ├── pipeline.lua
│       ├── executor.lua
│       ├── runner.lua
│       └── mine.lua
├── turn/                   -- 回合流程层
│   ├── init.lua            -- gameplay loop
│   ├── runtime.lua
│   ├── dispatch.lua
│   ├── intent.lua
│   ├── auto.lua
│   ├── phase.lua           -- 回合阶段
│   └── step/               -- 回合步骤
│       ├── begin.lua       -- 回合开始
│       ├── roll.lua        -- 掷骰
│       ├── walk.lua        -- 移动
│       ├── arrive.lua      -- 落地
│       ├── decide.lua      -- 决策
│       ├── wait.lua
│       ├── anim.lua
│       └── log.lua
├── chance.lua              -- 机会卡
├── choice/                 -- 选择系统
│   ├── init.lua            -- registry
│   ├── resolve.lua
│   └── handler.lua
├── visual/                 -- 视觉表现层
│   ├── init.lua            -- view + ports
│   ├── model.lua           -- ui model
│   ├── render/             -- 场景渲染
│   │   ├── board.lua
│   │   ├── tile.lua
│   │   ├── move.lua
│   │   ├── action.lua
│   │   └── effect.lua
│   ├── control/            -- 输入控制
│   │   ├── router.lua
│   │   ├── dispatch.lua
│   │   ├── intent.lua
│   │   ├── builder.lua
│   │   └── policy.lua
│   └── widget/             -- UI组件
│       ├── panel.lua
│       ├── modal.lua
│       └── choice.lua
├── app.lua                 -- 应用组装
└── main.lua                -- 入口
```

## Require 路径对比

| 旧路径 | 新路径 | 说明 |
|--------|--------|------|
| `src.game.core.runtime.Game` | `game` | 门面直接用目录名 |
| `src.game.core.runtime.bootstrap.CompositionRoot` | `game.bootstrap` | 扁平 |
| `src.game.flow.turn.GameplayLoop` | `turn` | 简洁 |
| `src.game.flow.turn.TurnDispatch` | `turn.dispatch` | 去重复 |
| `src.presentation.api.UIView` | `visual` | 直白 |
| `src.presentation.interaction.UIEventRouter` | `visual.control.router` | 操控层 |
| `src.core.Logger` | `core.logger` | 一致 |
| `src.game.systems.market.Market` | `game.shop` | 商店 |
| `src.game.core.player.Inventory` | `game.bag` | 背包 |

## 文件合并原则

- **<300行且职责紧密** → 合并
- **>500行或处理器多** → 保留子目录

## 具体合并

| 原文件 | 新文件 | 行数 |
|--------|--------|------|
| state/*4个 | game/state.lua | ~300 |
| chance/*2个 | chance.lua | 469 |
| choice/*4个 | choice/*.lua | 550 |
| item/handler/* | item/handler/*.lua | 686 |

## 包路径配置

```lua
-- main.lua
package.path = "?.lua;?/init.lua;" .. package.path

local app = require "app"
app.start()
```

## 迁移步骤

1. **创建新目录** - core/, game/, turn/, visual/
2. **迁移 core/**
3. **迁移 game/**
4. **迁移 turn/**
5. **迁移 visual/**
6. **创建 app.lua**
7. **更新 main.lua**
8. **测试**
9. **删除 src/**

## 深度对比

| 路径 | 旧深度 | 新深度 |
|------|--------|--------|
| CompositionRoot | 5 | 2 |
| GameplayLoop | 5 | 2 |
| UIEventRouter | 5 | 3 |
| ItemDemolish | 5 | 3 |
| GameStateTurn | 5 | 2 |
| Market | 4 | 2 |

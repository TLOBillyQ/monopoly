# SOLID 与好莱坞原则评审报告

**日期**: 2026-01-18  
**范围**: `src/` 目录下全部 Lua 模块

---

## 一、总体评价

| 原则 | 评级 | 说明 |
|------|------|------|
| **SRP** (单一职责) | ★★★☆☆ | 多数模块职责清晰，但 `landing.lua`、`land.lua`、`choice_service.lua` 混合职责较重 |
| **OCP** (开闭原则) | ★★★★☆ | Effect 系统通过 `defs` 数组实现良好扩展，但回合阶段硬编码 |
| **LSP** (里氏替换) | ★★★★☆ | Lua 动态特性下无显式继承，模块间接口稳定 |
| **ISP** (接口隔离) | ★★☆☆☆ | 大量函数依赖"大上下文对象"（`game`、`ctx`），接口粒度粗糙 |
| **DIP** (依赖倒置) | ★★★☆☆ | `composition_root.lua` 具备 DI 雏形，但上层仍大量直接 `require` |
| **Hollywood** (好莱坞) | ★★★☆☆ | 部分场景遵循回调/注册模式，但 UI 层主动轮询较多 |

---

## 二、逐原则分析

### 2.1 SRP（单一职责原则）

**良好实践**：
- `src/core/` 领域对象（`dice.lua`、`rng.lua`、`store.lua`、`flow.lua`）职责单一
- `*_service.lua` 按功能划分（movement、market、bankruptcy、choice）
- `choice_handlers/` 拆分策略模式处理器

**违例点**：

| 文件 | 问题 | 建议 |
|------|------|------|
| `landing.lua` | 混合"效果定义"与"效果执行"，含 13 种效果逻辑 | 将 `defs` 提取为纯配置，执行逻辑下沉至 `effect_pipeline` |
| `land.lua` | 同时处理租金计算、连续地块、购买/升级、强征卡、免租卡 | 拆分为 `rent_calculator.lua` + `land_actions.lua` |
| `item_executor.lua` | 包含 AI 决策逻辑、choice 构建、道具执行 | 将 choice 构建移至专用 builder |
| `player.lua` | 承载状态管理、资金操作、效果应用（医院/深山）、载具逻辑 | 效果应用委托给外部 handler |
| `turn_manager.lua` | 混合流程驱动、choice 解析、AI 决策分发 | 提取 `ChoiceResolver` |

### 2.2 OCP（开闭原则）

**良好实践**：
- `Effect.defs` 数组 + `can_apply/apply` 钩子，新增效果无需改动核心代码
- `choice_handlers/` 模式：新增 handler 只需注册到 `choice_service.lua`
- `market_cfg`/`items_cfg` 数据驱动

**违例点**：

| 文件 | 问题 | 建议 |
|------|------|------|
| `turn_manager.lua` L14-20 | `PHASES` 硬编码 6 个阶段 | 改为配置或注册表 |
| `choice_service.lua` L80-95 | `choice.kind` 硬编码 switch | 统一走 handler 注册表 |
| `item_executor.lua` | 每种道具单独 `if/elseif` 分支 | 引入 `item_handlers` 注册表 |

### 2.3 LSP（里氏替换原则）

Lua 无静态类型，但项目遵循：
- 所有 `*Service` 模块均暴露一致签名（`Service.xxx(game, player, ...)`）
- `Effect.defs` 中每个效果均实现 `can_apply(ctx)` + `apply(ctx)` 协议
- `choice_handlers` 均返回 `{ stay = boolean }`

**潜在风险**：
- `game.services.*` 注册的模块若签名不一致将导致运行时崩溃
- 建议：添加 `assert` 或运行时类型校验

### 2.4 ISP（接口隔离原则）

**主要问题**：函数普遍接收"大上下文对象"，调用者无法按需获取依赖。

| 模式 | 文件示例 | 问题 |
|------|----------|------|
| `ctx` 大对象 | `Effect.build_ctx` 含 9 个字段 | 效果函数只用 2-3 个字段，却必须构建完整 ctx |
| `game` 传递 | 几乎所有 `*_service` | 函数依赖 `game.board`、`game.rng`、`game.store` 等，但签名只见 `game` |
| `deps` 注入 | `item_executor.use_item` | 部分依赖注入（`inventory`、`strategy`），但其他依赖仍直接 require |

**改进方向**：
1. 将 `ctx` 拆分为 `{ player, tile }` + `{ game_ctx }` 两级
2. 服务函数显式声明所需依赖（如 `move(board, player, steps)`）

### 2.5 DIP（依赖倒置原则）

**良好实践**：
- `composition_root.lua` 统一装配 `services`、`store`、`rng`
- `game:get_service("choice")` 实现服务定位
- `player.inventory._on_change` 回调注入

**违例点**：

| 文件 | 直接依赖 | 建议 |
|------|----------|------|
| `turn_manager.lua` | 硬编码 `require("src.gameplay.turn_start")` 等 6 个模块 | 通过 `composition_root` 注入阶段 handlers |
| `choice_service.lua` | 直接 require `Inventory`/`Executor`/`Strategy`/`Effect` | 通过 `deps` 参数注入 |
| `landing.lua` | 直接 require `chance_effects`/`MineEffect`/`Steal` | 将效果实现注入 `defs` 中 |
| `market_service.lua` | 直接 require `Inventory`/`Agent` | 注入或通过 services 获取 |
| `love_layer.lua` | 直接 require `Modal`/`AutoRunner`/`UIState` | UI 层依赖注入已分离，可接受 |

### 2.6 Hollywood 原则（"Don't call us, we'll call you"）

**良好实践**：
- `IntentDispatcher.dispatch(game, payload)` — 框架回调 UI 层
- `player.inventory._on_change` 回调同步 store
- `Effect.defs` + `Pipeline.run` — 框架遍历效果定义并回调

**违例点**：

| 场景 | 问题 | 改进 |
|------|------|------|
| UI 轮询 choice | `LoveLayer:get_pending_choice()` 主动查询 store | 改为 `IntentDispatcher` 推送 |
| AutoRunner tick | `auto_runner:update(dt)` 由外部驱动 | 可接受（游戏主循环模式） |
| AI 决策 | `DecisionEngine.get_choice_action(game, choice)` 被 `turn_manager` 主动调用 | 考虑注册 AI 策略回调 |

---

## 三、依赖图分析

```
main.lua
  └─ Game (src/game.lua)
       └─ CompositionRoot (装配点)
            ├─ core/* (Board, Player, Dice, RNG, Store, Flow)
            ├─ gameplay/services (Movement, Market, Bankruptcy, Choice)
            ├─ gameplay/turn_* (阶段处理)
            └─ gameplay/effect* (效果系统)

adapters/love2d/*
  └─ Game (依赖注入)
       └─ IntentDispatcher (事件推送)
```

**当前依赖方向**：
- ✅ `adapters/` → `gameplay/` → `core/`
- ✅ `gameplay/` 不依赖 `adapters/`（已通过 `deps_check.lua` 校验）
- ⚠️ `gameplay/` 内部服务间存在隐式依赖（通过 `game.services.*`）

---

## 四、代表性改进示例

### 示例 1：提取 ChoiceResolver

**现状** (`turn_manager.lua` L52-55)：
```lua
local function resolve_choice(game, choice, action)
  local service = game and game.get_service and game:get_service("choice")
  return service.resolve(game, choice, action) or {}
end
```

**改进**：将 `resolve_choice` 作为 `TurnManager` 的可注入依赖：
```lua
function TurnManager.new(game, opts)
  local tm = {
    game = game,
    resolve_choice = opts.resolve_choice or default_resolver,
  }
  return setmetatable(tm, TurnManager)
end
```

### 示例 2：Effect 定义与执行分离

**现状** (`landing.lua`)：
```lua
Effect.defs = {
  {
    id = "pass_players",
    apply = function(ctx)
      return Steal.handle_pass_players(ctx.game, ctx.player, ids)
    end,
  },
  -- ...
}
```

**改进**：纯配置 + 外部注入执行器
```lua
-- config/landing_effects.lua
return {
  { id = "pass_players", mandatory = true },
  { id = "start_reward", mandatory = true },
}

-- gameplay/landing.lua (执行层)
local executors = {
  pass_players = require("src.gameplay.effects.pass_players"),
  start_reward = require("src.gameplay.effects.start_reward"),
}
```

---

## 五、改进路线图

详见 [roadmap.md](roadmap.md)

---

## 六、结论

本项目在架构上已具备良好基础：
1. **分层清晰**：core/gameplay/adapters 三层隔离
2. **DI 雏形**：`composition_root.lua` 统一装配
3. **扩展点**：Effect 系统、choice_handlers 支持插件式扩展

主要改进方向：
1. **减少大上下文对象**：拆分 `ctx`、`game` 为细粒度参数
2. **依赖注入彻底化**：消除 gameplay 层的直接 `require`
3. **统一回调模式**：扩大 `IntentDispatcher` 覆盖范围

遵循项目 AGENTS.md 原则：**优先删除或复用，而非新增抽象**。

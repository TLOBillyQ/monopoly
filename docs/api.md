# API 文档（关键入口）

> 说明：仅列出核心入口与常用服务，参数与返回值以当前实现为准。

## Game

### Game.new(opts)
- **参数**: `opts`（table）
  - `players`: 玩家名称数组
  - `ai`: AI 玩家索引映射（可选）
  - `auto_all`: 是否全自动（可选）
  - `seed`: 随机种子（可选）
- **返回**: `game` 实例

### Game.dispatch_action(action)
- **参数**: `action`（table）
- **返回**: 无

## MovementService

### MovementService.move(game, player, steps, opts)
- **参数**:
  - `game`: Game 实例
  - `player`: Player 实例
  - `steps`: 步数（可为负数）
  - `opts`（可选）: `{ branch_parity, direction, skip_market_check }`
- **返回**: `{ encountered_players, passed_start, stopped_on_roadblock, visited, landing_tile, steps, market_interrupt }`

## ChoiceService

### ChoiceService.resolve(game, choice, action)
- **参数**:
  - `choice`: 待处理选择对象（包含 `kind`, `options`, `meta`）
  - `action`: `{ type, option_id, choice_id }`
- **返回**: `{ stay = boolean }`

## MarketService

### MarketService.buy(game, player, product_id)
- **参数**:
  - `product_id`: 商品 ID（number）
- **返回**: `true` 或 `{ ok = false, intent = ... }`

## ItemExecutor

### Executor.use_item(game, player, item_id, context, deps)
- **参数**:
  - `item_id`: 道具 ID（number）
  - `context`: `{ by_ai, target_id, services }`（可选）
  - `deps`: `{ inventory, strategy }`
- **返回**: `boolean` 或 `{ waiting = true, intent = ... }`

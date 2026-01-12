# 优化实施快速启动指南

本指南提供了开始实施代码优化的具体步骤。

## 准备工作

### 1. 环境准备
```bash
# 确认工具已安装
love --version          # Love2D 11.x
lua -v                  # Lua 5.4 (可选，用于运行脚本)

# 创建工作分支
git checkout -b feature/code-optimization-phase1
```

### 2. 建立基线
```bash
# 记录当前行数
find . -name "*.lua" -exec wc -l {} + | tail -1 > baseline.txt

# 运行测试建立基线（如果有 Lua）
lua scripts/regression.lua
lua scripts/deps_check.lua

# 手动测试基线
love .  # 测试游戏功能正常
```

## 第一周：消除重复代码

### 任务 1.1: 创建公共服务访问模块 (2-3 小时)

#### 步骤 1: 创建 services.lua
```bash
# 创建文件
touch src/util/services.lua
```

```lua
-- src/util/services.lua
local Services = {}

function Services.get(game, key)
  return game and game.services and game.services[key]
end

function Services.status(game)
  return Services.get(game, "status")
end

function Services.bankruptcy(game)
  return Services.get(game, "bankruptcy")
end

function Services.tile(game)
  return Services.get(game, "tile")
end

function Services.movement(game)
  return Services.get(game, "movement")
end

function Services.item(game)
  return Services.get(game, "item")
end

function Services.market(game)
  return Services.get(game, "market")
end

function Services.chance(game)
  return Services.get(game, "chance")
end

return Services
```

#### 步骤 2: 在 item.lua 中使用
```lua
-- 在 src/gameplay/domain/item.lua 顶部添加
local Services = require("src.util.services")

-- 替换所有使用
-- 旧代码:
local function status_service(game)
  return get_service(game, "status")
end

-- 新代码:
-- 直接使用 Services.status(game)

-- 删除旧的 get_service 函数定义
```

#### 步骤 3: 在其他文件重复步骤 2
需要修改的文件：
- [ ] src/gameplay/domain/item.lua
- [ ] src/gameplay/domain/chance.lua
- [ ] src/gameplay/domain/land.lua
- [ ] src/gameplay/domain/landing.lua
- [ ] src/gameplay/app/choice_resolver.lua
- [ ] src/gameplay/app/landing_resolver.lua

#### 步骤 4: 测试
```bash
# 运行游戏
love .

# 测试关键功能
# - 使用道具
# - 触发机会牌
# - 购买地块
# - 检查服务调用
```

#### 步骤 5: 提交
```bash
git add src/util/services.lua
git add src/gameplay/domain/item.lua
# ... 其他修改的文件
git commit -m "refactor: extract common service access pattern to Services module"
```

**预计节省**: ~72 行

---

### 任务 1.2: 创建游戏状态访问模块 (1-2 小时)

#### 步骤 1: 创建 game_state.lua
```bash
touch src/util/game_state.lua
```

```lua
-- src/util/game_state.lua
local GameState = {}

function GameState.tile_state(game, tile)
  if not game or not game.store or not tile or tile.type ~= "land" then
    return { owner_id = nil, level = 0 }
  end
  local s = game.store:get({ "board", "tiles", tile.id })
  if type(s) ~= "table" then
    return { owner_id = nil, level = 0 }
  end
  return { owner_id = s.owner_id, level = s.level or 0 }
end

function GameState.total_invested(tile, owner_id, level)
  if not owner_id then
    return 0
  end
  level = level or 0
  local price = tile.price or 0
  return price * ((2 ^ (level + 1)) - 1)
end

return GameState
```

#### 步骤 2: 替换使用
需要修改的文件：
- [ ] src/gameplay/domain/item.lua
- [ ] src/gameplay/domain/land.lua
- [ ] src/gameplay/app/services/tile_service.lua

```lua
-- 在文件顶部添加
local GameState = require("src.util.game_state")

-- 替换所有 tile_state 调用
-- 旧: local st = tile_state(game, tile)
-- 新: local st = GameState.tile_state(game, tile)

-- 删除本地 tile_state 函数定义
```

#### 步骤 3: 测试和提交
```bash
love .  # 测试
git add src/util/game_state.lua
git add src/gameplay/domain/item.lua
git add src/gameplay/domain/land.lua
git add src/gameplay/app/services/tile_service.lua
git commit -m "refactor: extract tile_state to GameState module"
```

**预计节省**: ~30 行

---

## 第二周：简化核心文件

### 任务 2.1: 表驱动的 item.lua (4-6 小时)

这是一个较大的重构，需要分步进行。

#### 步骤 1: 识别模式
阅读 `src/gameplay/domain/item.lua` 的 `post_consume_handlers`，识别：
- 设置状态的道具 (2001, 2003, 2010)
- 附身类道具 (2017, 2019)
- 特殊逻辑道具 (2002, 2004-2006)

#### 步骤 2: 创建配置表
```lua
-- 在 item.lua 中添加
local SIMPLE_ITEM_EFFECTS = {
  [2001] = { 
    type = "set_status", 
    key = "pending_free_rent", 
    value = true,
    log = "使用免费卡，下一次租金免除"
  },
  [2003] = { 
    type = "set_status", 
    key = "pending_dice_multiplier", 
    value = 2,
    log = "使用骰子加倍卡，本次步数翻倍"
  },
  [2010] = { 
    type = "set_status", 
    key = "pending_tax_free", 
    value = true,
    log = "使用免税卡，本次征税免除"
  },
  [2017] = { 
    type = "deity", 
    deity = "rich",
    log = "附身财神"
  },
  [2019] = { 
    type = "deity", 
    deity = "angel",
    log = "附身天使"
  },
}
```

#### 步骤 3: 创建通用处理器
```lua
local function apply_simple_effect(game, player, item_id)
  local config = SIMPLE_ITEM_EFFECTS[item_id]
  if not config then
    return false
  end
  
  if config.type == "set_status" then
    game:set_player_status(player, config.key, config.value)
    logger.event(player.name .. " " .. config.log)
    return true
  end
  
  if config.type == "deity" then
    local status = Services.status(game)
    if not status then
      logger.warn("缺少 StatusService")
      return false
    end
    status.apply_deity(player, config.deity)
    logger.event(player.name .. " " .. config.log)
    return true
  end
  
  return false
end
```

#### 步骤 4: 替换原有 handlers
```lua
-- 替换所有简单的 post_consume_handlers
for item_id, _ in pairs(SIMPLE_ITEM_EFFECTS) do
  post_consume_handlers[item_id] = function(game, player, _context)
    return apply_simple_effect(game, player, item_id)
  end
end
```

#### 步骤 5: 逐步测试
```bash
# 每替换一批 handlers 就测试一次
love .
# 测试对应的道具功能
```

#### 步骤 6: 提交
```bash
git add src/gameplay/domain/item.lua
git commit -m "refactor: use table-driven design for simple item effects"
```

**预计节省**: ~80-100 行

---

### 任务 2.2: 合并目标查找函数 (1-2 小时)

#### 步骤 1: 创建通用函数
```lua
-- 在 item.lua 中添加
local function find_best_target(game, player, distance, filter_fn)
  distance = distance or 3
  local board = game.board
  local best_idx = nil
  local best_value = nil
  
  for _, idx in ipairs(indices_in_range(board, player.position, distance)) do
    if filter_fn(idx, player.position) then
      local tile = board:get_tile(idx)
      local value = 0
      
      if tile.type == "land" then
        local st = GameState.tile_state(game, tile)
        value = GameState.total_invested(tile, st.owner_id, st.level)
      end
      
      if not best_value or value > best_value then
        best_value = value
        best_idx = idx
      end
    end
  end
  
  return best_idx
end
```

#### 步骤 2: 重写现有函数
```lua
function ItemEffects.find_monster_target(game, player, distance)
  return find_best_target(game, player, distance, function(idx, pos)
    local tile = game.board:get_tile(idx)
    if tile.type == "land" then
      local st = GameState.tile_state(game, tile)
      return (st.level or 0) > 0 and st.owner_id and st.owner_id ~= player.id
    end
    return false
  end)
end

find_missile_target = function(game, player, distance)
  return find_best_target(game, player, distance, function(idx, pos)
    return idx ~= pos
  end)
end
```

#### 步骤 3: 测试和提交
```bash
love .  # 测试怪兽卡和导弹卡
git add src/gameplay/domain/item.lua
git commit -m "refactor: merge find_monster_target and find_missile_target"
```

**预计节省**: ~25 行

---

## 检查清单

### 每次重构后
- [ ] 代码可以运行（无语法错误）
- [ ] 游戏启动正常
- [ ] 相关功能可用
- [ ] 没有新的警告或错误
- [ ] 代码更简洁清晰
- [ ] 提交消息清晰

### 每周结束时
- [ ] 运行完整测试套件
- [ ] 手动测试所有修改的功能
- [ ] 检查行数减少情况
- [ ] 代码审查
- [ ] 合并到主分支

## 遇到问题怎么办

### 测试失败
1. 检查是否正确导入新模块
2. 检查函数签名是否匹配
3. 使用 print 调试查看值
4. 回退到上一个工作版本

### 不确定如何重构
1. 先理解现有代码
2. 参考 `docs/CODE_ANALYSIS.md` 中的示例
3. 小步尝试，保持代码可回退
4. 在 Issue 中寻求帮助

### 行数减少不如预期
- 这是正常的，估算会有偏差
- 关注代码质量提升，而不只是行数
- 继续下一个优化项

## 进度追踪

### 当前进度
```
第 1 周：
  ✓ 任务 1.1: 提取 Services 模块
  ✓ 任务 1.2: 提取 GameState 模块
  ⏳ 任务 1.3: 统一错误处理
  
已节省: ~102 行 / 目标 200-300 行
```

### 下一步
继续第二周的任务，重构 item.lua 和 chance.lua。

---

**提示**: 
- 不要急于求成，质量比速度重要
- 频繁提交，保持小步前进
- 遇到困难时参考文档或寻求帮助
- 记得测试！

**参考文档**:
- [完整路线图](ROADMAP_CODE_REDUCTION.md)
- [代码分析](CODE_ANALYSIS.md)
- [重构指南](REFACTORING_GUIDE.md)
- [优化分析](OPTIMIZATION_ANALYSIS.md)

# 代码优化快速参考指南

## 常见重构模式

### 模式 1: 提取重复函数

**适用场景**: 同一函数在多个文件中重复出现

**操作步骤**:
1. 在 `src/util/` 创建新的工具模块
2. 将函数移至工具模块并导出
3. 在原文件中 require 该模块
4. 替换所有调用点
5. 运行测试验证

**示例**:
```lua
-- 之前: 在多个文件中
local function get_service(game, key)
  return game and game.services and game.services[key]
end

-- 之后: src/util/services.lua
local Services = {}
function Services.get(game, key)
  return game and game.services and game.services[key]
end
return Services

-- 使用: 在需要的文件中
local Services = require("src.util.services")
local status = Services.get(game, "status")
```

### 模式 2: 表驱动设计

**适用场景**: 大量相似的 handler 函数，只是参数不同

**操作步骤**:
1. 识别共同模式和差异点
2. 创建配置表存储差异
3. 实现通用处理函数
4. 替换原有多个函数

**示例**:
```lua
-- 之前: 多个相似函数
handlers.add_cash = function(game, player, card)
  player:add_cash(card.amount)
  logger.event(player.name .. " 获得 " .. card.amount .. " 金币")
end

handlers.add_double_cash = function(game, player, card)
  player:add_cash(card.amount * 2)
  logger.event(player.name .. " 获得 " .. (card.amount * 2) .. " 金币")
end

-- 之后: 配置 + 通用函数
local CONFIGS = {
  add_cash = { multiplier = 1, message = "获得" },
  add_double_cash = { multiplier = 2, message = "获得" },
}

local function handle_cash(game, player, card, config)
  local amount = card.amount * config.multiplier
  player:add_cash(amount)
  logger.event(player.name .. " " .. config.message .. " " .. amount .. " 金币")
end

handlers.add_cash = function(g, p, c)
  handle_cash(g, p, c, CONFIGS.add_cash)
end
```

### 模式 3: 提取公共逻辑

**适用场景**: 多个函数有相同的前置/后置处理

**操作步骤**:
1. 识别公共部分
2. 提取为独立函数
3. 在原函数中调用

**示例**:
```lua
-- 之前: 重复的错误处理
function action1(game, player)
  local service = get_service(game, "status")
  if not service then
    logger.warn("缺少 StatusService")
    return false
  end
  -- 实际逻辑
  service.do_something(player)
  return true
end

function action2(game, player)
  local service = get_service(game, "status")
  if not service then
    logger.warn("缺少 StatusService")
    return false
  end
  -- 实际逻辑
  service.do_other_thing(player)
  return true
end

-- 之后: 提取公共部分
local function with_service(game, service_name, fn)
  local service = get_service(game, service_name)
  if not service then
    logger.warn("缺少 " .. service_name)
    return false
  end
  return fn(service)
end

function action1(game, player)
  return with_service(game, "status", function(service)
    service.do_something(player)
    return true
  end)
end

function action2(game, player)
  return with_service(game, "status", function(service)
    service.do_other_thing(player)
    return true
  end)
end
```

### 模式 4: 减少嵌套

**适用场景**: 深层嵌套的条件判断

**操作步骤**:
1. 使用早期返回（guard clauses）
2. 提取复杂条件为有意义的变量
3. 考虑反转条件

**示例**:
```lua
-- 之前: 深层嵌套
function process(game, player, tile)
  if game then
    if player then
      if tile then
        if tile.type == "land" then
          local state = get_state(game, tile)
          if state.owner_id == player.id then
            -- 实际逻辑
            do_something(player, tile)
            return true
          end
        end
      end
    end
  end
  return false
end

-- 之后: 早期返回
function process(game, player, tile)
  if not game or not player or not tile then
    return false
  end
  
  if tile.type ~= "land" then
    return false
  end
  
  local state = get_state(game, tile)
  if state.owner_id ~= player.id then
    return false
  end
  
  do_something(player, tile)
  return true
end
```

### 模式 5: 合并相似函数

**适用场景**: 多个函数逻辑几乎相同，只有细微差别

**操作步骤**:
1. 识别差异点
2. 添加参数或配置来区分
3. 合并为一个函数

**示例**:
```lua
-- 之前: 两个相似函数
function find_monster_target(game, player, distance)
  for _, idx in ipairs(indices) do
    local tile = get_tile(idx)
    if tile.type == "land" and has_building(tile) then
      -- 选择逻辑
    end
  end
end

function find_missile_target(game, player, distance)
  for _, idx in ipairs(indices) do
    local tile = get_tile(idx)
    if idx ~= player.position then
      -- 几乎相同的选择逻辑
    end
  end
end

-- 之后: 合并为一个
function find_target(game, player, distance, filter_fn)
  for _, idx in ipairs(indices) do
    local tile = get_tile(idx)
    if filter_fn(idx, tile, player) then
      -- 统一的选择逻辑
    end
  end
end

-- 使用时传入不同的过滤函数
find_target(game, player, 3, function(idx, tile, player)
  return tile.type == "land" and has_building(tile)
end)
```

## 重构清单

在重构任何代码前，确保：

- [ ] 理解代码的当前功能
- [ ] 已有测试覆盖（或准备手动测试）
- [ ] 在独立分支进行
- [ ] 每次只改一小块
- [ ] 每次改动后运行测试
- [ ] 保持提交小而频繁
- [ ] 代码审查前后对比

## 测试策略

### 自动化测试
```bash
# 运行回归测试（需要 Lua）
lua scripts/regression.lua

# 运行依赖检查
lua scripts/deps_check.lua
```

### 手动测试关键路径
1. 启动游戏: `love .`
2. 测试掷骰移动
3. 测试道具使用（每种类型至少一个）
4. 测试地块购买和升级
5. 测试机会牌触发
6. 测试路障和地雷
7. 测试破产流程

## 代码度量

### 重构前后对比
```bash
# 统计总行数
find . -name "*.lua" -exec wc -l {} + | tail -1

# 统计各模块行数
for dir in src/*/; do 
  echo "$dir: $(find $dir -name "*.lua" -exec wc -l {} + | tail -1 | cut -d' ' -f1)"
done

# 查找最大文件
find . -name "*.lua" -exec wc -l {} + | sort -rn | head -10

# 查找重复代码
grep -r "local function get_service" --include="*.lua" | wc -l
```

## 常见陷阱

### 陷阱 1: 过度抽象
❌ **错误**: 为只用一次的代码创建抽象
```lua
-- 不好: 只在一个地方使用
local function add_ten(x) return x + 10 end
local result = add_ten(value)
```

✅ **正确**: 保持简单
```lua
local result = value + 10
```

### 陷阱 2: 破坏封装
❌ **错误**: 工具函数访问太多内部状态
```lua
-- 不好: 工具函数知道太多细节
function Utils.process_player(game, player)
  game.store:set({"players", player.id, "cash"}, player.cash)
  game.ui_hooks.update_display()
  -- ...
end
```

✅ **正确**: 保持边界清晰
```lua
-- 好: 使用现有接口
function Utils.update_cash(player, amount)
  player:add_cash(amount)
  return player.cash
end
```

### 陷阱 3: 配置过度
❌ **错误**: 所有东西都变成配置
```lua
-- 不好: 简单逻辑也配置化
local CONFIGS = {
  check_positive = { compare = ">", value = 0 },
  check_negative = { compare = "<", value = 0 },
}
```

✅ **正确**: 保持适度
```lua
-- 好: 简单的检查直接写
if value > 0 then
  -- ...
end
```

## 重构时间估算

| 重构类型 | 估算时间 | 风险等级 |
|---------|---------|---------|
| 提取重复函数 | 30-60分钟 | 低 |
| 表驱动设计 | 2-4小时 | 中 |
| 合并相似函数 | 1-2小时 | 低 |
| 重构大文件 | 4-8小时 | 高 |
| 优化配置 | 1-2小时 | 低 |

## 获取帮助

### 参考文档
- 主路线图: `docs/ROADMAP_CODE_REDUCTION.md`
- 详细分析: `docs/CODE_ANALYSIS.md`
- 开发指南: `README.md`

### 检查重构是否成功
1. 代码行数减少 ✓
2. 测试全部通过 ✓
3. 代码更易理解 ✓
4. 减少了重复 ✓
5. 没有引入新复杂度 ✓

---

**提示**: 重构是渐进的过程。每次小步前进，保持代码始终可工作。

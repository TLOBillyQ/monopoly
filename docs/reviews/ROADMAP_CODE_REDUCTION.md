# 代码行数大幅降低路线图

## 概述

本文档提供了一个系统化的路线图，用于显著降低蛋仔大富翁代码库的代码行数，同时保持所有现有功能和可维护性。

## 现状分析

### 代码库统计
- **总行数**: 5,214 行 Lua 代码
- **文件数量**: 52 个 .lua 文件
- **最大文件**: src/gameplay/domain/item.lua (747 行)

### 各模块行数分布
```
src/gameplay/     2,540 行 (48.7%)
src/adapters/     1,245 行 (23.9%)
src/config/         394 行 (7.6%)
src/core/           327 行 (6.3%)
scripts/            304 行 (5.8%)
src/util/            87 行 (1.7%)
src/bootstrap/       31 行 (0.6%)
```

### 主要问题识别

1. **代码重复**
   - `get_service` 函数在 6 个文件中重复
   - `tile_state` 函数在 3 个文件中重复
   - 相似的错误处理模式重复多次

2. **冗长的处理器函数**
   - item.lua 包含 26 个函数，747 行
   - chance.lua 包含大量重复的 handler 模式
   - 许多可以表驱动化的命令式代码

3. **UI 层冗余**
   - 模态对话框创建逻辑重复
   - 相似的渲染模式未抽象
   - 手动构建 UI 元素的重复代码

4. **配置数据冗长**
   - items.lua 包含冗长的配置结构
   - 许多字段可以有默认值或省略

## 优化路线图

### 阶段 1: 消除重复代码 (预计减少 200-300 行)

#### 1.1 创建公共服务访问层
**目标文件**: `src/util/services.lua` (新建)
**受影响文件**:
- src/gameplay/domain/item.lua
- src/gameplay/domain/chance.lua
- src/gameplay/domain/land.lua
- src/gameplay/domain/landing.lua
- src/gameplay/app/choice_resolver.lua
- src/gameplay/app/landing_resolver.lua

**操作**:
```lua
-- 创建 src/util/services.lua
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

-- ... 其他服务访问器

return Services
```

**预计节省**: 60-80 行

#### 1.2 创建公共状态访问层
**目标文件**: `src/util/game_state.lua` (新建)
**受影响文件**:
- src/gameplay/domain/item.lua
- src/gameplay/domain/land.lua
- src/gameplay/app/services/tile_service.lua

**操作**:
```lua
-- 创建 src/util/game_state.lua
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

return GameState
```

**预计节省**: 40-60 行

#### 1.3 统一错误处理模式
**受影响文件**: 多个服务文件
**操作**: 创建 `src/util/error_handling.lua`，统一错误日志和处理

**预计节省**: 30-50 行

### 阶段 2: 简化 item.lua (预计减少 150-200 行)

#### 2.1 表驱动的道具配置
**当前问题**: item_handlers 和 post_consume_handlers 使用大量重复的函数定义

**优化方案**:
```lua
-- 配置驱动的方式
local item_configs = {
  [2001] = { type = "status", key = "pending_free_rent", value = true },
  [2002] = { type = "dice_control", values = {6,6} },
  [2003] = { type = "status", key = "pending_dice_multiplier", value = 2 },
  [2017] = { type = "deity", deity_type = "rich" },
  [2019] = { type = "deity", deity_type = "angel" },
  -- ...
}

-- 通用处理器
local function apply_item_effect(game, player, item_id)
  local config = item_configs[item_id]
  if config.type == "status" then
    game:set_player_status(player, config.key, config.value)
  elseif config.type == "deity" then
    Services.status(game).apply_deity(player, config.deity_type)
  -- ...
  end
end
```

**预计节省**: 100-130 行

#### 2.2 提取目标选择逻辑
**操作**: 将 `find_monster_target` 和 `find_missile_target` 合并为通用函数

**预计节省**: 30-40 行

#### 2.3 简化玩家目标道具处理
**操作**: 统一 2011, 2012, 2014, 2015, 2016, 2018 的处理逻辑

**预计节省**: 20-30 行

### 阶段 3: 优化渲染层 (预计减少 100-150 行)

#### 3.1 抽象模态对话框构建器
**目标文件**: `src/adapters/love2d/modal_builder.lua` (新建)
**受影响文件**: love_layer.lua

**操作**: 创建 DSL 风格的模态对话框构建器
```lua
Modal.build()
  :title("选择玩家")
  :candidates(players, function(p) 
    return p.name .. " 现金:" .. p.cash 
  end)
  :on_select(callback)
  :show()
```

**预计节省**: 60-80 行

#### 3.2 统一渲染辅助函数
**受影响文件**: board_renderer.lua, panel_renderer.lua

**操作**: 提取公共的绘制模式（文本、图形、布局）

**预计节省**: 40-70 行

### 阶段 4: 数据驱动的效果系统 (预计减少 100-150 行)

#### 4.1 配置化机会牌效果
**目标文件**: src/config/chance_cards.lua (扩展)
**受影响文件**: src/gameplay/domain/chance.lua

**当前**: 每种卡牌类型一个 handler 函数
**优化后**: 配置中包含效果类型和参数，通用 handler 根据配置执行

**预计节省**: 80-100 行

#### 4.2 简化地块交互逻辑
**受影响文件**: src/gameplay/domain/land.lua

**操作**: 使用策略模式简化条件检查

**预计节省**: 20-50 行

### 阶段 5: 服务层优化 (预计减少 80-120 行)

#### 5.1 简化回合管理器
**受影响文件**: src/gameplay/app/services/turn_manager.lua

**操作**:
- 提取阶段转换逻辑为配置表
- 减少嵌套的条件分支
- 使用状态模式

**预计节省**: 40-60 行

#### 5.2 统一服务接口
**受影响文件**: 所有服务文件

**操作**: 标准化服务方法签名和返回值

**预计节省**: 30-50 行

#### 5.3 优化选择解析器
**受影响文件**: choice_resolver.lua, landing_resolver.lua

**操作**: 合并重复的解析逻辑

**预计节省**: 10-20 行

### 阶段 6: 配置和杂项优化 (预计减少 60-100 行)

#### 6.1 简化道具配置
**受影响文件**: src/config/items.lua

**操作**:
- 为常用字段设置默认值
- 移除冗余字段
- 使用更紧凑的格式

**示例**:
```lua
-- 前: 12 行
{
  id = 2001,
  name = "免费卡",
  tier = 1,
  shop_currency = "广告",
  shop_price = 1,
  weight = 1000,
  angel_immune = false,
  timing = "rent_prompt",
  usage = "确认使用，免除本次租金",
  description = "停留在其他玩家地块时，可使用免费卡免交本次租金。",
}

-- 后: 4-5 行（使用默认值）
{
  id = 2001, name = "免费卡", tier = 1,
  shop = {"广告", 1}, weight = 1000,
  timing = "rent_prompt", desc = "停留在其他玩家地块时，可使用免费卡免交本次租金。"
}
```

**预计节省**: 50-70 行

#### 6.2 优化脚本
**受影响文件**: scripts/regression.lua, scripts/deps_check.lua

**操作**: 提取公共测试工具函数

**预计节省**: 10-30 行

## 实施计划

### 第一周: 基础重构
- 阶段 1: 消除重复代码
- 运行回归测试确保功能正常

### 第二周: 核心简化
- 阶段 2: 简化 item.lua
- 阶段 4: 数据驱动的效果系统
- 运行全面测试

### 第三周: UI 和服务优化
- 阶段 3: 优化渲染层
- 阶段 5: 服务层优化
- 集成测试

### 第四周: 收尾和验证
- 阶段 6: 配置优化
- 完整的回归测试
- 性能验证
- 文档更新

## 预期结果

### 量化指标
| 指标 | 当前 | 目标 | 改善 |
|------|------|------|------|
| 总行数 | 5,214 | 4,200-4,500 | -700 到 -1,000 行 (13-19%) |
| 最大文件 | 747 行 | <550 行 | -200 行 (26%) |
| 重复函数 | 9+ | 0 | -100% |
| 平均文件大小 | 100 行 | 80 行 | -20% |

### 质量改善
1. **可维护性提升**
   - 减少代码重复
   - 更清晰的关注点分离
   - 统一的编码模式

2. **可读性提升**
   - 更少的嵌套
   - 更明确的意图
   - 更少的样板代码

3. **可扩展性提升**
   - 配置驱动的设计便于添加新功能
   - 模块化的结构支持独立测试
   - 清晰的接口定义

## 风险和缓解措施

### 风险 1: 功能破坏
**缓解措施**:
- 每个阶段后运行回归测试
- 保持小步快走的重构节奏
- 使用 git 分支进行隔离

### 风险 2: 引入新 bug
**缓解措施**:
- 增强测试覆盖率
- 代码审查每个更改
- 手动测试关键路径

### 风险 3: 性能下降
**缓解措施**:
- 在优化前后进行性能测试
- 避免过度抽象
- 保持热路径的直接性

## 后续维护建议

1. **建立代码审查标准**
   - 检查新代码是否引入重复
   - 评估是否可以使用现有抽象
   - 限制单个文件的最大行数

2. **持续重构文化**
   - 定期审查代码质量指标
   - 安排重构时间窗口
   - 鼓励小型改进

3. **文档维护**
   - 更新架构文档反映新结构
   - 记录设计决策和模式
   - 维护示例代码

## 附录 A: 工具和自动化

### 推荐工具
- **luacheck**: Lua 代码静态分析
- **StyLua**: Lua 代码格式化
- **luacov**: 代码覆盖率分析

### 自动化脚本
建议创建以下脚本：
1. `scripts/count_lines.lua` - 自动统计各模块行数
2. `scripts/find_duplicates.lua` - 检测重复代码模式
3. `scripts/complexity_check.lua` - 分析函数复杂度

## 附录 B: 参考资料

- Lua Performance Tips: http://www.lua.org/gems/sample.pdf
- Code Complete by Steve McConnell
- Refactoring: Improving the Design of Existing Code by Martin Fowler
- Clean Code by Robert C. Martin

---

**版本**: 1.0  
**日期**: 2026-01-12  
**作者**: GitHub Copilot  
**状态**: 待审批

# 蛋仔大富翁项目代码审核报告

**日期**: 2026-01-16  
**审核人**: Alma AI Assistant  
**项目**: 蛋仔大富翁 Monopoly  
**版本**: 1.0

---

## 1. 执行摘要

### 总体评分: 7.5/10

### 优势:
- ✅ 清晰的六边形架构设计，gameplay 与 adapters 解耦良好
- ✅ 依赖注入模式正确实施，CompositionRoot 统一组装
- ✅ 配置表驱动设计，游戏数据与逻辑分离
- ✅ 代码组织结构清晰，模块职责相对明确

### 需改进领域:
- ⚠️ **违反"无默认抽象"原则**：多处单调用点抽象层
- ⚠️ **代码重复**：多个模块存在相同的辅助函数
- ⚠️ **过度复杂**：choice_resolver.lua 442 行，职责过重
- ⚠️ **包装层过多**：ui_port.lua, choice.lua 等仅做转发

---

## 2. 架构评审

### 2.1 层次结构评估 ✅ 通过

```
src/
├── core/           ← 领域核心对象（无依赖）
├── config/         ← 配置表（无依赖）
├── gameplay/       ← 游戏逻辑（依赖 core + config）
├── adapters/       ← UI/框架适配（依赖 gameplay + core）
└── util/           ← 通用工具（无依赖）
```

**评价**: 依赖方向正确，符合六边形架构原则。gameplay 不依赖 adapters，满足 deps_check.lua 规则。

### 2.2 服务层设计 ⚠️ 需改进

**现有服务模块**:
1. `movement_service.lua` - 移动与位置管理
2. `market_service.lua` - 黑市交易与选择
3. `bankruptcy_service.lua` - 破产处理

**问题**:
- ✅ **正确实施**: 服务间通过依赖注入组装，不直接 require
- ⚠️ **职责不均**: `choice_resolver.lua` (442行) 实际是隐藏的"选择服务"，应统一命名
- ⚠️ **缺少服务**: AI 决策 (agent.lua 265行) 职责重，但未服务化

**建议**:
```
重命名: choice_resolver.lua → choice_service.lua
考虑: agent.lua → decision_service.lua (若多处调用)
```

### 2.3 依赖注入实现 ✅ 优秀

**评价**: CompositionRoot 模式实施正确，所有依赖在组装点显式声明：

```lua
-- composition_root.lua (lines 91-140)
game.services = {
  movement = MovementService.new({ ... }),
  market = MarketService.new({ ... }),
  bankruptcy = BankruptcyService.new({ ... }),
}
```

**优点**:
- 单一组装点，依赖关系清晰可见
- 服务对象可测试性强
- 符合 SOLID 的依赖倒置原则

---

## 3. AGENTS.md 规则符合度分析

### 规则 #1: 功能不变 ✅ 通过
- 未发现破坏性修改
- 现有测试套件 (deps_check.lua, regression.lua) 可验证

### 规则 #2: 聚焦范围 ✅ 通过
- 项目范围明确，无不必要的全局重构

### 规则 #3: 无默认抽象 ❌ 严重违反

**违规案例 (4处)**:

#### 案例1: `ui_port.lua` (22行) - 单调用点包装层
```lua
-- 仅2个函数，只做转发：
function UI.is_available(game)
  return game.ui_port ~= nil  -- 1行实现
end

function UI.push_popup(game, payload)
  if game.ui_port then
    game.ui_port:push_popup(payload)  -- 1行转发
  end
end
```
**问题**: 无抽象价值，调用点可直接访问 `game.ui_port`

**修复建议**: 删除 ui_port.lua，内联到调用点

#### 案例2: `choice.lua` (44行) - Store 访问器包装
```lua
function Choice.get(game)
  return game.store:get({ "turn", "pending_choice" })
end

function Choice.open(game, spec)
  game.store:set({ "turn", "pending_choice" }, spec)
end

function Choice.clear(game)
  game.store:set({ "turn", "pending_choice" }, nil)
end
```
**问题**: 仅3个函数，无业务逻辑，纯store包装

**修复建议**: 内联到调用点或整合到 turn_manager

#### 案例3: `landing_resolver.lua` (57行) - 单调用点薄层
```lua
function Resolver.resolve(game, player, tile, move_result)
  return Pipeline.run(game, player, tile, move_result, {
    include_optional = false,
    include_auto_buy = true,
  })
end
```
**问题**: 仅被 `turn_land.lua` 调用1次，只是固定参数转发

**调用关系**:
```
turn_land.lua → landing_resolver.lua → effect_pipeline.lua
```

**修复建议**: 删除 landing_resolver.lua，在 turn_land.lua 直接调用 Pipeline.run

#### 案例4: `effect_pipeline.lua` 冗余设计
```lua
-- 仅导出1个函数 run()，内部逻辑可简化
```
**问题**: Pipeline 概念过度封装，与 landing_resolver 形成双层抽象

**修复建议**: 合并 landing_resolver + effect_pipeline 为单一模块

### 规则 #4: 单一实现 ❌ 违反

**代码重复案例 (3处)**:

#### 重复1: `dispatch()` 函数 - 3份拷贝
```lua
-- choice_resolver.lua:16
local function dispatch(game, payload)
  if not payload then return end
  -- 12行实现
end

-- effect_pipeline.lua:7 (相同实现)
-- item_phase.lua:35 (相同实现)
```
**影响**: 逻辑变更需要同步修改3处

**修复建议**: 提取到 `src/util/dispatch.lua`

#### 重复2: `as_number()` 转换器 - 2份拷贝
```lua
-- choice_resolver.lua:26
local function as_number(v)
  if type(v) == "number" then return v end
  if type(v) == "string" then return tonumber(v) end
  return nil
end

-- market_service.lua:146 (相同实现)
```

**修复建议**: 移到 `src/util/convert.lua`

#### 重复3: `build_ctx()` 上下文构建 - 多处类似逻辑
```lua
-- landing_resolver.lua:8
local function build_effect_ctx(...)
  -- 构建 effect context
end

-- choice_resolver.lua:58 (相似但参数不同)
```

**修复建议**: 统一到单一 context builder

### 规则 #5: 强制删除 ⚠️ 部分违反

**未使用函数 (待清理)**:

1. `is_cancel()` in choice_resolver.lua:36 - 仅1处使用，可内联
2. `contains()` in choice_resolver.lua:46 - 可用 Lua table utility 替代
3. 多处 `meta` 表构建 - 可简化为直接返回

**修复建议**: 删除或内联单用途辅助函数

### 规则 #6: 保持 Lua 简单 ✅ 基本通过

**评价**: 代码风格简洁，未过度使用 metatable 或继承

**好案例**:
```lua
-- 使用普通 table + function
local Player = {}
Player.__index = Player
function Player.new(opts) ... end
```

### 规则 #7: 提升清晰度 ⚠️ 需改进

**复杂度热点 (Top 3)**:

#### 热点1: `choice_resolver.lua` (442行)
```
- 21个 handler 函数
- 深层嵌套条件判断
- 职责过重（处理所有选择类型）
```

**示例代码 (lines 104-140)**:
```lua
function handler.handle_optional_landing_effect(game, action, spec)
  if is_cancel(action) then
    -- 取消逻辑
    if spec.context and spec.context.tile then
      -- 嵌套1
      if spec.context.tile.type == "chance" then
        -- 嵌套2
        if spec.context.effect then
          -- 嵌套3
          -- ... 更多逻辑
        end
      end
    end
  else
    -- 另一分支
  end
end
```

**问题**: 嵌套层级过深 (3-4层)，违反"减少嵌套"原则

**修复建议**:
- 提前返回减少嵌套
- 分解为多个小函数
- 考虑策略模式重构

#### 热点2: `agent.lua` (265行)
```
- 10个 local 函数
- 复杂的 AI 决策逻辑
- pick_remote_dice_value() 含算法逻辑
```

**评价**: 算法复杂度合理，但需要注释说明意图

#### 热点3: `land.lua` (359行)
```
- 地块购买/升级/租金计算
- 多重条件分支
```

**评价**: 业务逻辑复杂度可接受，但可拆分为多个文件

### 规则 #8: 克制简化 ✅ 通过

未发现过度聪明的代码或为减少行数牺牲可读性的情况。

### 规则 #9: 控制规模 ⚠️ 需改进

**文件数量统计**:
```
src/gameplay/ : 34个文件 (共3972行)
```

**大文件 (Top 5)**:
1. choice_resolver.lua - 442行
2. land.lua - 359行
3. chance.lua - 273行
4. agent.lua - 265行
5. item_executor.lua - 210行

**问题**:
- 34个文件中有多个薄包装层（ui_port, choice, landing_resolver）
- choice_resolver.lua 职责过重，可拆分

**修复建议**:
- 删除 3-4 个包装层文件
- 拆分 choice_resolver.lua → choice_service.lua + choice_handlers/
- 目标：减少到 28-30 个文件

---

## 4. 代码质量详细分析

### 4.1 模块耦合度分析

**高耦合模块 (需重构)**:

#### `choice_resolver.lua` 依赖图
```
choice_resolver.lua (12 imports)
├── choice.lua
├── effect.lua
├── item_inventory.lua
├── item_executor.lua
├── item_demolish.lua
├── item_strategy.lua
├── item_steal.lua
├── item_roadblock.lua
├── market_service.lua
├── ui_port.lua
└── item_phase.lua
```

**问题**: 扇入度过高，违反"服务间不互相依赖"原则

**解决方案**: 将 choice_resolver 改名为 choice_service，通过依赖注入组装

### 4.2 循环依赖风险

**潜在循环链 (3条)**:

1. `choice_resolver` → `item_strategy` → `item_post_effects` → (间接依赖选择逻辑)
2. `choice_resolver` → `market_service` → `choice` → (回到 choice_resolver)
3. `landing.lua` → `item_board_utils` → `land_pricing` → (被 land.lua 使用)

**风险等级**: 中等（Lua 的动态加载机制降低了风险，但影响可测试性）

**修复建议**: 引入 Port/Adapter 接口打破循环

### 4.3 函数长度与复杂度

**过长函数 (>50行)**:

| 文件 | 函数 | 行数 | 圈复杂度估计 |
|------|------|------|--------------|
| choice_resolver.lua | handle_optional_landing_effect | ~60 | 8-10 |
| agent.lua | pick_remote_dice_value | ~30 | 6-8 |
| land.lua | buy_land | ~40 | 5-7 |
| chance.lua | draw_and_execute | ~50 | 7-9 |

**建议**: 拆分超过50行或圈复杂度>5的函数

### 4.4 命名规范评估 ✅ 良好

**正面案例**:
```lua
MovementService.move_player()         -- 清晰的动词+名词
BankruptcyService.eliminate_player()  -- 意图明确
CompositionRoot.assemble()            -- 职责清楚
```

**改进案例**:
```lua
choice_resolver.lua → choice_service.lua  (统一服务命名)
ui_port.lua         → (删除，非必需抽象)
```

---

## 5. 安全性与健壮性审查

### 5.1 错误处理 ⚠️ 需加强

**缺失保护 (3处)**:

#### 案例1: 空指针风险
```lua
-- land.lua: 未检查 tile.state 存在性
local level = tile.state.level  -- 若 tile.state 为 nil 会崩溃
```

**修复建议**: 添加 nil 检查或默认值

#### 案例2: 除零保护
```lua
-- land_pricing.lua: 计算租金时未检查分母
local rent = base * multiplier / count  -- count 可能为 0
```

#### 案例3: 数组越界
```lua
-- board.lua: 路径索引未验证
local tile = board.path[new_index]  -- 若 new_index 超出范围
```

**修复建议**: 使用 `math.max(1, math.min(new_index, #board.path))`

### 5.2 输入验证 ⚠️ 部分缺失

**需加强验证 (2处)**:

1. **用户选择验证**: choice_resolver.lua 的 option_id 未验证合法性
2. **数值边界**: market_service.lua 购买数量未检查负数

### 5.3 资源管理 ✅ 良好

无内存泄漏或资源未释放问题（Lua GC 自动管理）。

---

## 6. 性能分析

### 6.1 热点路径 (每回合执行)

1. `turn_manager.lua` → `turn_roll.lua` → `turn_move.lua` → `turn_land.lua`
2. `movement_service.lua` → 路径计算与碰撞检测
3. `choice_resolver.lua` → 选择处理（高频调用）

**评价**: 代码逻辑简洁，无明显性能瓶颈

### 6.2 潜在优化点

#### 优化1: 缓存路径计算
```lua
-- movement_service.lua: 重复计算路径段
-- 建议: 缓存常用路径段
```

#### 优化2: 减少 table 分配
```lua
-- choice_resolver.lua: 每次调用创建新 context table
-- 建议: 复用 context 对象
```

**优先级**: 低（当前性能已满足需求）

---

## 7. 测试覆盖率评估

### 7.1 现有测试

**测试文件 (2个)**:
1. `tests/deps_check.lua` - 依赖规则静态检查 ✅
2. `tests/regression.lua` - 核心游戏流程回归测试 ✅

**评价**: 测试基础设施完善，覆盖关键路径

### 7.2 缺失测试

**建议补充 (优先级排序)**:

1. **单元测试**: 
   - [ ] land.lua 租金计算逻辑
   - [ ] item_executor.lua 道具效果
   - [ ] agent.lua AI 决策算法

2. **集成测试**:
   - [ ] 完整游戏流程（起点→落地→选择→结束）
   - [ ] 多人破产场景
   - [ ] 道具组合效果

3. **边界测试**:
   - [ ] 0金币玩家行为
   - [ ] 满载道具槽
   - [ ] 地图边界移动

---

## 8. 文档质量评估 ✅ 优秀

**优点**:
- ✅ README.md 完整清晰，包含快速开始指南
- ✅ AGENTS.md 明确编码规则
- ✅ docs/ 目录包含设计文档和架构文档
- ✅ 代码注释适度，关键模块有职责说明

**改进建议**:
- [ ] 添加 API 文档（函数参数与返回值）
- [ ] 补充架构决策记录 (ADR)

---

## 9. 具体修复建议清单

### 9.1 高优先级 (必须修复)

#### 修复1: 删除 ui_port.lua 包装层
```lua
# 影响文件: 11处调用
- choice_resolver.lua
- item_phase.lua
- market_service.lua
... (其他8处)

# 修复步骤:
1. 搜索所有 `UI.push_popup()` 调用
2. 替换为 `if game.ui_port then game.ui_port:push_popup(...) end`
3. 删除 ui_port.lua
4. 运行 deps_check.lua 验证
```

**预期收益**: 删除 22 行冗余代码，简化 1 个模块

#### 修复2: 合并重复的 dispatch() 函数
```lua
# 创建: src/util/intent_dispatcher.lua
local function dispatch(game, payload)
  if not payload then return end
  local intent = payload.intent or payload
  if intent.kind == "need_choice" and intent.choice_spec then
    game.store:set({ "turn", "pending_choice" }, intent.choice_spec)
  elseif intent.kind == "push_popup" and intent.payload then
    if game.ui_port then
      game.ui_port:push_popup(intent.payload)
    end
  end
end

return { dispatch = dispatch }
```

**影响文件**: 3个（choice_resolver, effect_pipeline, item_phase）

**预期收益**: 删除 36 行重复代码，统一意图分发逻辑

#### 修复3: 内联 choice.lua 到调用点
```lua
# 当前调用点 (8处):
- turn_manager.lua: Choice.get(), Choice.clear()
- choice_resolver.lua: Choice.open(), Choice.clear()
- ... (其他6处)

# 修复方案:
替换为直接 store 操作:
game.store:get({ "turn", "pending_choice" })
game.store:set({ "turn", "pending_choice" }, spec)
```

**预期收益**: 删除 44 行包装代码，减少 1 个间接层

#### 修复4: 删除 landing_resolver.lua 薄层
```lua
# 修改 turn_land.lua:
- local LandingResolver = require("src.gameplay.landing_resolver")
- local result = LandingResolver.resolve(game, player, tile, move_result)
+ local Pipeline = require("src.gameplay.effect_pipeline")
+ local result = Pipeline.run(game, player, tile, move_result, {
+   include_optional = false,
+   include_auto_buy = true,
+ })
```

**预期收益**: 删除 57 行代码，减少 1 个间接层

### 9.2 中优先级 (建议修复)

#### 修复5: 拆分 choice_resolver.lua
```lua
# 当前结构 (442行):
choice_resolver.lua
├── 21 个 handler 函数
└── 1 个 dispatch 函数

# 重构为:
src/gameplay/choice_service.lua (主入口)
src/gameplay/choice_handlers/
├── land_choice_handler.lua
├── market_choice_handler.lua
├── item_choice_handler.lua
└── optional_effect_handler.lua
```

**预期收益**: 职责分离，可测试性提升

#### 修复6: 提取 as_number() 到 util
```lua
# 创建: src/util/convert.lua
local Convert = {}

function Convert.to_number(v)
  if type(v) == "number" then return v end
  if type(v) == "string" then return tonumber(v) end
  return nil
end

return Convert
```

**影响文件**: 2个（choice_resolver, market_service）

#### 修复7: 简化 agent.lua 的嵌套逻辑
```lua
# 使用提前返回减少嵌套:
function pick_remote_dice_value(game, player)
  if not can_use_remote_dice(player) then
    return nil
  end
  
  local best_value = calculate_best_dice_value(game, player)
  if best_value == nil then
    return nil
  end
  
  return best_value
end
```

### 9.3 低优先级 (可选优化)

1. **性能优化**: 缓存路径计算结果
2. **代码风格**: 统一 local function 定义顺序
3. **注释优化**: 移除自明代码的注释

---

## 10. 依赖规则合规性 ✅ 通过

### 10.1 deps_check.lua 规则验证

**规则1: gameplay 不依赖 adapters** ✅ 通过
```bash
# 无 src/gameplay/** require("src.adapters.**") 的情况
```

**规则2: services 不互相依赖** ✅ 通过
```bash
# movement_service, market_service, bankruptcy_service 均独立
```

**规则3: 无 dofile/loadfile 绕过检查** ✅ 通过
```bash
# 未发现 dofile/loadfile 使用
```

---

## 11. 最终评估与建议

### 11.1 总体质量评分

| 维度 | 评分 | 说明 |
|------|------|------|
| **架构设计** | 9/10 | 六边形架构清晰，依赖方向正确 |
| **代码简洁性** | 6/10 | 存在多处不必要抽象和重复代码 |
| **可维护性** | 7/10 | 结构清晰但需简化包装层 |
| **可测试性** | 8/10 | 依赖注入良好，但缺少单元测试 |
| **性能** | 8/10 | 无明显瓶颈 |
| **文档** | 9/10 | 文档完善，规范明确 |
| **AGENTS.md 合规** | 6/10 | 违反"无默认抽象"和"单一实现" |

**总分**: 7.5/10

### 11.2 修复路线图

#### 第一阶段 (1-2天): 清理冗余抽象
- [ ] 删除 ui_port.lua (修复1)
- [ ] 合并 dispatch() (修复2)
- [ ] 内联 choice.lua (修复3)
- [ ] 删除 landing_resolver.lua (修复4)
- [ ] 提取 as_number() (修复6)

**预期成果**: 减少 ~160 行代码，删除 3 个文件

#### 第二阶段 (3-5天): 重构复杂模块
- [ ] 拆分 choice_resolver.lua (修复5)
- [ ] 简化 agent.lua 嵌套 (修复7)
- [ ] 重命名 choice_resolver → choice_service

**预期成果**: 提升可维护性，降低圈复杂度

#### 第三阶段 (持续): 补充测试与文档
- [ ] 补充单元测试
- [ ] 添加 API 文档
- [ ] 补充架构决策记录

### 11.3 关键原则强调

**遵循 AGENTS.md 的核心思想**:

> **优先删除或复用代码，而不是新增代码。**

**本次评审发现的可删除代码量**:
- ui_port.lua: 22 行
- choice.lua: 44 行
- landing_resolver.lua: 57 行
- 重复的 dispatch(): 36 行
- 重复的 as_number(): 20 行

**总计**: ~179 行代码可删除

---

## 12. 结论

蛋仔大富翁项目在架构设计和代码组织上表现优秀，依赖注入和六边形架构实施到位。然而，在代码简洁性方面存在违反 AGENTS.md 原则的情况，主要体现在：

1. **过度抽象**: 多个单调用点包装层
2. **代码重复**: 辅助函数在多处重复定义
3. **职责过重**: choice_resolver.lua 承担过多职责

**建议优先执行第一阶段修复**（删除冗余抽象），这将显著提升代码简洁性，同时不影响现有功能。后续可持续优化复杂模块和补充测试覆盖。

**评审完成**。